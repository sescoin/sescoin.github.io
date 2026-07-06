-- Correctifs :
-- 1. approve_account_request : la migration 20260707 insérait first_name/last_name
--    dans profiles (colonnes inexistantes) et role='user' (interdit) -> échec
--    « column first_name of relation profiles does not exist ». On rétablit la
--    version correcte : display_name, role='student', réutilisation d'un
--    éventuel compte auth existant, transaction de solde initial.
-- 2. submit_account_request : la contrainte unique account_requests_username_key
--    bloquait la recréation d'un compte dont une ancienne demande (approuvée ou
--    refusée) portait le même identifiant. On purge ces demandes non en attente.
-- 3. send_chat_gift : montant minimum 0,01 SC (le solde est stocké à 2 décimales,
--    un cadeau plus petit s'affichait « 0.00 » et sa récupération violait la
--    contrainte transactions_amount_check).
-- 4. accept_chat_loan_request : enregistre le prêt de classe dans la blockchain
--    avec la description accentuée « Prêt accordé ».
-- 5. Accents rétablis rétroactivement sur les anciennes transactions de prêt.
-- 6. Notification de bannissement : retrait de « La consultation reste possible ».

begin;

-- ── 1. approve_account_request (colonnes correctes) ──────────────────────────

create or replace function public.approve_account_request(
  p_request_id      uuid,
  p_initial_balance numeric
)
returns void
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_request  public.account_requests%rowtype;
  v_user_id  uuid;
  v_email    text;
  v_admin_id uuid;
begin
  v_admin_id := auth.uid();

  if not exists (
    select 1 from public.profiles where id = v_admin_id and role = 'admin'
  ) then
    raise exception 'Non autorisé.';
  end if;

  select * into v_request
  from public.account_requests
  where id = p_request_id and status = 'pending'
  for update;

  if v_request.id is null then
    raise exception 'Demande introuvable ou déjà traitée.';
  end if;

  v_email := v_request.username || '@sescoin.local';

  -- Réutiliser un compte auth existant (recréation après suppression).
  select id into v_user_id from auth.users where email = v_email;

  if v_user_id is null then
    v_user_id := gen_random_uuid();

    insert into auth.users (
      id, instance_id, aud, role, email,
      encrypted_password, email_confirmed_at,
      confirmation_token, recovery_token,
      email_change_token_new, email_change, email_change_token_current,
      reauthentication_token, last_sign_in_at,
      raw_app_meta_data, raw_user_meta_data,
      is_sso_user, created_at, updated_at
    ) values (
      v_user_id,
      '00000000-0000-0000-0000-000000000000',
      'authenticated', 'authenticated',
      v_email,
      v_request.password_hash,
      now(),
      '', '', '', '', '', '',
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object(
        'username', v_request.username,
        'display_name', v_request.first_name || ' ' || v_request.last_name
      ),
      false, now(), now()
    );

    insert into auth.identities (
      id, user_id, provider_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), v_user_id, v_user_id::text,
      jsonb_build_object(
        'sub', v_user_id::text,
        'email', v_email,
        'email_verified', true,
        'provider', 'email'
      ),
      'email', now(), now(), now()
    );
  else
    -- Compte auth déjà présent : rafraîchir le mot de passe et l'identity.
    update auth.users
    set encrypted_password = v_request.password_hash,
        email_confirmed_at = coalesce(email_confirmed_at, now()),
        updated_at = now()
    where id = v_user_id;

    insert into auth.identities (
      id, user_id, provider_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    )
    select
      gen_random_uuid(), v_user_id, v_user_id::text,
      jsonb_build_object(
        'sub', v_user_id::text,
        'email', v_email,
        'email_verified', true,
        'provider', 'email'
      ),
      'email', now(), now(), now()
    where not exists (
      select 1 from auth.identities
      where user_id = v_user_id and provider = 'email'
    );
  end if;

  -- Profil (colonnes réelles : pas de first_name/last_name, role = 'student').
  if not exists (select 1 from public.profiles where id = v_user_id) then
    insert into public.profiles (
      id, username, display_name, balance,
      role, is_banned, avatar_url, class_id, created_at
    ) values (
      v_user_id,
      v_request.username,
      v_request.first_name || ' ' || v_request.last_name,
      p_initial_balance,
      'student', false, v_request.avatar_url, v_request.class_id, now()
    );
  end if;

  update public.account_requests
  set status          = 'approved',
      reviewed_at     = now(),
      reviewed_by     = v_admin_id,
      initial_balance = p_initial_balance
  where id = p_request_id;

  insert into public.transactions (
    from_user_id, to_user_id, amount, type, description, metadata
  ) values (
    v_admin_id, v_user_id, p_initial_balance,
    'initial_balance', 'Solde initial',
    jsonb_build_object('account_request_id', p_request_id)
  );

  insert into public.notifications (user_id, type, title, body, is_read)
  values (
    v_user_id, 'account_approved',
    'Compte approuvé',
    'Le compte SES Coin a été approuvé. Bienvenue !',
    false
  );
end;
$$;

grant execute on function public.approve_account_request(uuid, numeric) to authenticated;

-- ── 2. submit_account_request : purge des demandes homonymes non en attente ──

create or replace function public.submit_account_request(
  p_first_name text,
  p_last_name  text,
  p_username   text,
  p_password   text,
  p_avatar_url text,
  p_device_id  text,
  p_class_id   uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_request account_requests%rowtype;
  v_admin   record;
begin
  if p_password is null or length(p_password) < 8 then
    raise exception 'Le mot de passe doit contenir au moins 8 caractères.';
  end if;

  -- Un identifiant réellement utilisé (profil actif) reste bloqué…
  if exists (select 1 from profiles where username = p_username) then
    raise exception 'Cet identifiant est déjà utilisé.';
  end if;

  -- …mais les anciennes demandes traitées (approuvées/refusées) ne doivent pas
  -- empêcher une nouvelle demande : on les supprime pour libérer l'identifiant.
  delete from account_requests
  where username = p_username and status <> 'pending';

  if exists (
    select 1 from account_requests
    where username = p_username and status = 'pending'
  ) then
    raise exception 'Une demande est déjà en attente pour cet identifiant.';
  end if;

  insert into account_requests (
    first_name, last_name, username, password_hash,
    avatar_url, device_id, class_id
  ) values (
    p_first_name, p_last_name, p_username,
    crypt(p_password, gen_salt('bf')),
    p_avatar_url, p_device_id, p_class_id
  ) returning * into v_request;

  for v_admin in select id from profiles where role = 'admin' loop
    insert into notifications (user_id, type, title, body, data, is_read)
    values (
      v_admin.id, 'system',
      'Nouvelle demande de compte',
      p_first_name || ' ' || p_last_name || ' souhaite créer un compte.',
      jsonb_build_object('request_id', v_request.id),
      false
    );
  end loop;

  return to_jsonb(v_request);
end;
$$;

grant execute on function public.submit_account_request(text,text,text,text,text,text,uuid) to anon;
grant execute on function public.submit_account_request(text,text,text,text,text,text,uuid) to authenticated;

-- ── 3. send_chat_gift : montant minimum 0,01 SC ──────────────────────────────

create or replace function public.send_chat_gift(
  p_amount   numeric,
  p_note     text default null,
  p_class_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_id uuid := auth.uid();
  v_user    public.profiles%rowtype;
  v_message public.chat_messages%rowtype;
begin
  if v_auth_id is null then raise exception 'Non authentifié.'; end if;

  select * into v_user from public.profiles where id = v_auth_id for update;
  if v_user.id is null then raise exception 'Profil introuvable.'; end if;
  if v_user.is_banned then raise exception 'Votre compte est banni.'; end if;

  if p_amount is null or p_amount < 0.01 then
    raise exception 'Le cadeau doit valoir au moins 0,01 SC.';
  end if;
  if p_amount > 100000 then
    raise exception 'Le montant ne peut pas dépasser 100 000 SC.';
  end if;

  if p_class_id is null then
    if v_user.role <> 'admin' then
      raise exception 'Seul l''administrateur peut envoyer un cadeau ici.';
    end if;
  else
    if not exists (select 1 from public.classes where id = p_class_id) then
      raise exception 'Classe introuvable.';
    end if;
    if v_user.role <> 'admin' and v_user.class_id is distinct from p_class_id then
      raise exception 'Vous n''appartenez pas à cette classe.';
    end if;
  end if;

  if v_user.role <> 'admin' then
    if v_user.balance < p_amount then
      raise exception 'Solde insuffisant.';
    end if;
    update public.profiles
    set balance = balance - p_amount
    where id = v_auth_id;
  end if;

  insert into public.chat_messages (
    user_id, username, display_name, avatar_url,
    content, is_censored, class_id, message_type,
    gift_amount, expires_at
  ) values (
    v_auth_id, v_user.username, v_user.display_name, v_user.avatar_url,
    coalesce(nullif(trim(coalesce(p_note, '')), ''), ''),
    false, p_class_id, 'gift',
    p_amount,
    now() + interval '7 days'
  ) returning * into v_message;

  return jsonb_build_object(
    'message', to_jsonb(v_message),
    'warning', false,
    'warning_count', 0,
    'muted', false
  );
end;
$$;

-- ── 4. accept_chat_loan_request : transaction blockchain « Prêt accordé » ─────

create or replace function public.accept_chat_loan_request(p_message_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lender_id uuid := auth.uid();
  v_lender    public.profiles%rowtype;
  v_borrower  public.profiles%rowtype;
  v_message   public.chat_messages%rowtype;
  v_total_due numeric;
  v_loan_id   uuid;
begin
  if v_lender_id is null then raise exception 'Non authentifié.'; end if;

  select * into v_lender from public.profiles where id = v_lender_id for update;
  if v_lender.id is null then raise exception 'Profil introuvable.'; end if;
  if v_lender.is_banned then raise exception 'Votre compte est banni.'; end if;

  select * into v_message
  from public.chat_messages
  where id = p_message_id
    and message_type = 'loan_request'
    and not is_deleted
    and coalesce(loan_status, 'pending') = 'pending'
  for update;

  if v_message.id is null then
    raise exception 'Demande introuvable ou déjà acceptée.';
  end if;
  if v_message.user_id = v_lender_id then
    raise exception 'Impossible d''accepter sa propre demande.';
  end if;
  if v_message.loan_due_date is not null and v_message.loan_due_date <= now() then
    raise exception 'La date d''échéance est déjà dépassée.';
  end if;
  if v_message.expires_at is not null and v_message.expires_at <= now() then
    raise exception 'Cette demande a expiré.';
  end if;

  select * into v_borrower
  from public.profiles where id = v_message.user_id for update;
  if v_borrower.id is null then raise exception 'Emprunteur introuvable.'; end if;

  if v_message.loan_amount > 100000 then
    raise exception 'Montant maximum 100 000 SC.';
  end if;
  if v_lender.balance < v_message.loan_amount then
    raise exception 'Solde insuffisant.';
  end if;

  v_total_due := v_message.loan_amount * (1 + coalesce(v_message.loan_interest_rate, 0) / 100);

  insert into public.loans (
    lender_id, lender_username,
    borrower_id, borrower_username,
    principal, interest_rate, total_due, amount_repaid,
    due_date, note, status
  ) values (
    v_lender_id, v_lender.username,
    v_message.user_id, v_borrower.username,
    v_message.loan_amount,
    coalesce(v_message.loan_interest_rate, 0),
    v_total_due, 0,
    v_message.loan_due_date,
    v_message.loan_note,
    'active'
  ) returning id into v_loan_id;

  update public.profiles set balance = balance - v_message.loan_amount where id = v_lender_id;
  update public.profiles set balance = balance + v_message.loan_amount where id = v_message.user_id;

  update public.chat_messages
  set loan_status = 'accepted',
      loan_id = v_loan_id,
      loan_accepted_by = v_lender_id
  where id = p_message_id;

  -- Trace dans la blockchain (prêteur -> emprunteur), description accentuée.
  insert into public.transactions (
    from_user_id, to_user_id, amount, type, description, metadata
  ) values (
    v_lender_id, v_message.user_id, v_message.loan_amount,
    'loan', 'Prêt accordé',
    jsonb_build_object('loan_id', v_loan_id)
  );

  insert into public.notifications (user_id, type, title, body, data, is_read)
  values (
    v_message.user_id, 'loan_accepted',
    'Prêt accordé',
    v_lender.display_name || ' a accepté la demande de prêt de '
      || v_message.loan_amount::text || ' SC.',
    jsonb_build_object('loan_id', v_loan_id),
    false
  );

  return jsonb_build_object('loan_id', v_loan_id);
end;
$$;

-- ── 5. Accents rétroactifs sur les anciennes transactions de prêt ────────────

update public.transactions
set description = 'Prêt accordé'
where description in ('Pret accorde', 'PrÃªt accordÃ©');

update public.transactions
set description = 'Remboursement de prêt'
where description in ('Remboursement de pret', 'Remboursement de pr?t');

-- ── 6. Bannissement : notification sans « consultation possible » ─────────────

create or replace function public.admin_ban_user(
  p_user_id uuid,
  p_reason  text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin public.profiles%rowtype;
begin
  select * into v_admin from public.profiles where id = auth.uid();
  if v_admin.id is null or v_admin.role <> 'admin' then
    raise exception 'Action réservée à l''administrateur.';
  end if;
  if p_user_id = v_admin.id then
    raise exception 'Impossible de bannir son propre compte.';
  end if;

  update public.profiles
  set is_banned = true,
      ban_reason = nullif(trim(coalesce(p_reason, '')), ''),
      updated_at = now()
  where id = p_user_id;

  if not found then
    raise exception 'Compte introuvable.';
  end if;

  insert into public.notifications (user_id, type, title, body, data, is_read)
  values (
    p_user_id, 'system',
    'Compte suspendu',
    'Ce compte a été suspendu par l''administrateur.'
      || case when p_reason is not null and length(trim(p_reason)) > 0
           then ' Motif : ' || trim(p_reason) || '.'
           else '' end
      || ' Aucune action n''est autorisée.',
    null,
    false
  );
end;
$$;

grant execute on function public.admin_ban_user(uuid, text) to authenticated;

-- ── 7. is_username_available : cohérent avec la recréation de compte ──────────
-- Seuls un profil actif ou une demande réellement en attente bloquent un
-- identifiant. Les demandes approuvées/refusées d'un compte supprimé et un
-- éventuel compte auth résiduel sont réutilisés à l'approbation.

create or replace function public.is_username_available(p_username text)
returns boolean
language sql security definer set search_path = public, auth
as $$
  select
    not exists (select 1 from public.profiles where username = p_username)
    and
    not exists (
      select 1 from public.account_requests
      where username = p_username and status = 'pending'
    );
$$;

grant execute on function public.is_username_available to anon, authenticated;

commit;

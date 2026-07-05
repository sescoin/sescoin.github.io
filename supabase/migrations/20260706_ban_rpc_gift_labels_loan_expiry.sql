-- Correctifs :
-- 1. Bannissement via RPC (l'UPDATE direct du client était bloqué par RLS,
--    silencieusement : la confirmation s'affichait mais rien n'était banni).
--    La notification est créée dans la même transaction.
-- 2. Textes des transactions/notifications de cadeaux : « Cadeau récupéré »,
--    formulations neutres (ni tutoiement ni vouvoiement).
-- 3. Demandes de prêt du chat : expiration automatique au bout de 24 h,
--    quel que soit leur état ; échéance minimale abaissée à 5 minutes.
-- 4. Accents rétablis sur tous les messages d'erreur affichés dans l'app.

begin;

-- ── 1. Bannir / réactiver via RPC ────────────────────────────────────────────

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
      || ' La consultation reste possible, mais aucune action n''est autorisée.',
    null,
    false
  );
end;
$$;

grant execute on function public.admin_ban_user(uuid, text) to authenticated;

create or replace function public.admin_unban_user(p_user_id uuid)
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

  update public.profiles
  set is_banned = false,
      ban_reason = null,
      updated_at = now()
  where id = p_user_id;

  if not found then
    raise exception 'Compte introuvable.';
  end if;

  insert into public.notifications (user_id, type, title, body, data, is_read)
  values (
    p_user_id, 'system',
    'Compte réactivé',
    'Ce compte a été réactivé par l''administrateur.',
    null,
    false
  );
end;
$$;

grant execute on function public.admin_unban_user(uuid) to authenticated;

-- ── 2. Cadeaux : libellés corrigés et neutres ────────────────────────────────

create or replace function public.claim_chat_gift(p_message_id uuid)
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

  select * into v_message
  from public.chat_messages
  where id = p_message_id
    and message_type = 'gift'
    and not is_deleted
  for update;

  if v_message.id is null then
    raise exception 'Cadeau introuvable.';
  end if;
  if v_message.gift_claimed_by is not null then
    raise exception 'Trop tard, ce cadeau a déjà été récupéré.';
  end if;
  if v_message.expires_at is not null and v_message.expires_at <= now() then
    raise exception 'Ce cadeau a expiré.';
  end if;
  if v_message.user_id = v_auth_id then
    raise exception 'Impossible de récupérer son propre cadeau.';
  end if;
  if v_message.class_id is not null
     and v_user.role <> 'admin'
     and v_user.class_id is distinct from v_message.class_id then
    raise exception 'Ce cadeau est réservé à une autre classe.';
  end if;

  update public.chat_messages
  set gift_claimed_by = v_auth_id,
      gift_claimed_username = v_user.username,
      gift_claimed_at = now()
  where id = p_message_id;

  update public.profiles
  set balance = balance + v_message.gift_amount
  where id = v_auth_id;

  insert into public.transactions (
    from_user_id, to_user_id, amount, type, description, metadata
  ) values (
    v_message.user_id, v_auth_id, v_message.gift_amount, 'gift',
    'Cadeau récupéré',
    jsonb_build_object('chat_message_id', p_message_id)
  );

  insert into public.notifications (user_id, type, title, body, data, is_read)
  values (
    v_message.user_id, 'system',
    'Cadeau récupéré',
    v_user.display_name || ' a récupéré le cadeau de '
      || v_message.gift_amount::text || ' SC.',
    jsonb_build_object('chat_message_id', p_message_id),
    false
  );

  return jsonb_build_object(
    'claimed', true,
    'amount', v_message.gift_amount
  );
end;
$$;

-- Corriger les descriptions des transactions cadeaux existantes
update public.transactions
set description = 'Cadeau récupéré'
where type = 'gift' and description = 'Cadeau du chat recupere';

-- ── 3. Notification d'acceptation de prêt : formulation neutre ───────────────

create or replace function public.accept_chat_loan_request(p_message_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_lender_id   uuid := auth.uid();
  v_lender      public.profiles%rowtype;
  v_borrower    public.profiles%rowtype;
  v_message     public.chat_messages%rowtype;
  v_total_due   numeric;
  v_loan_id     uuid;
begin
  if v_lender_id is null then raise exception 'Non authentifié.'; end if;

  select * into v_lender
  from public.profiles
  where id = v_lender_id
  for update;

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
  from public.profiles
  where id = v_message.user_id
  for update;

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

  update public.profiles
  set balance = balance - v_message.loan_amount
  where id = v_lender_id;

  update public.profiles
  set balance = balance + v_message.loan_amount
  where id = v_message.user_id;

  update public.chat_messages
  set loan_status = 'accepted',
      loan_id = v_loan_id,
      loan_accepted_by = v_lender_id
  where id = p_message_id;

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

-- ── 4. Demandes de prêt du chat : expiration à 24 h ──────────────────────────

drop function if exists public.send_loan_request_chat(numeric, numeric, timestamptz, text, uuid);

create or replace function public.send_loan_request_chat(
  p_amount        numeric,
  p_interest_rate numeric     default null,
  p_due_date      timestamptz default null,
  p_note          text        default null,
  p_class_id      uuid        default null
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

  select * into v_user from public.profiles where id = v_auth_id;
  if v_user.id is null then raise exception 'Profil introuvable.'; end if;
  if v_user.is_banned then raise exception 'Votre compte est banni.'; end if;

  if p_class_id is not null then
    if not exists (select 1 from public.classes where id = p_class_id) then
      raise exception 'Classe introuvable.';
    end if;
    if v_user.role <> 'admin' and v_user.class_id is distinct from p_class_id then
      raise exception 'Vous n''appartenez pas à cette classe.';
    end if;
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'Montant invalide.';
  end if;
  if p_amount > 100000 then
    raise exception 'Le montant ne peut pas dépasser 100 000 SC.';
  end if;
  if p_interest_rate is not null and (p_interest_rate < 0 or p_interest_rate > 100) then
    raise exception 'Taux d''intérêt invalide (0-100).';
  end if;
  if p_due_date is not null and p_due_date <= now() + interval '5 minutes' then
    raise exception 'La date d''échéance doit être au moins dans 5 minutes.';
  end if;

  insert into public.chat_messages (
    user_id, username, display_name, avatar_url,
    content, is_censored, class_id, message_type,
    loan_amount, loan_note, loan_interest_rate, loan_due_date,
    loan_status, expires_at
  ) values (
    v_auth_id, v_user.username, v_user.display_name, v_user.avatar_url,
    coalesce(nullif(trim(p_note), ''), ''),
    false, p_class_id, 'loan_request',
    p_amount,
    nullif(trim(coalesce(p_note, '')), ''),
    p_interest_rate,
    p_due_date,
    'pending',
    now() + interval '24 hours'
  ) returning * into v_message;

  return jsonb_build_object(
    'message', to_jsonb(v_message),
    'warning', false,
    'warning_count', 0,
    'muted', false
  );
end;
$$;

grant execute on function public.send_loan_request_chat(numeric, numeric, timestamptz, text, uuid) to authenticated;

-- Appliquer la règle des 24 h aux demandes déjà publiées
update public.chat_messages
set expires_at = created_at + interval '24 hours'
where message_type = 'loan_request'
  and expires_at > created_at + interval '24 hours';

-- ── 5. Cadeaux : messages d'erreur accentués ─────────────────────────────────

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

  if p_amount is null or p_amount <= 0 then
    raise exception 'Montant invalide.';
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

commit;

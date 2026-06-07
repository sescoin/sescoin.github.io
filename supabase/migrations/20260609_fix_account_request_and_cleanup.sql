begin;

-- ── 1. Corriger submit_account_request : password_hash + notif admin ──────────

drop function if exists public.submit_account_request(text,text,text,text,text,text,uuid);

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

  if exists (
    select 1 from profiles where username = p_username
    union
    select 1 from account_requests
    where username = p_username and status = 'pending'
  ) then
    raise exception 'Ce nom d''utilisateur est déjà pris ou en attente.';
  end if;

  insert into account_requests (
    first_name, last_name, username, password_hash,
    avatar_url, device_id, class_id
  ) values (
    p_first_name, p_last_name, p_username,
    crypt(p_password, gen_salt('bf')),
    p_avatar_url, p_device_id, p_class_id
  ) returning * into v_request;

  -- Notifier l'admin d'une nouvelle demande de compte
  for v_admin in select id from profiles where role = 'admin' loop
    insert into notifications (user_id, type, title, body, data, is_read)
    values (
      v_admin.id,
      'system',
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

-- ── 2. Mettre à jour approve_account_request pour copier class_id ─────────────

create or replace function public.approve_account_request(
  p_request_id     uuid,
  p_initial_balance numeric
)
returns void
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_request public.account_requests%rowtype;
  v_user_id uuid;
  v_email   text;
  v_admin_id uuid;
begin
  v_admin_id := auth.uid();

  select * into v_request
  from public.account_requests
  where id = p_request_id and status = 'pending'
  for update;

  if v_request.id is null then
    raise exception 'Demande introuvable ou déjà traitée.';
  end if;

  v_user_id := gen_random_uuid();
  v_email   := v_request.username || '@sescoin.local';

  insert into auth.users (
    id, instance_id, aud, role, email,
    encrypted_password, email_confirmed_at,
    confirmation_token, recovery_token,
    email_change_token_new, email_change, email_change_token_current,
    reauthentication_token, last_sign_in_at,
    raw_app_meta_data, raw_user_meta_data,
    is_super_admin, created_at, updated_at
  ) values (
    v_user_id, '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    v_email,
    v_request.password_hash,
    now(),
    '', '', '', '', '',
    '',
    now(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    false, now(), now()
  );

  insert into auth.identities (
    id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  ) values (
    gen_random_uuid(), v_user_id,
    jsonb_build_object('sub', v_user_id, 'email', v_email),
    'email', now(), now(), now()
  );

  insert into public.profiles (
    id, username, first_name, last_name, display_name,
    avatar_url, balance, role, class_id
  ) values (
    v_user_id,
    v_request.username,
    v_request.first_name,
    v_request.last_name,
    v_request.first_name || ' ' || v_request.last_name,
    v_request.avatar_url,
    p_initial_balance,
    'user',
    v_request.class_id
  );

  update public.account_requests
  set status      = 'approved',
      reviewed_at = now(),
      reviewed_by = v_admin_id,
      initial_balance = p_initial_balance
  where id = p_request_id;

  insert into public.notifications (user_id, type, title, body, is_read)
  values (
    v_user_id, 'account_approved',
    'Compte approuvé',
    'Ton compte SES Coin a ete approuve',
    false
  );
end;
$$;

grant execute on function public.approve_account_request(uuid, numeric) to authenticated;

-- RPC pour que l'admin mette à jour la classe d'une demande de compte
create or replace function public.set_account_request_class(
  p_request_id uuid,
  p_class_id   uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Non autorisé.';
  end if;
  update account_requests set class_id = p_class_id where id = p_request_id;
end;
$$;

grant execute on function public.set_account_request_class(uuid, uuid) to authenticated;

-- ── 3. loan_due_date en timestamptz (pas date) ────────────────────────────────

alter table public.chat_messages
  add column if not exists loan_interest_rate numeric,
  add column if not exists loan_due_date       timestamptz;

-- ── 4. Mettre à jour send_loan_request_chat (timestamptz + validations) ───────

drop function if exists public.send_loan_request_chat(numeric, text);
drop function if exists public.send_loan_request_chat(numeric, numeric, date, text);

create or replace function public.send_loan_request_chat(
  p_amount        numeric,
  p_interest_rate numeric    default null,
  p_due_date      timestamptz default null,
  p_note          text       default null
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

  select * into v_user from profiles where id = v_auth_id;
  if v_user.id is null then raise exception 'Profil introuvable.'; end if;
  if v_user.is_banned then raise exception 'Votre compte est banni.'; end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'Montant invalide.';
  end if;
  if p_amount > 100000 then
    raise exception 'Le montant ne peut pas dépasser 100 000 SC.';
  end if;
  if p_interest_rate is not null and (p_interest_rate < 0 or p_interest_rate > 100) then
    raise exception 'Taux d''intérêt invalide (0–100).';
  end if;
  if p_due_date is not null and p_due_date <= now() + interval '10 minutes' then
    raise exception 'La date d''échéance doit être au moins dans 10 minutes.';
  end if;

  insert into chat_messages (
    user_id, username, display_name, avatar_url,
    content, is_censored, class_id, message_type,
    loan_amount, loan_note, loan_interest_rate, loan_due_date,
    expires_at
  ) values (
    v_auth_id, v_user.username, v_user.display_name, v_user.avatar_url,
    coalesce(nullif(trim(p_note), ''), ''),
    false, null, 'loan_request',
    p_amount,
    nullif(trim(coalesce(p_note, '')), ''),
    p_interest_rate,
    p_due_date,
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

grant execute on function public.send_loan_request_chat(numeric, numeric, timestamptz, text) to authenticated;

-- ── 5. accept_chat_loan_request : un utilisateur accepte une demande de prêt ──

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

  select * into v_lender from profiles where id = v_lender_id;
  if v_lender.id is null then raise exception 'Profil introuvable.'; end if;
  if v_lender.is_banned then raise exception 'Votre compte est banni.'; end if;

  select * into v_message from chat_messages
  where id = p_message_id and message_type = 'loan_request' and not is_deleted
  for update;

  if v_message.id is null then
    raise exception 'Demande introuvable ou déjà traitée.';
  end if;
  if v_message.user_id = v_lender_id then
    raise exception 'Impossible d''accepter votre propre demande.';
  end if;

  select * into v_borrower from profiles where id = v_message.user_id;
  if v_borrower.id is null then raise exception 'Emprunteur introuvable.'; end if;

  if v_message.loan_amount > 100000 then
    raise exception 'Montant maximum 100 000 SC.';
  end if;
  if v_lender.balance < v_message.loan_amount then
    raise exception 'Solde insuffisant.';
  end if;

  v_total_due := v_message.loan_amount * (1 + coalesce(v_message.loan_interest_rate, 0) / 100);

  insert into loans (
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

  -- Transférer les fonds
  update profiles set balance = balance - v_message.loan_amount where id = v_lender_id;
  update profiles set balance = balance + v_message.loan_amount where id = v_message.user_id;

  -- Supprimer la demande du chat
  update chat_messages set is_deleted = true where id = p_message_id;

  -- Notifier l'emprunteur
  insert into notifications (user_id, type, title, body, data, is_read)
  values (
    v_message.user_id, 'loan_accepted',
    'Prêt accordé !',
    v_lender.display_name || ' a accepté ta demande de ' ||
      v_message.loan_amount::text || ' SC.',
    jsonb_build_object('loan_id', v_loan_id),
    false
  );

  return jsonb_build_object('loan_id', v_loan_id);
end;
$$;

grant execute on function public.accept_chat_loan_request(uuid) to authenticated;

-- ── 6. Supprimer les anciens messages du chat global (avant migration) ─────────

delete from public.chat_messages
where class_id is null
  and created_at < now();

commit;

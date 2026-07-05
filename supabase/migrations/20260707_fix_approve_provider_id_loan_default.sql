begin;

-- ── 1. approve_account_request : provider_id obligatoire dans auth.identities ──
-- Supabase exige désormais identities.provider_id (NOT NULL). Pour le provider
-- « email », GoTrue utilise l'identifiant de l'utilisateur comme provider_id.

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
    id, user_id, provider_id, identity_data, provider,
    last_sign_in_at, created_at, updated_at
  ) values (
    gen_random_uuid(), v_user_id,
    v_user_id::text,
    jsonb_build_object(
      'sub', v_user_id,
      'email', v_email,
      'email_verified', true
    ),
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
    'Le compte SES Coin a été approuvé. Bienvenue !',
    false
  );
end;
$$;

grant execute on function public.approve_account_request(uuid, numeric) to authenticated;

-- ── 2. Limite quotidienne de prêt : 100 SC par défaut (au lieu de 5000) ────────

alter table public.loan_config
  alter column max_daily_sc set default 100;

-- Ne remplace la valeur que si elle est encore sur l'ancien défaut.
update public.loan_config
set max_daily_sc = 100, updated_at = now()
where id = 1 and max_daily_sc = 5000;

commit;

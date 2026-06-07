begin;

-- ── 1. Corriger submit_account_request : password_hash (pas hashed_password) ──

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

  return to_jsonb(v_request);
end;
$$;

grant execute on function public.submit_account_request(text,text,text,text,text,text,uuid) to anon;
grant execute on function public.submit_account_request(text,text,text,text,text,text,uuid) to authenticated;

-- ── 2. Ajouter les champs taux d'intérêt et date d'échéance aux demandes prêt ──

alter table public.chat_messages
  add column if not exists loan_interest_rate numeric,
  add column if not exists loan_due_date       date;

-- ── 3. Mettre à jour send_loan_request_chat avec les nouveaux champs ──────────

drop function if exists public.send_loan_request_chat(numeric, text);

create or replace function public.send_loan_request_chat(
  p_amount        numeric,
  p_interest_rate numeric default null,
  p_due_date      date    default null,
  p_note          text    default null
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

  if p_interest_rate is not null and (p_interest_rate < 0 or p_interest_rate > 100) then
    raise exception 'Taux d''intérêt invalide (0–100).';
  end if;

  if p_due_date is not null and p_due_date <= current_date then
    raise exception 'La date d''échéance doit être dans le futur.';
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

grant execute on function public.send_loan_request_chat(numeric, numeric, date, text) to authenticated;

-- ── 4. Supprimer les anciens messages du chat global (avant migration) ─────────

delete from public.chat_messages
where class_id is null
  and created_at < now();

commit;

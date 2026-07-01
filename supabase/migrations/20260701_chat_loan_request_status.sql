begin;

alter table public.chat_messages
  add column if not exists loan_status text,
  add column if not exists loan_id uuid,
  add column if not exists loan_accepted_by uuid;

update public.chat_messages
set loan_status = 'pending'
where message_type = 'loan_request'
  and loan_status is null
  and is_deleted = false;

drop function if exists public.send_loan_request_chat(numeric, text);
drop function if exists public.send_loan_request_chat(numeric, numeric, date, text);

create or replace function public.send_loan_request_chat(
  p_amount        numeric,
  p_interest_rate numeric     default null,
  p_due_date      timestamptz default null,
  p_note          text        default null
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
  if v_auth_id is null then raise exception 'Non authentifie.'; end if;

  select * into v_user from public.profiles where id = v_auth_id;
  if v_user.id is null then raise exception 'Profil introuvable.'; end if;
  if v_user.is_banned then raise exception 'Votre compte est banni.'; end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'Montant invalide.';
  end if;
  if p_amount > 100000 then
    raise exception 'Le montant ne peut pas depasser 100 000 SC.';
  end if;
  if p_interest_rate is not null and (p_interest_rate < 0 or p_interest_rate > 100) then
    raise exception 'Taux d''interet invalide (0-100).';
  end if;
  if p_due_date is not null and p_due_date <= now() + interval '10 minutes' then
    raise exception 'La date d''echeance doit etre au moins dans 10 minutes.';
  end if;

  insert into public.chat_messages (
    user_id, username, display_name, avatar_url,
    content, is_censored, class_id, message_type,
    loan_amount, loan_note, loan_interest_rate, loan_due_date,
    loan_status, expires_at
  ) values (
    v_auth_id, v_user.username, v_user.display_name, v_user.avatar_url,
    coalesce(nullif(trim(p_note), ''), ''),
    false, null, 'loan_request',
    p_amount,
    nullif(trim(coalesce(p_note, '')), ''),
    p_interest_rate,
    p_due_date,
    'pending',
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
  if v_lender_id is null then raise exception 'Non authentifie.'; end if;

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
    raise exception 'Demande introuvable ou deja acceptee.';
  end if;
  if v_message.user_id = v_lender_id then
    raise exception 'Impossible d''accepter votre propre demande.';
  end if;
  if v_message.loan_due_date is not null and v_message.loan_due_date <= now() then
    raise exception 'La date d''echeance est deja depassee.';
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
    'Pret accorde !',
    v_lender.display_name || ' a accepte ta demande de ' ||
      v_message.loan_amount::text || ' SC.',
    jsonb_build_object('loan_id', v_loan_id),
    false
  );

  return jsonb_build_object('loan_id', v_loan_id);
end;
$$;

grant execute on function public.accept_chat_loan_request(uuid) to authenticated;

commit;

begin;

alter table public.chat_messages
  add column if not exists loan_status text,
  add column if not exists loan_id uuid,
  add column if not exists loan_accepted_by uuid;

alter table public.chat_messages
  alter column loan_due_date type timestamptz
  using loan_due_date::timestamptz;

drop function if exists public.send_loan_request_chat(numeric, text);
drop function if exists public.send_loan_request_chat(numeric, numeric, date, text);

drop function if exists public.send_loan_request_chat(numeric, numeric, timestamptz, text);

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

commit;

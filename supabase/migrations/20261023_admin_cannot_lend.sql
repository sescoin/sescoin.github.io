-- ============================================================
-- L'administrateur ne prete pas
--
-- request_loan refusait deja un administrateur comme preteur, mais deux
-- chemins restaient ouverts :
--   - accept_chat_loan_request : l'administrateur pouvait accepter une
--     demande de pret publiee dans les annonces ou dans une classe ;
--   - accept_loan : un administrateur preteur acceptait sans etre debite
--     (creation monetaire), pour d'anciennes demandes restees en attente.
-- On ferme les deux. Emprunter reste possible.
-- ============================================================

-- ── 1. Demande publiee dans le chat ──────────────────────────────────────────
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
  v_due_date  timestamptz;
begin
  if v_lender_id is null then raise exception 'Non authentifié.'; end if;

  select * into v_lender from public.profiles where id = v_lender_id for update;
  if v_lender.id is null then raise exception 'Profil introuvable.'; end if;
  if v_lender.role = 'admin' then
    raise exception 'Un administrateur ne peut pas prêter d''argent.';
  end if;
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
  -- Le controle ne vaut que pour une echeance fixe : une demande exprimee en
  -- duree ne peut pas etre « depassee ».
  if v_message.loan_duration_minutes is null
     and v_message.loan_due_date is not null
     and v_message.loan_due_date <= now() then
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

  -- Le compte a rebours demarre ici, pas a l'envoi de la demande.
  v_due_date := case
    when v_message.loan_duration_minutes is not null
      then now() + make_interval(mins => v_message.loan_duration_minutes)
    else v_message.loan_due_date
  end;

  v_total_due := v_message.loan_amount * (1 + coalesce(v_message.loan_interest_rate, 0) / 100);

  insert into public.loans (
    lender_id, lender_username,
    borrower_id, borrower_username,
    principal, interest_rate, total_due, amount_repaid,
    due_date, duration_minutes, note, status
  ) values (
    v_lender_id, v_lender.username,
    v_message.user_id, v_borrower.username,
    v_message.loan_amount,
    coalesce(v_message.loan_interest_rate, 0),
    v_total_due, 0,
    v_due_date,
    v_message.loan_duration_minutes,
    v_message.loan_note,
    'active'
  ) returning id into v_loan_id;

  update public.profiles set balance = balance - v_message.loan_amount where id = v_lender_id;
  update public.profiles set balance = balance + v_message.loan_amount where id = v_message.user_id;

  -- L'echeance retenue est reportee sur la demande, pour que le chat affiche
  -- la meme date que le pret.
  update public.chat_messages
  set loan_status = 'accepted',
      loan_id = v_loan_id,
      loan_accepted_by = v_lender_id,
      loan_due_date = v_due_date
  where id = p_message_id;

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

  return jsonb_build_object('loan_id', v_loan_id, 'due_date', v_due_date);
end;
$$;

grant execute on function public.accept_chat_loan_request(uuid) to authenticated;

-- ── 2. Demande adressee a un preteur precis ──────────────────────────────────
create or replace function public.accept_loan(p_loan_id uuid, p_lender_id uuid)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_loan   public.loans%rowtype;
  v_lender public.profiles%rowtype;
begin
  if auth.uid() <> p_lender_id then raise exception 'Non autorisé.'; end if;

  select * into v_loan
  from public.loans
  where id = p_loan_id and lender_id = p_lender_id and status = 'pending'
  for update;
  if not found then raise exception 'Prêt introuvable.'; end if;

  -- Le controle ne vaut que pour une echeance fixe : une demande exprimee en
  -- duree ne peut pas etre « depassee ».
  if v_loan.duration_minutes is null
     and v_loan.due_date is not null
     and v_loan.due_date <= now() then
    raise exception 'La date d''échéance est déjà dépassée.';
  end if;

  select * into v_lender from public.profiles where id = p_lender_id for update;

  if v_lender.role = 'admin' then
    raise exception 'Un administrateur ne peut pas prêter d''argent.';
  end if;
  if v_lender.balance < v_loan.principal then
    raise exception 'Solde insuffisant.';
  end if;

  update public.profiles set balance = balance - v_loan.principal where id = p_lender_id;
  update public.profiles set balance = balance + v_loan.principal where id = v_loan.borrower_id;

  update public.loans
  set status = 'active',
      due_date = case
        when duration_minutes is not null
          then now() + make_interval(mins => duration_minutes)
        else due_date
      end
  where id = p_loan_id
  returning * into v_loan;

  insert into public.transactions (from_user_id, to_user_id, amount, type, description, metadata)
  values (
    p_lender_id, v_loan.borrower_id, v_loan.principal,
    'loan', 'Prêt accordé', jsonb_build_object('loan_id', v_loan.id)
  );

  insert into public.notifications (user_id, type, title, body, data)
  values (
    v_loan.borrower_id, 'loan_accepted', 'Prêt accepté',
    'Le prêt de ' || v_loan.principal || ' SC a été accepté.',
    jsonb_build_object('loan_id', v_loan.id)
  );

  return to_jsonb(v_loan);
end;
$$;

grant execute on function public.accept_loan(uuid, uuid) to authenticated;

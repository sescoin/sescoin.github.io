begin;

create or replace function public.process_overdue_loans()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_loan record;
  v_remaining numeric(12,2);
  v_count integer := 0;
begin
  for v_loan in
    select *
    from public.loans
    where status = 'active'
      and due_date is not null
      and due_date <= now()
    for update
  loop
    v_remaining := greatest(v_loan.total_due - v_loan.amount_repaid, 0);

    if v_remaining > 0 then
      update public.profiles
      set balance = balance - v_remaining
      where id = v_loan.borrower_id;

      update public.profiles
      set balance = balance + v_remaining
      where id = v_loan.lender_id;

      insert into public.transactions (
        from_user_id,
        to_user_id,
        amount,
        type,
        description,
        metadata
      )
      values (
        v_loan.borrower_id,
        v_loan.lender_id,
        v_remaining,
        'loan',
        'Prelevement automatique pret en retard',
        jsonb_build_object(
          'loan_id', v_loan.id,
          'auto_default', true
        )
      );
    end if;

    update public.loans
    set
      amount_repaid = total_due,
      status = 'defaulted',
      updated_at = now()
    where id = v_loan.id;

    insert into public.notifications (user_id, type, title, body, data)
    values (
      v_loan.borrower_id,
      'loan_overdue',
      'Pret en retard',
      'Le montant restant de ton pret a ete preleve automatiquement.',
      jsonb_build_object('loan_id', v_loan.id, 'amount', v_remaining)
    );

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

create or replace function public.request_loan(
  p_borrower_id uuid,
  p_lender_id uuid,
  p_principal numeric,
  p_interest_rate numeric,
  p_total_due numeric,
  p_due_date timestamptz default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_borrower public.profiles%rowtype;
  v_lender public.profiles%rowtype;
  v_loan public.loans%rowtype;
begin
  perform public.process_overdue_loans();

  if auth.uid() <> p_borrower_id then
    raise exception 'Non autorise.';
  end if;
  if p_borrower_id = p_lender_id then
    raise exception 'Impossible de se preter a soi-meme.';
  end if;
  if p_principal <= 0 then
    raise exception 'Montant invalide.';
  end if;

  select * into v_borrower
  from public.profiles
  where id = p_borrower_id
  for update;

  select * into v_lender
  from public.profiles
  where id = p_lender_id;

  if v_borrower.id is null or v_lender.id is null then
    raise exception 'Compte introuvable.';
  end if;

  if v_lender.role = 'admin' then
    raise exception 'Impossible de demander un pret a un administrateur.';
  end if;

  if v_borrower.balance < 10 then
    raise exception 'Solde insuffisant pour contracter un pret. Minimum requis : 10 SC.';
  end if;

  insert into public.loans (
    lender_id,
    lender_username,
    borrower_id,
    borrower_username,
    principal,
    interest_rate,
    total_due,
    amount_repaid,
    status,
    due_date,
    note
  )
  values (
    p_lender_id,
    v_lender.username,
    p_borrower_id,
    v_borrower.username,
    p_principal,
    p_interest_rate,
    p_total_due,
    0,
    'pending',
    p_due_date,
    p_note
  )
  returning * into v_loan;

  insert into public.notifications (user_id, type, title, body, data)
  values (
    p_lender_id,
    'loan_requested',
    'Demande de pret',
    v_borrower.username || ' te demande un pret de ' || p_principal || ' SC.',
    jsonb_build_object('loan_id', v_loan.id)
  );

  return to_jsonb(v_loan);
end;
$$;

grant execute on function public.process_overdue_loans() to authenticated;

commit;

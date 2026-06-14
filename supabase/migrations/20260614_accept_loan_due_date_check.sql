begin;

create or replace function public.accept_loan(p_loan_id uuid, p_lender_id uuid)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_loan   public.loans%rowtype;
  v_lender public.profiles%rowtype;
begin
  if auth.uid() <> p_lender_id then raise exception 'Non autorise.'; end if;

  select * into v_loan
  from public.loans
  where id = p_loan_id and lender_id = p_lender_id and status = 'pending'
  for update;
  if not found then raise exception 'Prêt introuvable.'; end if;

  if v_loan.due_date is not null and v_loan.due_date <= now() then
    raise exception 'La date d''échéance est déjà dépassée.';
  end if;

  select * into v_lender from public.profiles where id = p_lender_id for update;

  if v_lender.role <> 'admin' and v_lender.balance < v_loan.principal then
    raise exception 'Solde insuffisant.';
  end if;

  if v_lender.role <> 'admin' then
    update public.profiles set balance = balance - v_loan.principal where id = p_lender_id;
  end if;

  update public.profiles set balance = balance + v_loan.principal where id = v_loan.borrower_id;
  update public.loans set status = 'active' where id = p_loan_id returning * into v_loan;

  insert into public.transactions (from_user_id, to_user_id, amount, type, description, metadata)
  values (
    p_lender_id, v_loan.borrower_id, v_loan.principal,
    'loan', 'Prêt accordé', jsonb_build_object('loan_id', v_loan.id)
  );

  insert into public.notifications (user_id, type, title, body, data)
  values (
    v_loan.borrower_id, 'loan_accepted', 'Prêt accepté',
    'Ton prêt de ' || v_loan.principal || ' SC a été accepté.',
    jsonb_build_object('loan_id', v_loan.id)
  );

  return to_jsonb(v_loan);
end;
$$;

commit;

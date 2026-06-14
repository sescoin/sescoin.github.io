begin;

create or replace function public.process_overdue_loans()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_loan              record;
  v_remaining         numeric(12,2);
  v_borrower_balance  numeric(12,2);
  v_actual_debit      numeric(12,2);
  v_count             integer := 0;
begin
  for v_loan in
    select *
    from public.loans
    where status = 'active'
      and due_date is not null
      and due_date <= now()
    for update
  loop
    v_remaining    := greatest(v_loan.total_due - v_loan.amount_repaid, 0);
    v_actual_debit := 0;

    if v_remaining > 0 then
      select balance into v_borrower_balance
      from public.profiles
      where id = v_loan.borrower_id;

      v_actual_debit := greatest(
        least(v_remaining, greatest(coalesce(v_borrower_balance, 0), 0)),
        0
      );

      if v_actual_debit > 0 then
        update public.profiles
        set balance = balance - v_actual_debit
        where id = v_loan.borrower_id;

        update public.profiles
        set balance = balance + v_actual_debit
        where id = v_loan.lender_id;

        insert into public.transactions (
          from_user_id, to_user_id, amount, type, description, metadata
        )
        values (
          v_loan.borrower_id,
          v_loan.lender_id,
          v_actual_debit,
          'loan',
          'Prélèvement automatique, prêt en retard',
          jsonb_build_object(
            'loan_id',      v_loan.id,
            'auto_default', true,
            'partial',      v_actual_debit < v_remaining
          )
        );

        insert into public.notifications (user_id, type, title, body, data)
        values (
          v_loan.lender_id,
          'loan_repaid',
          'Remboursement reçu',
          'Tu as reçu un remboursement de ' || v_actual_debit || ' SC.',
          jsonb_build_object('loan_id', v_loan.id)
        );
      end if;
    end if;

    update public.loans
    set
      amount_repaid = v_loan.amount_repaid + v_actual_debit,
      status        = 'defaulted',
      updated_at    = now()
    where id = v_loan.id;

    insert into public.notifications (user_id, type, title, body, data)
    values (
      v_loan.borrower_id,
      'loan_overdue',
      'Prêt en retard',
      case
        when v_actual_debit > 0
          then 'Ton prêt de ' || v_loan.principal || ' SC est arrivé à échéance. '
            || v_actual_debit || ' SC ont été prélevés automatiquement.'
        else 'Ton prêt de ' || v_loan.principal
          || ' SC est arrivé à échéance. Aucun fonds disponible pour le prélèvement.'
      end,
      jsonb_build_object('loan_id', v_loan.id, 'amount', v_actual_debit)
    );

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

grant execute on function public.process_overdue_loans() to authenticated;

commit;

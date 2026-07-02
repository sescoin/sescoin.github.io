begin;

create or replace function public.delete_loan(
  p_loan_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_loan public.loans;
begin
  select *
  into v_loan
  from public.loans
  where id = p_loan_id;

  if v_loan.id is null then
    raise exception 'Prêt introuvable';
  end if;

  if auth.uid() is distinct from v_loan.borrower_id
     and auth.uid() is distinct from v_loan.lender_id
     and not public.current_profile_is_admin() then
    raise exception 'Accès refusé';
  end if;

  if v_loan.status not in ('repaid', 'rejected', 'cancelled', 'defaulted')
     and not (
       v_loan.status = 'pending'
       and v_loan.due_date is not null
       and v_loan.due_date <= now()
     ) then
    raise exception 'Seuls les prêts archivés ou expirés peuvent être supprimés';
  end if;

  delete from public.loans
  where id = p_loan_id;
end;
$$;

grant execute on function public.delete_loan(uuid) to authenticated;

commit;

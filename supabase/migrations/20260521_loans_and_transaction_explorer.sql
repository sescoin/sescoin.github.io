begin;

create or replace function public.reject_loan(
  p_loan_id uuid,
  p_lender_id uuid
)
returns public.loans
language plpgsql
security definer
set search_path = public
as $$
declare
  v_loan public.loans;
begin
  if auth.uid() is distinct from p_lender_id and not public.current_profile_is_admin() then
    raise exception 'Accès refusé';
  end if;

  update public.loans
  set
    status = 'rejected',
    updated_at = now()
  where id = p_loan_id
    and lender_id = p_lender_id
    and status = 'pending'
  returning * into v_loan;

  if v_loan.id is null then
    raise exception 'Prêt introuvable ou déjà traité';
  end if;

  return v_loan;
end;
$$;

create or replace function public.cancel_loan(
  p_loan_id uuid,
  p_borrower_id uuid
)
returns public.loans
language plpgsql
security definer
set search_path = public
as $$
declare
  v_loan public.loans;
begin
  if auth.uid() is distinct from p_borrower_id and not public.current_profile_is_admin() then
    raise exception 'Accès refusé';
  end if;

  update public.loans
  set
    status = 'cancelled',
    updated_at = now()
  where id = p_loan_id
    and borrower_id = p_borrower_id
    and status = 'pending'
  returning * into v_loan;

  if v_loan.id is null then
    raise exception 'Prêt introuvable ou déjà traité';
  end if;

  return v_loan;
end;
$$;

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

  if v_loan.status not in ('repaid', 'rejected', 'cancelled', 'defaulted') then
    raise exception 'Seuls les prêts archivés peuvent être supprimés';
  end if;

  delete from public.loans
  where id = p_loan_id;
end;
$$;

grant execute on function public.reject_loan(uuid, uuid) to authenticated;
grant execute on function public.cancel_loan(uuid, uuid) to authenticated;
grant execute on function public.delete_loan(uuid) to authenticated;

drop policy if exists "transactions_select_authenticated_feed" on public.transactions;
create policy "transactions_select_authenticated_feed" on public.transactions
  for select to authenticated
  using (true);

commit;

begin;

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
  v_loan public.loans%rowtype;
  v_borrower public.profiles%rowtype;
begin
  if auth.uid() <> p_borrower_id then raise exception 'Non autorisé.'; end if;
  if p_borrower_id = p_lender_id then raise exception 'Impossible de demander un prêt à soi-même.'; end if;
  if p_principal <= 0 then raise exception 'Montant invalide.'; end if;

  select * into v_borrower from public.profiles where id = p_borrower_id;
  if not found then raise exception 'Emprunteur introuvable.'; end if;

  insert into public.loans (
    lender_id, borrower_id, principal, interest_rate, total_due, due_date, note
  ) values (
    p_lender_id, p_borrower_id, p_principal, p_interest_rate, p_total_due, p_due_date, p_note
  )
  returning * into v_loan;

  insert into public.notifications (user_id, type, title, body, data)
  values (
    p_lender_id, 'loan_requested', 'Demande de prêt',
    v_borrower.username || ' te demande un prêt de ' || p_principal || ' SC.',
    jsonb_build_object('loan_id', v_loan.id)
  );

  return to_jsonb(v_loan);
end;
$$;

update public.notifications
set
  title = case
    when title in ('Pret accepte', 'Prêt accepte') then 'Prêt accepté'
    when title in ('Demande de pret', 'Demande de pr?t') then 'Demande de prêt'
    when title in ('Remboursement recu', 'Remboursement reçu') then 'Remboursement reçu'
    else title
  end,
  body = replace(
    replace(
      replace(
        replace(
          replace(
            replace(
              body,
              'te demande un pr?t de ',
              'te demande un prêt de '
            ),
            'Ton pr?t de ',
            'Ton prêt de '
          ),
          'Tu as recu un remboursement de ',
          'Tu as reçu un remboursement de '
        ),
        'a ?t? accept?.',
        'a été accepté.'
      ),
      'pr?t',
      'prêt'
    ),
    'a ?t?',
    'a été'
  )
where type in ('loan_requested', 'loan_accepted', 'loan_repaid')
   or title in ('Pret accepte', 'Prêt accepte', 'Demande de pret', 'Demande de pr?t', 'Remboursement recu')
   or body like '%pr?t%'
   or body like '%a ?t?%'
   or body like '%remboursement de %';

update public.transactions
set description = replace(description, 'pr?t', 'prêt')
where description like '%pr?t%';

commit;

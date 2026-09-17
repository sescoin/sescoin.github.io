-- ============================================================
-- 1. Blockchain : flux global visible par tous
--
-- Le schema de base ne pose que « transactions_select_own_or_admin », qui
-- limite la lecture a ses propres transactions. L'explorateur est un registre
-- public : on retablit la politique permissive du flux (perdue lors d'une
-- reinitialisation depuis schema.sql).
-- ============================================================

drop policy if exists "transactions_select_authenticated_feed" on public.transactions;
create policy "transactions_select_authenticated_feed" on public.transactions
  for select to authenticated
  using (true);

-- ============================================================
-- 2. Prets cibles exprimes en duree
--
-- Le chat sait deja porter une duree (migration 20260816) : l'echeance est
-- calculee a l'acceptation. Les demandes adressees a des preteurs precis
-- figeaient encore une date a l'envoi. On aligne les deux flux.
-- ============================================================

-- Filet de securite : si la 20260816 n'a pas ete rejouee apres une
-- reinitialisation, les colonnes de duree manquent et l'insertion echouerait.
alter table public.loans
  add column if not exists duration_minutes integer;

alter table public.chat_messages
  add column if not exists loan_duration_minutes integer;

create or replace function public.request_loan(
  p_borrower_id      uuid,
  p_lender_id        uuid,
  p_principal        numeric,
  p_interest_rate    numeric,
  p_total_due        numeric,
  p_due_date         timestamptz default null,
  p_note             text        default null,
  p_duration_minutes integer     default null
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
    raise exception 'Non autorisé.';
  end if;
  if p_borrower_id = p_lender_id then
    raise exception 'Impossible de se prêter à soi-même.';
  end if;
  if p_principal <= 0 then
    raise exception 'Montant invalide.';
  end if;

  -- Une demande porte soit une échéance, soit une durée, jamais les deux.
  if p_duration_minutes is not null then
    if p_duration_minutes < 5 then
      raise exception 'La durée doit valoir au moins 5 minutes.';
    end if;
    if p_duration_minutes > 30 * 1440 then
      raise exception 'La durée ne peut pas dépasser 30 jours.';
    end if;
    p_due_date := null;
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
    raise exception 'Impossible de demander un prêt à un administrateur.';
  end if;

  if v_borrower.balance <= 0 then
    raise exception 'Impossible de contracter un prêt avec un solde inférieur ou égal à 0.';
  end if;

  if v_borrower.balance < 10 then
    raise exception 'Solde insuffisant pour contracter un prêt. Minimum requis : 10 SC.';
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
    duration_minutes,
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
    p_duration_minutes,
    p_note
  )
  returning * into v_loan;

  insert into public.notifications (user_id, type, title, body, data)
  values (
    p_lender_id,
    'loan_requested',
    'Demande de prêt',
    v_borrower.username || ' te demande un prêt de ' || p_principal || ' SC.',
    jsonb_build_object('loan_id', v_loan.id)
  );

  return to_jsonb(v_loan);
end;
$$;

-- L'ancienne signature a sept arguments rendrait l'appel ambigu : on la retire.
drop function if exists public.request_loan(
  uuid, uuid, numeric, numeric, numeric, timestamptz, text
);

grant execute on function public.request_loan(
  uuid, uuid, numeric, numeric, numeric, timestamptz, text, integer
) to authenticated;

-- ── Acceptation : le compte à rebours démarre ici ────────────────────────────

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

  -- Le contrôle ne vaut que pour une échéance fixe : une demande exprimée en
  -- durée ne peut pas être « dépassée ».
  if v_loan.duration_minutes is null
     and v_loan.due_date is not null
     and v_loan.due_date <= now() then
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

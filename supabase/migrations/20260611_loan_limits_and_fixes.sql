begin;

-- ── 1. Corriger process_overdue_loans : ne jamais mettre le solde en négatif ──

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
      -- Récupérer le solde actuel de l'emprunteur
      select balance into v_borrower_balance
      from public.profiles
      where id = v_loan.borrower_id;

      -- Ne débiter que ce qui est disponible (pas de solde négatif)
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
          'Prelevement automatique pret en retard',
          jsonb_build_object(
            'loan_id',     v_loan.id,
            'auto_default', true,
            'partial',      v_actual_debit < v_remaining
          )
        );
      end if;
    end if;

    -- Mettre à jour amount_repaid avec ce qui a réellement été débité
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
      'Pret en retard',
      case
        when v_actual_debit > 0
          then 'Ton pret de ' || v_loan.principal || ' SC est arrive a echeance. '
            || v_actual_debit || ' SC ont ete preleves automatiquement.'
        else 'Ton pret de ' || v_loan.principal
          || ' SC est arrive a echeance. Aucun fonds disponible pour le prelevement.'
      end,
      jsonb_build_object('loan_id', v_loan.id, 'amount', v_actual_debit)
    );

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

-- ── 2. request_loan : limites 5 000 SC/jour, 1 000 SC/semaine + solde négatif ─

create or replace function public.request_loan(
  p_borrower_id  uuid,
  p_lender_id    uuid,
  p_principal    numeric,
  p_interest_rate numeric,
  p_total_due    numeric,
  p_due_date     timestamptz default null,
  p_note         text        default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_borrower    public.profiles%rowtype;
  v_lender      public.profiles%rowtype;
  v_loan        public.loans%rowtype;
  v_daily_total  numeric(12,2);
  v_weekly_total numeric(12,2);
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

  -- Solde négatif interdit
  if v_borrower.balance < 0 then
    raise exception 'Impossible de contracter un pret avec un solde negatif.';
  end if;

  if v_borrower.balance < 10 then
    raise exception 'Solde insuffisant pour contracter un pret. Minimum requis : 10 SC.';
  end if;

  -- Limite quotidienne : 5 000 SC par jour
  select coalesce(sum(l.principal), 0) into v_daily_total
  from public.loans l
  where l.borrower_id = p_borrower_id
    and l.created_at  >= date_trunc('day', now())
    and l.status not in ('cancelled', 'rejected');

  if v_daily_total + p_principal > 5000 then
    raise exception
      'Limite quotidienne atteinte. Tu ne peux pas emprunter plus de 5 000 SC par jour (quota restant : % SC).',
      greatest(0, floor(5000 - v_daily_total))::int;
  end if;

  -- Limite hebdomadaire : 1 000 SC par semaine
  select coalesce(sum(l.principal), 0) into v_weekly_total
  from public.loans l
  where l.borrower_id = p_borrower_id
    and l.created_at  >= date_trunc('week', now())
    and l.status not in ('cancelled', 'rejected');

  if v_weekly_total + p_principal > 1000 then
    raise exception
      'Limite hebdomadaire atteinte. Tu ne peux pas emprunter plus de 1 000 SC par semaine (quota restant : % SC).',
      greatest(0, floor(1000 - v_weekly_total))::int;
  end if;

  insert into public.loans (
    lender_id, lender_username, borrower_id, borrower_username,
    principal, interest_rate, total_due, amount_repaid, status, due_date, note
  )
  values (
    p_lender_id,    v_lender.username,
    p_borrower_id,  v_borrower.username,
    p_principal, p_interest_rate, p_total_due, 0, 'pending', p_due_date, p_note
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

-- ── 3. Planifier le traitement automatique via pg_cron (une fois par heure) ───

do $$
begin
  create extension if not exists pg_cron;

  begin
    perform cron.unschedule('process-overdue-loans');
  exception when others then null;
  end;

  perform cron.schedule(
    'process-overdue-loans',
    '0 * * * *',
    $cron$select public.process_overdue_loans()$cron$
  );
exception when others then
  raise notice 'pg_cron non disponible sur ce serveur, traitement automatique ignoré : %', sqlerrm;
end;
$$;

grant execute on function public.process_overdue_loans() to authenticated;
grant execute on function public.request_loan(uuid, uuid, numeric, numeric, numeric, timestamptz, text) to authenticated;

commit;

begin;

-- ── 1. Table loan_config (ligne unique, paramètres des prêts) ─────────────────

create table if not exists public.loan_config (
  id                integer      primary key default 1 check (id = 1),
  max_daily_sc      numeric(12,2) not null default 5000,
  max_weekly_sc     numeric(12,2) not null default 1000,
  max_active_loans  integer      not null default 3,
  max_duration_days integer      not null default 14,
  max_interest_rate numeric(5,2) not null default 100,
  min_balance_sc    numeric(12,2) not null default 10,
  updated_at        timestamptz  not null default now()
);

insert into public.loan_config (id) values (1) on conflict do nothing;

alter table public.loan_config enable row level security;

do $$ begin
  if not exists (
    select 1 from pg_policies
    where tablename = 'loan_config' and policyname = 'loan_config_read'
  ) then
    create policy "loan_config_read"
      on public.loan_config for select to authenticated using (true);
  end if;
end $$;

-- ── 2. Fonction admin : mettre à jour la config ───────────────────────────────

create or replace function public.update_loan_config(
  p_max_daily_sc      numeric,
  p_max_weekly_sc     numeric,
  p_max_active_loans  integer,
  p_max_duration_days integer,
  p_max_interest_rate numeric,
  p_min_balance_sc    numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.profiles where id = auth.uid() and role = 'admin'
  ) then
    raise exception 'Accès réservé aux administrateurs.';
  end if;

  if p_max_daily_sc <= 0 or p_max_weekly_sc <= 0 then
    raise exception 'Les limites doivent être supérieures à zéro.';
  end if;
  if p_max_active_loans < 1 then
    raise exception 'Le nombre de prêts actifs minimum est 1.';
  end if;
  if p_max_duration_days < 1 then
    raise exception 'La durée minimum est 1 jour.';
  end if;
  if p_max_interest_rate < 0 or p_max_interest_rate > 100 then
    raise exception 'Le taux d''intérêt doit être compris entre 0 et 100.';
  end if;
  if p_min_balance_sc < 0 then
    raise exception 'Le solde minimum ne peut pas être négatif.';
  end if;

  update public.loan_config
  set
    max_daily_sc      = p_max_daily_sc,
    max_weekly_sc     = p_max_weekly_sc,
    max_active_loans  = p_max_active_loans,
    max_duration_days = p_max_duration_days,
    max_interest_rate = p_max_interest_rate,
    min_balance_sc    = p_min_balance_sc,
    updated_at        = now()
  where id = 1;
end;
$$;

grant execute on function public.update_loan_config(numeric, numeric, integer, integer, numeric, numeric) to authenticated;

-- ── 3. request_loan : lit la config depuis loan_config ────────────────────────

create or replace function public.request_loan(
  p_borrower_id   uuid,
  p_lender_id     uuid,
  p_principal     numeric,
  p_interest_rate numeric,
  p_total_due     numeric,
  p_due_date      timestamptz default null,
  p_note          text        default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_borrower     public.profiles%rowtype;
  v_lender       public.profiles%rowtype;
  v_loan         public.loans%rowtype;
  v_daily_total  numeric(12,2);
  v_weekly_total numeric(12,2);
  v_active_count integer;
  v_cfg          public.loan_config%rowtype;
begin
  perform public.process_overdue_loans();

  select * into v_cfg from public.loan_config where id = 1;

  if auth.uid() <> p_borrower_id then
    raise exception 'Non autorisé.';
  end if;
  if p_borrower_id = p_lender_id then
    raise exception 'Impossible de se prêter à soi-même.';
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
    raise exception 'Impossible de demander un prêt à un administrateur.';
  end if;

  if v_borrower.balance < 0 then
    raise exception 'Impossible de contracter un prêt avec un solde négatif.';
  end if;

  if v_borrower.balance < v_cfg.min_balance_sc then
    raise exception 'Solde insuffisant pour contracter un prêt. Minimum requis : % SC.', v_cfg.min_balance_sc::int;
  end if;

  select count(*) into v_active_count
  from public.loans
  where borrower_id = p_borrower_id
    and status in ('pending', 'active');

  if v_active_count >= v_cfg.max_active_loans then
    raise exception
      'Tu as déjà % prêts actifs ou en attente. Rembourse-en un avant d''en demander un nouveau.',
      v_cfg.max_active_loans;
  end if;

  -- Limite quotidienne
  select coalesce(sum(l.principal), 0) into v_daily_total
  from public.loans l
  where l.borrower_id = p_borrower_id
    and l.created_at >= date_trunc('day', now())
    and l.status not in ('cancelled', 'rejected');

  if v_daily_total + p_principal > v_cfg.max_daily_sc then
    raise exception
      'Impossible d''emprunter plus de % SC par jour.
quota restant : % SC.',
      v_cfg.max_daily_sc::int,
      greatest(0, floor(v_cfg.max_daily_sc - v_daily_total))::int;
  end if;

  -- Limite hebdomadaire
  select coalesce(sum(l.principal), 0) into v_weekly_total
  from public.loans l
  where l.borrower_id = p_borrower_id
    and l.created_at >= date_trunc('week', now())
    and l.status not in ('cancelled', 'rejected');

  if v_weekly_total + p_principal > v_cfg.max_weekly_sc then
    raise exception
      'Impossible d''emprunter plus de % SC par semaine, quota restant : % SC.',
      v_cfg.max_weekly_sc::int,
      greatest(0, floor(v_cfg.max_weekly_sc - v_weekly_total))::int;
  end if;

  insert into public.loans (
    lender_id, lender_username, borrower_id, borrower_username,
    principal, interest_rate, total_due, amount_repaid, status, due_date, note
  )
  values (
    p_lender_id,   v_lender.username,
    p_borrower_id, v_borrower.username,
    p_principal, p_interest_rate, p_total_due, 0, 'pending', p_due_date, p_note
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

grant execute on function public.request_loan(uuid, uuid, numeric, numeric, numeric, timestamptz, text) to authenticated;

commit;

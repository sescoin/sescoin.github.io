-- ============================================================
-- Pret exprime en duree, et retour de la sourdine sur recidive
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. Duree portee par la demande
--
-- Jusqu'ici, choisir « 3 jours » revenait a figer une echeance au moment de
-- l'envoi : une demande acceptee deux jours plus tard ne laissait qu'un jour
-- pour rembourser. La duree est desormais conservee telle quelle, et
-- l'echeance calculee au moment de l'acceptation.
-- ─────────────────────────────────────────────────────────────
alter table public.chat_messages
  add column if not exists loan_duration_minutes integer;

alter table public.loans
  add column if not exists duration_minutes integer;

-- ─────────────────────────────────────────────────────────────
-- 2. Envoi de la demande
-- ─────────────────────────────────────────────────────────────
create or replace function public.send_loan_request_chat(
  p_amount           numeric,
  p_interest_rate    numeric     default null,
  p_due_date         timestamptz default null,
  p_note             text        default null,
  p_class_id         uuid        default null,
  p_duration_minutes integer     default null
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_auth_id uuid := auth.uid();
  v_user    public.profiles%rowtype;
  v_message public.chat_messages%rowtype;
  v_count   integer;
begin
  if v_auth_id is null then raise exception 'Non authentifié.'; end if;

  select * into v_user from public.profiles where id = v_auth_id;
  if v_user.id is null then raise exception 'Profil introuvable.'; end if;
  if v_user.is_banned then raise exception 'Votre compte est banni.'; end if;

  if p_class_id is not null then
    if not exists (select 1 from public.classes where id = p_class_id) then
      raise exception 'Classe introuvable.';
    end if;
    if v_user.role <> 'admin' and v_user.class_id is distinct from p_class_id then
      raise exception 'Vous n''appartenez pas à cette classe.';
    end if;
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'Montant invalide.';
  end if;
  if p_amount > 100000 then
    raise exception 'Le montant ne peut pas dépasser 100 000 SC.';
  end if;
  if p_interest_rate is not null and (p_interest_rate < 0 or p_interest_rate > 100) then
    raise exception 'Taux d''intérêt invalide (0-100).';
  end if;

  -- Une demande porte soit une echeance, soit une duree, jamais les deux.
  if p_duration_minutes is not null then
    if p_duration_minutes < 5 then
      raise exception 'La durée doit valoir au moins 5 minutes.';
    end if;
    if p_duration_minutes > 30 * 1440 then
      raise exception 'La durée ne peut pas dépasser 30 jours.';
    end if;
    p_due_date := null;
  elsif p_due_date is not null and p_due_date <= now() + interval '5 minutes' then
    raise exception 'La date d''échéance doit être au moins dans 5 minutes.';
  end if;

  if v_user.role <> 'admin' then
    if p_class_id is null then
      select count(*) into v_count from public.chat_messages
      where user_id = v_auth_id and message_type = 'loan_request'
        and class_id is null and created_at >= date_trunc('day', now());
      if v_count >= 1 then
        raise exception 'Limite atteinte : 1 demande de prêt par jour dans les annonces.';
      end if;
    else
      select count(*) into v_count from public.chat_messages
      where user_id = v_auth_id and message_type = 'loan_request'
        and class_id = p_class_id and created_at >= date_trunc('day', now());
      if v_count >= 2 then
        raise exception 'Limite atteinte : 2 demandes de prêt par jour dans cette classe.';
      end if;
    end if;
  end if;

  insert into public.chat_messages (
    user_id, username, display_name, avatar_url,
    content, is_censored, class_id, message_type,
    loan_amount, loan_note, loan_interest_rate, loan_due_date,
    loan_duration_minutes, loan_status, expires_at
  ) values (
    v_auth_id, v_user.username, v_user.display_name, v_user.avatar_url,
    coalesce(nullif(trim(p_note), ''), ''),
    false, p_class_id, 'loan_request',
    p_amount,
    nullif(trim(coalesce(p_note, '')), ''),
    p_interest_rate,
    p_due_date,
    p_duration_minutes,
    'pending',
    now() + interval '24 hours'
  ) returning * into v_message;

  return jsonb_build_object(
    'message', to_jsonb(v_message),
    'warning', false, 'warning_count', 0, 'muted', false
  );
end;
$$;

-- L'ancienne signature a cinq arguments subsisterait en surcharge et rendrait
-- l'appel ambigu : on la retire.
drop function if exists public.send_loan_request_chat(
  numeric, numeric, timestamptz, text, uuid
);

grant execute on function public.send_loan_request_chat(
  numeric, numeric, timestamptz, text, uuid, integer
) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- 3. Acceptation : l'echeance part de maintenant
-- ─────────────────────────────────────────────────────────────
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

-- ─────────────────────────────────────────────────────────────
-- 4. Sourdine apres trois signalements retenus
--
-- Retablie sans la notification au signaleur, qui n'apportait rien.
-- ─────────────────────────────────────────────────────────────
create or replace function public.confirmed_reports_count(p_user_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(distinct message_id)::int
  from public.reports
  where reported_id = p_user_id and status = 'reviewed';
$$;

grant execute on function public.confirmed_reports_count(uuid) to authenticated;

create or replace function public.on_report_reviewed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_confirmed integer;
  v_username text;
begin
  if old.status = new.status or new.status <> 'reviewed' then
    return new;
  end if;

  v_confirmed := public.confirmed_reports_count(new.reported_id);
  if v_confirmed < 3 then
    return new;
  end if;

  select username into v_username
  from public.profiles where id = new.reported_id;

  update public.profiles
  set chat_muted_until = greatest(
    coalesce(chat_muted_until, now()),
    now() + interval '24 hours'
  )
  where id = new.reported_id;

  insert into public.sanctions (
    user_id, username, kind, reason, until, automatic
  ) values (
    new.reported_id, v_username, 'mute',
    v_confirmed || ' signalements retenus',
    now() + interval '24 hours', true
  );

  -- Pas de notification : le bandeau du chat porte deja l'information.
  return new;
end;
$$;

drop trigger if exists trg_on_report_reviewed on public.reports;
create trigger trg_on_report_reviewed
  after update of status on public.reports
  for each row execute function public.on_report_reviewed();

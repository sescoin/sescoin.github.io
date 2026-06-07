begin;

-- ── 1. Corriger "Message censure" → "Message censuré" ────────────────────────

-- Corriger les messages déjà censurés en base
update public.chat_messages
set content = 'Message censuré'
where is_censored = true
  and content = 'Message censure';

-- Réécrire edit_chat_message avec l'accent correct
create or replace function public.edit_chat_message(
  p_message_id uuid,
  p_content    text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_id       uuid := auth.uid();
  v_user          public.profiles%rowtype;
  v_message       public.chat_messages%rowtype;
  v_lower         text;
  v_is_bad        boolean := false;
  v_bad_patterns  text[] := array[
    'connard', 'connasse', 'conne ', 'espece de con',
    'salope', 'sale pute', 'pute', 'putain de',
    'fdp', 'fils de pute', 'fille de pute',
    'nique ta', 'nique sa', 'va te faire niquer', 'ntm',
    'encule', 'enculer', 'va te faire enc',
    'batard', 'fils de',
    'trouduc', 'trou du cul', 'ta gueule', 'ferme ta gueule', 'ftg',
    'va te faire', 'vtff', 'va crever', 'creve',
    'abruti', 'imbecile', 'cretin', 'debile',
    'pede', ' pd ', 'grosse merde',
    'je vais te tuer', 'je vais vous tuer', 'je vais te frapper',
    'je vais te casser', 'je vais t''eclater', 'on va te',
    'tue toi', 'suicide toi', 'va mourir', 'tu vas mourir',
    'mort a '
  ];
  v_pat text;
begin
  if v_auth_id is null then
    raise exception 'Non authentifié.';
  end if;

  select * into v_user from public.profiles where id = v_auth_id;
  if v_user.id is null then raise exception 'Profil introuvable.'; end if;
  if v_user.is_banned then raise exception 'Votre compte est banni.'; end if;

  select * into v_message
  from public.chat_messages
  where id = p_message_id and not is_deleted
  for update;

  if v_message.id is null then raise exception 'Message introuvable.'; end if;
  if v_message.user_id is distinct from v_auth_id then
    raise exception 'Modification non autorisée.';
  end if;

  if v_user.chat_muted_until is not null and v_user.chat_muted_until <= now() then
    update public.profiles
    set chat_muted_until = null, chat_warning_count = 0
    where id = v_auth_id
    returning * into v_user;
  end if;

  if v_user.chat_muted_until is not null and v_user.chat_muted_until > now() then
    raise exception 'Vous êtes muet pour encore % minute(s).',
      greatest(1, ceil(extract(epoch from (v_user.chat_muted_until - now())) / 60)::int);
  end if;

  if length(trim(p_content)) = 0 then raise exception 'Message vide.'; end if;
  if length(p_content) > 500 then raise exception 'Message trop long (500 caractères max).'; end if;

  v_lower := lower(p_content);
  foreach v_pat in array v_bad_patterns loop
    if v_lower like '%' || v_pat || '%' then
      v_is_bad := true;
      exit;
    end if;
  end loop;

  if v_is_bad then
    update public.profiles
    set chat_warning_count = chat_warning_count + 1
    where id = v_auth_id
    returning * into v_user;

    if v_user.chat_warning_count >= 3 then
      update public.profiles
      set chat_muted_until = now() + interval '10 minutes'
      where id = v_auth_id
      returning * into v_user;
    end if;

    update public.chat_messages
    set content    = 'Message censuré',
        is_censored = true,
        edited_at  = now()
    where id = p_message_id
    returning * into v_message;

    return jsonb_build_object(
      'message',       to_jsonb(v_message),
      'warning',       true,
      'warning_count', v_user.chat_warning_count,
      'muted',         v_user.chat_muted_until is not null
    );
  end if;

  update public.chat_messages
  set content    = trim(p_content),
      is_censored = false,
      edited_at  = now()
  where id = p_message_id
  returning * into v_message;

  return jsonb_build_object(
    'message',       to_jsonb(v_message),
    'warning',       false,
    'warning_count', v_user.chat_warning_count,
    'muted',         false
  );
end;
$$;

grant execute on function public.edit_chat_message(uuid, text) to authenticated;

-- ── 2. Garantir que approve_avatar_change envoie une notification ─────────────

create or replace function public.approve_avatar_change(p_user_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.current_profile_is_admin() then
    raise exception 'Action réservée à l''administrateur.';
  end if;

  update public.profiles
  set avatar_url         = pending_avatar_url,
      pending_avatar_url = null,
      updated_at         = now()
  where id = p_user_id and pending_avatar_url is not null;

  -- Supprimer la notif admin d'examen de photo
  delete from public.notifications
  where type = 'system'
    and data->>'action' = 'review_avatar'
    and data->>'user_id' = p_user_id::text;

  -- Notifier l'utilisateur que sa photo a été acceptée
  insert into public.notifications (user_id, type, title, body, data, is_read)
  values (
    p_user_id,
    'system',
    'Photo de profil acceptée',
    'Ta nouvelle photo de profil a été acceptée.',
    jsonb_build_object('action', 'avatar_approved'),
    false
  );
end;
$$;

grant execute on function public.approve_avatar_change(uuid) to authenticated;

-- Pareil pour reject_avatar_change (accents + notification)
create or replace function public.reject_avatar_change(p_user_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.current_profile_is_admin() then
    raise exception 'Action réservée à l''administrateur.';
  end if;

  update public.profiles
  set pending_avatar_url = null,
      updated_at         = now()
  where id = p_user_id;

  delete from public.notifications
  where type = 'system'
    and data->>'action' = 'review_avatar'
    and data->>'user_id' = p_user_id::text;

  insert into public.notifications (user_id, type, title, body, data, is_read)
  values (
    p_user_id,
    'system',
    'Photo de profil refusée',
    'Ta demande de changement de photo a été refusée.',
    jsonb_build_object('action', 'avatar_rejected'),
    false
  );
end;
$$;

grant execute on function public.reject_avatar_change(uuid) to authenticated;

-- ── 3. Corriger accept_loan : "Prêt accepté" avec accent ─────────────────────

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

  insert into public.notifications (user_id, type, title, body, data, is_read)
  values (
    v_loan.borrower_id, 'loan_accepted', 'Prêt accepté',
    'Ton prêt de ' || v_loan.principal || ' SC a été accepté.',
    jsonb_build_object('loan_id', v_loan.id),
    false
  );

  return to_jsonb(v_loan);
end;
$$;

grant execute on function public.accept_loan(uuid, uuid) to authenticated;

-- ── 4. Rembourser automatiquement les prêts actifs sans date d'échéance ───────

do $$
declare
  v_loan  record;
  v_borrower_balance numeric;
begin
  for v_loan in
    select l.*, p.balance as borrower_balance
    from public.loans l
    join public.profiles p on p.id = l.borrower_id
    where l.status = 'active'
      and l.due_date is null
  loop
    if v_loan.borrower_balance >= v_loan.total_due then
      -- Remboursement complet : débit emprunteur, crédit prêteur
      update public.profiles set balance = balance - v_loan.total_due where id = v_loan.borrower_id;
      update public.profiles set balance = balance + v_loan.total_due where id = v_loan.lender_id;
      update public.loans
      set status        = 'repaid',
          amount_repaid = v_loan.total_due,
          updated_at    = now()
      where id = v_loan.id;
    else
      -- Solde insuffisant : remboursement partiel avec ce qui reste
      update public.profiles set balance = 0 where id = v_loan.borrower_id;
      update public.profiles set balance = balance + v_loan.borrower_balance where id = v_loan.lender_id;
      update public.loans
      set status        = 'repaid',
          amount_repaid = v_loan.borrower_balance,
          repaid_at     = now()
      where id = v_loan.id;
    end if;
  end loop;
end;
$$;

commit;

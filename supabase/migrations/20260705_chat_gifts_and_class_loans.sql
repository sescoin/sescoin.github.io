-- Cadeaux dans le chat (annonces + classe) et demandes de prêt de classe.
--
-- Cadeau : l'expéditeur met une somme en jeu dans le chat ; le premier
-- utilisateur qui clique « Récupérer » l'empoche (opération atomique).
-- L'admin crée la monnaie (pas de débit), un élève est débité à l'envoi.

begin;

-- ── 1. Colonnes cadeaux sur les messages ─────────────────────────────────────

alter table public.chat_messages
  add column if not exists gift_amount numeric,
  add column if not exists gift_claimed_by uuid,
  add column if not exists gift_claimed_username text,
  add column if not exists gift_claimed_at timestamptz;

-- ── 2. Nouveau type de transaction ───────────────────────────────────────────

alter table public.transactions drop constraint if exists transactions_type_check;
alter table public.transactions add constraint transactions_type_check check (
  type in (
    'transfer', 'purchase', 'auction', 'loan',
    'reward', 'tax', 'admin_credit', 'admin_debit', 'initial_balance', 'gift'
  )
);

-- ── 3. Envoyer un cadeau ─────────────────────────────────────────────────────
-- p_class_id null  -> chat Annonces (admin uniquement)
-- p_class_id non null -> chat de classe (membres de la classe ou admin)

create or replace function public.send_chat_gift(
  p_amount   numeric,
  p_note     text default null,
  p_class_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_id uuid := auth.uid();
  v_user    public.profiles%rowtype;
  v_message public.chat_messages%rowtype;
begin
  if v_auth_id is null then raise exception 'Non authentifie.'; end if;

  select * into v_user from public.profiles where id = v_auth_id for update;
  if v_user.id is null then raise exception 'Profil introuvable.'; end if;
  if v_user.is_banned then raise exception 'Votre compte est banni.'; end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'Montant invalide.';
  end if;
  if p_amount > 100000 then
    raise exception 'Le montant ne peut pas depasser 100 000 SC.';
  end if;

  if p_class_id is null then
    -- Chat Annonces : reserve a l'administrateur
    if v_user.role <> 'admin' then
      raise exception 'Seul l''administrateur peut envoyer un cadeau ici.';
    end if;
  else
    if not exists (select 1 from public.classes where id = p_class_id) then
      raise exception 'Classe introuvable.';
    end if;
    if v_user.role <> 'admin' and v_user.class_id is distinct from p_class_id then
      raise exception 'Vous n''appartenez pas a cette classe.';
    end if;
  end if;

  -- L'admin cree la monnaie ; un utilisateur est debite a l'envoi.
  if v_user.role <> 'admin' then
    if v_user.balance < p_amount then
      raise exception 'Solde insuffisant.';
    end if;
    update public.profiles
    set balance = balance - p_amount
    where id = v_auth_id;
  end if;

  insert into public.chat_messages (
    user_id, username, display_name, avatar_url,
    content, is_censored, class_id, message_type,
    gift_amount, expires_at
  ) values (
    v_auth_id, v_user.username, v_user.display_name, v_user.avatar_url,
    coalesce(nullif(trim(coalesce(p_note, '')), ''), ''),
    false, p_class_id, 'gift',
    p_amount,
    now() + interval '7 days'
  ) returning * into v_message;

  return jsonb_build_object(
    'message', to_jsonb(v_message),
    'warning', false,
    'warning_count', 0,
    'muted', false
  );
end;
$$;

grant execute on function public.send_chat_gift(numeric, text, uuid) to authenticated;

-- ── 4. Récupérer un cadeau (premier arrivé, premier servi) ───────────────────

create or replace function public.claim_chat_gift(p_message_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_id uuid := auth.uid();
  v_user    public.profiles%rowtype;
  v_message public.chat_messages%rowtype;
begin
  if v_auth_id is null then raise exception 'Non authentifie.'; end if;

  select * into v_user from public.profiles where id = v_auth_id for update;
  if v_user.id is null then raise exception 'Profil introuvable.'; end if;
  if v_user.is_banned then raise exception 'Votre compte est banni.'; end if;

  -- Verrou : un seul utilisateur peut passer ici a la fois pour ce message.
  select * into v_message
  from public.chat_messages
  where id = p_message_id
    and message_type = 'gift'
    and not is_deleted
  for update;

  if v_message.id is null then
    raise exception 'Cadeau introuvable.';
  end if;
  if v_message.gift_claimed_by is not null then
    raise exception 'Trop tard ! Ce cadeau a deja ete recupere.';
  end if;
  if v_message.expires_at is not null and v_message.expires_at <= now() then
    raise exception 'Ce cadeau a expire.';
  end if;
  if v_message.user_id = v_auth_id then
    raise exception 'Impossible de recuperer votre propre cadeau.';
  end if;
  if v_message.class_id is not null
     and v_user.role <> 'admin'
     and v_user.class_id is distinct from v_message.class_id then
    raise exception 'Ce cadeau est reserve a une autre classe.';
  end if;

  update public.chat_messages
  set gift_claimed_by = v_auth_id,
      gift_claimed_username = v_user.username,
      gift_claimed_at = now()
  where id = p_message_id;

  update public.profiles
  set balance = balance + v_message.gift_amount
  where id = v_auth_id;

  insert into public.transactions (
    from_user_id, to_user_id, amount, type, description, metadata
  ) values (
    v_message.user_id, v_auth_id, v_message.gift_amount, 'gift',
    'Cadeau du chat recupere',
    jsonb_build_object('chat_message_id', p_message_id)
  );

  -- Prevenir l'expediteur
  insert into public.notifications (user_id, type, title, body, data, is_read)
  values (
    v_message.user_id, 'system',
    'Cadeau récupéré !',
    v_user.display_name || ' a récupéré ton cadeau de ' ||
      v_message.gift_amount::text || ' SC.',
    jsonb_build_object('chat_message_id', p_message_id),
    false
  );

  return jsonb_build_object(
    'claimed', true,
    'amount', v_message.gift_amount
  );
end;
$$;

grant execute on function public.claim_chat_gift(uuid) to authenticated;

-- ── 5. Demande de prêt dans le chat de classe ────────────────────────────────
-- Même fonction que pour les annonces, avec une classe optionnelle.

drop function if exists public.send_loan_request_chat(numeric, numeric, timestamptz, text);

create or replace function public.send_loan_request_chat(
  p_amount        numeric,
  p_interest_rate numeric     default null,
  p_due_date      timestamptz default null,
  p_note          text        default null,
  p_class_id      uuid        default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_id uuid := auth.uid();
  v_user    public.profiles%rowtype;
  v_message public.chat_messages%rowtype;
begin
  if v_auth_id is null then raise exception 'Non authentifie.'; end if;

  select * into v_user from public.profiles where id = v_auth_id;
  if v_user.id is null then raise exception 'Profil introuvable.'; end if;
  if v_user.is_banned then raise exception 'Votre compte est banni.'; end if;

  if p_class_id is not null then
    if not exists (select 1 from public.classes where id = p_class_id) then
      raise exception 'Classe introuvable.';
    end if;
    if v_user.role <> 'admin' and v_user.class_id is distinct from p_class_id then
      raise exception 'Vous n''appartenez pas a cette classe.';
    end if;
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'Montant invalide.';
  end if;
  if p_amount > 100000 then
    raise exception 'Le montant ne peut pas depasser 100 000 SC.';
  end if;
  if p_interest_rate is not null and (p_interest_rate < 0 or p_interest_rate > 100) then
    raise exception 'Taux d''interet invalide (0-100).';
  end if;
  if p_due_date is not null and p_due_date <= now() + interval '10 minutes' then
    raise exception 'La date d''echeance doit etre au moins dans 10 minutes.';
  end if;

  insert into public.chat_messages (
    user_id, username, display_name, avatar_url,
    content, is_censored, class_id, message_type,
    loan_amount, loan_note, loan_interest_rate, loan_due_date,
    loan_status, expires_at
  ) values (
    v_auth_id, v_user.username, v_user.display_name, v_user.avatar_url,
    coalesce(nullif(trim(p_note), ''), ''),
    false, p_class_id, 'loan_request',
    p_amount,
    nullif(trim(coalesce(p_note, '')), ''),
    p_interest_rate,
    p_due_date,
    'pending',
    now() + interval '7 days'
  ) returning * into v_message;

  return jsonb_build_object(
    'message', to_jsonb(v_message),
    'warning', false,
    'warning_count', 0,
    'muted', false
  );
end;
$$;

grant execute on function public.send_loan_request_chat(numeric, numeric, timestamptz, text, uuid) to authenticated;

commit;

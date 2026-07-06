-- Correctifs :
-- 1. Transactions système (crédit/débit admin, taxe, récompense, achat) : plus
--    de contrepartie « admin ». L'admin n'apparaît plus dans la blockchain
--    (« utilisateur -> admin ») ni dans son portefeuille, et ne reçoit aucun
--    montant. On rend from_user_id / to_user_id nullables et on utilise NULL
--    pour le côté « système ».
-- 2. Virement : la raison saisie est ajoutée aux notifications d'envoi/réception.
-- 3. Cadeaux du chat : les utilisateurs peuvent en envoyer dans les annonces ;
--    minimum 0,01 SC ; limites quotidiennes (annonces 2, classe 3).
-- 4. Demandes de prêt du chat : limites quotidiennes (annonces 1, classe 2).
-- 5. Notification « Demande de prêt » : accents rétablis (rétroactif).

begin;

-- ── 1. Contreparties nullables ───────────────────────────────────────────────

alter table public.transactions alter column from_user_id drop not null;
alter table public.transactions alter column to_user_id   drop not null;

-- ── 2. transfer_funds : raison dans les notifications ────────────────────────

create or replace function public.transfer_funds(
  p_from_user_id uuid,
  p_to_user_id uuid,
  p_amount numeric,
  p_description text,
  p_type text default 'transfer',
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_from public.profiles%rowtype;
  v_to public.profiles%rowtype;
  v_tx public.transactions%rowtype;
  v_reason text;
  v_suffix text;
begin
  if p_amount <= 0 then
    raise exception 'Montant invalide.';
  end if;
  if p_from_user_id = p_to_user_id then
    raise exception 'Impossible de s''envoyer des fonds à soi-même.';
  end if;

  select * into v_from from public.profiles where id = p_from_user_id for update;
  if not found then raise exception 'Envoyeur introuvable.'; end if;

  select * into v_to from public.profiles where id = p_to_user_id for update;
  if not found then raise exception 'Destinataire introuvable.'; end if;

  if v_from.is_banned or v_to.is_banned then
    raise exception 'Un des comptes est banni.';
  end if;

  if v_from.role <> 'admin' and v_from.balance < p_amount then
    raise exception 'Solde insuffisant.';
  end if;

  if v_from.role <> 'admin' then
    update public.profiles set balance = balance - p_amount where id = p_from_user_id;
  end if;
  update public.profiles set balance = balance + p_amount where id = p_to_user_id;

  insert into public.transactions (
    from_user_id, to_user_id, amount, type, description, metadata
  ) values (
    p_from_user_id, p_to_user_id, p_amount,
    coalesce(p_type, 'transfer'), p_description,
    coalesce(p_metadata, '{}'::jsonb)
  ) returning * into v_tx;

  v_reason := nullif(trim(coalesce(p_description, '')), '');
  v_suffix := case when v_reason is not null then ' Raison : ' || v_reason else '' end;

  insert into public.notifications (user_id, type, title, body, data)
  values
    (p_to_user_id, 'transaction_received', 'Paiement reçu',
     'Tu as reçu ' || p_amount || ' SC.' || v_suffix,
     jsonb_build_object('transaction_id', v_tx.id)),
    (p_from_user_id, 'transaction_sent', 'Paiement envoyé',
     'Tu as envoyé ' || p_amount || ' SC.' || v_suffix,
     jsonb_build_object('transaction_id', v_tx.id));

  return to_jsonb(v_tx);
end;
$$;

grant execute on function public.transfer_funds to authenticated;

-- ── 3. Achat boutique : pas de crédit admin, contrepartie NULL ───────────────

create or replace function public.purchase_marketplace_item(
  p_buyer_id uuid,
  p_item_id uuid,
  p_quantity integer default 1
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_item public.marketplace_items%rowtype;
  v_buyer public.profiles%rowtype;
  v_total numeric(12,2);
  v_tx public.transactions%rowtype;
  v_purchase_id uuid;
begin
  if auth.uid() <> p_buyer_id then raise exception 'Non autorisé.'; end if;
  if p_quantity < 1 then raise exception 'Quantité invalide.'; end if;

  select * into v_item
  from public.marketplace_items
  where id = p_item_id and is_active = true
  for update;
  if not found then raise exception 'Offre indisponible.'; end if;

  if v_item.stock <> -1 and v_item.stock < p_quantity then
    raise exception 'Stock insuffisant.';
  end if;

  select * into v_buyer from public.profiles where id = p_buyer_id for update;
  if not found then raise exception 'Compte introuvable.'; end if;
  if v_buyer.is_banned then raise exception 'Votre compte est banni.'; end if;

  v_total := v_item.price * p_quantity;

  if v_buyer.role <> 'admin' then
    if v_buyer.balance < v_total then raise exception 'Solde insuffisant.'; end if;
    update public.profiles set balance = balance - v_total where id = p_buyer_id;
  end if;

  -- Achat : l'acheteur paie le « système » (pas d'admin destinataire).
  insert into public.transactions (
    from_user_id, to_user_id, amount, type, description, metadata
  ) values (
    p_buyer_id, null, v_total, 'purchase',
    'Achat boutique : ' || v_item.name,
    jsonb_build_object('item_id', p_item_id, 'item_name', v_item.name)
  ) returning * into v_tx;

  if v_item.stock <> -1 then
    update public.marketplace_items set stock = stock - p_quantity
    where id = p_item_id returning * into v_item;
  end if;

  insert into public.purchases (buyer_id, item_id, quantity, total_price, transaction_id)
  values (p_buyer_id, p_item_id, p_quantity, v_total, v_tx.id)
  returning id into v_purchase_id;

  insert into public.notifications (user_id, type, title, body, data)
  values (
    p_buyer_id, 'marketplace_purchase', 'Achat confirmé',
    'Achat effectué : ' || v_item.name || '.',
    jsonb_build_object('purchase_id', v_purchase_id, 'item_id', p_item_id)
  );

  return jsonb_build_object(
    'purchase_id', v_purchase_id,
    'transaction', to_jsonb(v_tx),
    'item', to_jsonb(v_item)
  );
end;
$$;

grant execute on function public.purchase_marketplace_item to authenticated;

-- ── 4. Ajustement admin : contrepartie NULL (pas d'admin dans la blockchain) ─

create or replace function public.admin_adjust_balance(
  p_user_id uuid,
  p_amount numeric,
  p_reason text
)
returns void
language plpgsql security definer set search_path = public
as $$
begin
  if not public.current_profile_is_admin() then
    raise exception 'Action réservée à l''administrateur.';
  end if;

  update public.profiles set balance = greatest(0, balance + p_amount)
  where id = p_user_id;

  insert into public.transactions (from_user_id, to_user_id, amount, type, description)
  values (
    case when p_amount >= 0 then null else p_user_id end, -- débit : from = user
    case when p_amount >= 0 then p_user_id else null end, -- crédit : to = user
    abs(p_amount),
    case when p_amount >= 0 then 'admin_credit' else 'admin_debit' end,
    p_reason
  );
end;
$$;

grant execute on function public.admin_adjust_balance to authenticated;

-- ── 5. Taxe : from = user, to = NULL ─────────────────────────────────────────

create or replace function public.admin_tax_all(p_percent numeric, p_reason text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_user record;
  v_amount numeric(12,2);
begin
  if not public.current_profile_is_admin() then
    raise exception 'Action réservée à l''administrateur.';
  end if;
  if p_percent <= 0 or p_percent > 100 then
    raise exception 'Pourcentage invalide.';
  end if;

  for v_user in
    select * from public.profiles
    where role <> 'admin' and is_banned = false and balance > 0
    for update
  loop
    v_amount := round(v_user.balance * p_percent / 100, 2);
    update public.profiles set balance = balance - v_amount where id = v_user.id;

    insert into public.transactions (from_user_id, to_user_id, amount, type, description)
    values (v_user.id, null, v_amount, 'tax', p_reason);

    insert into public.notifications (user_id, type, title, body, data)
    values (
      v_user.id, 'admin_tax', 'Taxe appliquée',
      'Une taxe de ' || p_percent || '% a été appliquée.',
      jsonb_build_object('amount', v_amount, 'reason', p_reason)
    );
  end loop;
end;
$$;

grant execute on function public.admin_tax_all to authenticated;

-- ── 6. Récompense : from = NULL, to = user ───────────────────────────────────

create or replace function public.admin_reward_all(p_amount numeric, p_reason text)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_user record;
begin
  if not public.current_profile_is_admin() then
    raise exception 'Action réservée à l''administrateur.';
  end if;
  if p_amount <= 0 then raise exception 'Montant invalide.'; end if;

  for v_user in
    select * from public.profiles where role <> 'admin' and is_banned = false
  loop
    update public.profiles set balance = balance + p_amount where id = v_user.id;

    insert into public.transactions (from_user_id, to_user_id, amount, type, description)
    values (null, v_user.id, p_amount, 'reward', p_reason);

    insert into public.notifications (user_id, type, title, body, data)
    values (
      v_user.id, 'admin_reward', 'Récompense reçue',
      'Une récompense de ' || p_amount || ' SC a été distribuée.',
      jsonb_build_object('amount', p_amount, 'reason', p_reason)
    );
  end loop;
end;
$$;

grant execute on function public.admin_reward_all to authenticated;

-- ── 7. Nettoyage rétroactif : retirer l'admin des transactions système ───────

update public.transactions
set to_user_id = null
where type in ('purchase', 'auction', 'tax', 'admin_debit')
  and to_user_id in (select id from public.profiles where role = 'admin');

update public.transactions
set from_user_id = null
where type in ('reward', 'admin_credit')
  and from_user_id in (select id from public.profiles where role = 'admin');

-- ── 8. Cadeaux : utilisateurs autorisés en annonces + limites quotidiennes ───

create or replace function public.send_chat_gift(
  p_amount   numeric,
  p_note     text default null,
  p_class_id uuid default null
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

  select * into v_user from public.profiles where id = v_auth_id for update;
  if v_user.id is null then raise exception 'Profil introuvable.'; end if;
  if v_user.is_banned then raise exception 'Votre compte est banni.'; end if;

  if p_amount is null or p_amount < 0.01 then
    raise exception 'Le cadeau doit valoir au moins 0,01 SC.';
  end if;
  if p_amount > 100000 then
    raise exception 'Le montant ne peut pas dépasser 100 000 SC.';
  end if;

  if p_class_id is not null then
    if not exists (select 1 from public.classes where id = p_class_id) then
      raise exception 'Classe introuvable.';
    end if;
    if v_user.role <> 'admin' and v_user.class_id is distinct from p_class_id then
      raise exception 'Vous n''appartenez pas à cette classe.';
    end if;
  end if;

  -- Limites quotidiennes (utilisateurs) : annonces 2/jour, classe 3/jour.
  if v_user.role <> 'admin' then
    if p_class_id is null then
      select count(*) into v_count from public.chat_messages
      where user_id = v_auth_id and message_type = 'gift'
        and class_id is null and created_at >= date_trunc('day', now());
      if v_count >= 2 then
        raise exception 'Limite atteinte : 2 cadeaux par jour dans les annonces.';
      end if;
    else
      select count(*) into v_count from public.chat_messages
      where user_id = v_auth_id and message_type = 'gift'
        and class_id = p_class_id and created_at >= date_trunc('day', now());
      if v_count >= 3 then
        raise exception 'Limite atteinte : 3 cadeaux par jour dans cette classe.';
      end if;
    end if;

    if v_user.balance < p_amount then
      raise exception 'Solde insuffisant.';
    end if;
    update public.profiles set balance = balance - p_amount where id = v_auth_id;
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
    'warning', false, 'warning_count', 0, 'muted', false
  );
end;
$$;

-- ── 9. Demandes de prêt du chat : limites quotidiennes ───────────────────────

create or replace function public.send_loan_request_chat(
  p_amount        numeric,
  p_interest_rate numeric     default null,
  p_due_date      timestamptz default null,
  p_note          text        default null,
  p_class_id      uuid        default null
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
  if p_due_date is not null and p_due_date <= now() + interval '5 minutes' then
    raise exception 'La date d''échéance doit être au moins dans 5 minutes.';
  end if;

  -- Limites quotidiennes (utilisateurs) : annonces 1/jour, classe 2/jour.
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
    now() + interval '24 hours'
  ) returning * into v_message;

  return jsonb_build_object(
    'message', to_jsonb(v_message),
    'warning', false, 'warning_count', 0, 'muted', false
  );
end;
$$;

grant execute on function public.send_loan_request_chat(numeric, numeric, timestamptz, text, uuid) to authenticated;

-- ── 10. Notification « Demande de prêt » : accents rétroactifs ───────────────

update public.notifications
set title = 'Demande de prêt'
where type = 'loan_requested' and title = 'Demande de pret';

update public.notifications
set body = replace(body, 'demande un pret', 'demande un prêt')
where type = 'loan_requested' and body like '%demande un pret%';

commit;

-- ============================================================
-- Textes neutres, enchères et nom public de l'administrateur
--
-- 1. Aucun texte de l'application ne s'adresse à la personne (ni « tu », ni
--    « vous ») : notifications et messages d'erreur reformulés. Les
--    fonctions ci-dessous reprennent à l'identique leur dernière version,
--    seuls les textes changent.
-- 2. Un déclencheur sur les notifications reformule aussi les textes
--    produits par d'anciennes versions encore en place, et les
--    notifications déjà reçues sont corrigées.
-- 3. L'administrateur ne peut plus enchérir.
-- 4. Nom affiché de l'administrateur : « Mme Kajouj-Bouchelaghem ». Seul
--    l'affichage change : l'identifiant de connexion reste le même.
--
-- Peut être exécutée plusieurs fois.
-- ============================================================

begin;

-- ── transfer_funds (d'après 20260709_admin_tx_attribution_gift_loan_limits.sql L22) ───
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
    raise exception 'Expéditeur et destinataire identiques.';
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
     p_amount || ' SC reçus.' || v_suffix,
     jsonb_build_object('transaction_id', v_tx.id)),
    (p_from_user_id, 'transaction_sent', 'Paiement envoyé',
     p_amount || ' SC envoyés.' || v_suffix,
     jsonb_build_object('transaction_id', v_tx.id));

  return to_jsonb(v_tx);
end;
$$;

-- ── purchase_marketplace_item (d'après 20260709_admin_tx_attribution_gift_loan_limits.sql L94) ───
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
  if v_buyer.is_banned then raise exception 'Compte banni.'; end if;

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

-- ── finalize_auction (d'après 20260524_market_snapshots_and_auction_transactions.sql L134) ───
create or replace function public.finalize_auction(p_auction_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  v_auction public.auctions%rowtype;
  v_admin_id uuid;
begin
  if not public.current_profile_is_admin() then
    raise exception 'Action réservée à l''administrateur.';
  end if;

  select * into v_auction
  from public.auctions
  where id = p_auction_id
  for update;

  if not found then
    raise exception 'Enchère introuvable.';
  end if;

  if v_auction.status = 'ended' then
    return;
  end if;

  update public.auctions
  set status = 'ended'
  where id = p_auction_id;

  if v_auction.current_winner_id is not null then
    select id into v_admin_id
    from public.profiles
    where role = 'admin'
    order by created_at asc
    limit 1;

    if v_admin_id is null then
      raise exception 'Aucun compte admin trouvé.';
    end if;

    insert into public.transactions (
      from_user_id,
      to_user_id,
      amount,
      type,
      description,
      metadata
    )
    values (
      v_auction.current_winner_id,
      v_admin_id,
      v_auction.current_price,
      'auction',
      'Enchère remportée : ' || v_auction.item_name,
      jsonb_build_object(
        'auction_id', v_auction.id,
        'auction_item_name', v_auction.item_name
      )
    );

    insert into public.notifications (user_id, type, title, body, data)
    values (
      v_auction.current_winner_id,
      'auction_won',
      'Enchère gagnée',
      'Enchère remportée : ' || v_auction.item_name,
      jsonb_build_object('auction_id', p_auction_id)
    );
  end if;
end;
$$;

-- ── repay_loan (d'après schema.sql L1308) ──────────────────────────────────
create or replace function public.repay_loan(
  p_loan_id uuid,
  p_borrower_id uuid,
  p_amount numeric
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_loan public.loans%rowtype;
  v_borrower public.profiles%rowtype;
  v_amount numeric(12,2);
begin
  if auth.uid() <> p_borrower_id then raise exception 'Non autorise.'; end if;
  if p_amount <= 0 then raise exception 'Montant invalide.'; end if;

  select * into v_loan
  from public.loans
  where id = p_loan_id and borrower_id = p_borrower_id and status = 'active'
  for update;
  if not found then raise exception 'Prêt introuvable.'; end if;

  v_amount := least(p_amount, v_loan.total_due - v_loan.amount_repaid);

  select * into v_borrower from public.profiles where id = p_borrower_id for update;
  if v_borrower.balance < v_amount then raise exception 'Solde insuffisant.'; end if;

  update public.profiles set balance = balance - v_amount where id = p_borrower_id;
  update public.profiles set balance = balance + v_amount where id = v_loan.lender_id;

  update public.loans
  set amount_repaid = amount_repaid + v_amount,
      status = case when amount_repaid + v_amount >= total_due then 'repaid' else 'active' end
  where id = p_loan_id
  returning * into v_loan;

  insert into public.transactions (from_user_id, to_user_id, amount, type, description, metadata)
  values (
    p_borrower_id, v_loan.lender_id, v_amount,
    'loan', 'Remboursement de prêt', jsonb_build_object('loan_id', v_loan.id)
  );

  insert into public.notifications (user_id, type, title, body, data)
  values (
    v_loan.lender_id, 'loan_repaid', 'Remboursement reçu',
    'Remboursement reçu : ' || v_amount || ' SC.',
    jsonb_build_object('loan_id', v_loan.id)
  );

  return to_jsonb(v_loan);
end;
$$;

-- ── process_overdue_loans (d'après 20260702_loan_auto_repay_negative_balance.sql L3) ───
create or replace function public.process_overdue_loans()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_loan record;
  v_remaining numeric(12,2);
  v_count integer := 0;
begin
  for v_loan in
    select *
    from public.loans
    where status = 'active'
      and due_date is not null
      and due_date <= now()
    for update
  loop
    v_remaining := greatest(v_loan.total_due - v_loan.amount_repaid, 0);

    if v_remaining > 0 then
      update public.profiles
      set balance = balance - v_remaining
      where id = v_loan.borrower_id;

      update public.profiles
      set balance = balance + v_remaining
      where id = v_loan.lender_id;

      insert into public.transactions (
        from_user_id,
        to_user_id,
        amount,
        type,
        description,
        metadata
      )
      values (
        v_loan.borrower_id,
        v_loan.lender_id,
        v_remaining,
        'loan',
        'Prélèvement automatique prêt en retard',
        jsonb_build_object(
          'loan_id', v_loan.id,
          'auto_default', true
        )
      );
    end if;

    update public.loans
    set
      amount_repaid = total_due,
      status = 'defaulted',
      updated_at = now()
    where id = v_loan.id;

    insert into public.notifications (user_id, type, title, body, data)
    values (
      v_loan.borrower_id,
      'loan_overdue',
      'Prêt en retard',
      'Montant restant du prêt prélevé automatiquement.',
      jsonb_build_object('loan_id', v_loan.id, 'amount', v_remaining)
    );

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

-- ── request_loan (d'après 20260917_blockchain_feed_and_targeted_loan_duration.sql L31) ───
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
    raise exception 'Prêteur et emprunteur identiques.';
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
    v_borrower.username || ' demande un prêt de ' || p_principal || ' SC.',
    jsonb_build_object('loan_id', v_loan.id)
  );

  return to_jsonb(v_loan);
end;
$$;

-- ── accept_chat_loan_request (d'après 20261023_admin_cannot_lend.sql L14) ───
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
  if v_lender.role = 'admin' then
    raise exception 'Un administrateur ne peut pas prêter d''argent.';
  end if;
  if v_lender.is_banned then raise exception 'Compte banni.'; end if;

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

-- ── send_loan_request_chat (d'après 20260816_loan_duration.sql L22) ────────
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
  if v_user.is_banned then raise exception 'Compte banni.'; end if;

  if p_class_id is not null then
    if not exists (select 1 from public.classes where id = p_class_id) then
      raise exception 'Classe introuvable.';
    end if;
    if v_user.role <> 'admin' and v_user.class_id is distinct from p_class_id then
      raise exception 'Classe réservée à ses membres.';
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

-- ── send_chat_gift (d'après 20260709_admin_tx_attribution_gift_loan_limits.sql L287) ───
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
  if v_user.is_banned then raise exception 'Compte banni.'; end if;

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
      raise exception 'Classe réservée à ses membres.';
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

-- ── claim_chat_gift (d'après 20260706_ban_rpc_gift_labels_loan_expiry.sql L101) ───
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
  if v_auth_id is null then raise exception 'Non authentifié.'; end if;

  select * into v_user from public.profiles where id = v_auth_id for update;
  if v_user.id is null then raise exception 'Profil introuvable.'; end if;
  if v_user.is_banned then raise exception 'Compte banni.'; end if;

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
    raise exception 'Trop tard, ce cadeau a déjà été récupéré.';
  end if;
  if v_message.expires_at is not null and v_message.expires_at <= now() then
    raise exception 'Ce cadeau a expiré.';
  end if;
  if v_message.user_id = v_auth_id then
    raise exception 'Impossible de récupérer son propre cadeau.';
  end if;
  if v_message.class_id is not null
     and v_user.role <> 'admin'
     and v_user.class_id is distinct from v_message.class_id then
    raise exception 'Ce cadeau est réservé à une autre classe.';
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
    'Cadeau récupéré',
    jsonb_build_object('chat_message_id', p_message_id)
  );

  insert into public.notifications (user_id, type, title, body, data, is_read)
  values (
    v_message.user_id, 'system',
    'Cadeau récupéré',
    v_user.display_name || ' a récupéré le cadeau de '
      || v_message.gift_amount::text || ' SC.',
    jsonb_build_object('chat_message_id', p_message_id),
    false
  );

  return jsonb_build_object(
    'claimed', true,
    'amount', v_message.gift_amount
  );
end;
$$;

-- ── send_class_message (d'après 20260608_classes_and_multichat.sql L274) ───
create or replace function public.send_class_message(
  p_class_id uuid,
  p_content  text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_id      uuid := auth.uid();
  v_user         public.profiles%rowtype;
  v_message      public.chat_messages%rowtype;
  v_lower        text;
  v_is_bad       boolean := false;
  v_bad_patterns text[] := array[
    'connard','connasse','conne ','espece de con',
    'salope','sale pute','pute','putain de',
    'fdp','fils de pute','fille de pute',
    'nique ta','nique sa','va te faire niquer','ntm',
    'encule','enculer','va te faire enc',
    'batard','fils de',
    'trouduc','trou du cul','ta gueule','ferme ta gueule','ftg',
    'va te faire','vtff','va crever','creve',
    'abruti','imbecile','cretin','debile',
    'pede',' pd ','grosse merde',
    'je vais te tuer','je vais vous tuer','je vais te frapper',
    'je vais te casser','je vais t''eclater','on va te',
    'tue toi','suicide toi','va mourir','tu vas mourir',
    'mort a '
  ];
  v_pat text;
begin
  if v_auth_id is null then raise exception 'Non authentifié.'; end if;

  select * into v_user from profiles where id = v_auth_id;
  if v_user.id is null then raise exception 'Profil introuvable.'; end if;
  if v_user.is_banned then raise exception 'Compte banni.'; end if;

  -- Vérifier que l'utilisateur appartient à la classe (ou est admin)
  if v_user.role <> 'admin' and v_user.class_id is distinct from p_class_id then
    raise exception 'Classe réservée à ses membres.';
  end if;

  -- Vérifier que la classe existe
  if not exists (select 1 from classes where id = p_class_id) then
    raise exception 'Classe introuvable.';
  end if;

  -- Vérifier mute
  if v_user.chat_muted_until is not null and v_user.chat_muted_until <= now() then
    update profiles set chat_muted_until = null, chat_warning_count = 0
    where id = v_auth_id returning * into v_user;
  end if;

  if v_user.chat_muted_until is not null and v_user.chat_muted_until > now() then
    raise exception 'Chat suspendu encore % minute(s).',
      greatest(1, ceil(extract(epoch from (v_user.chat_muted_until - now())) / 60)::int);
  end if;

  if length(trim(p_content)) = 0 then raise exception 'Message vide.'; end if;
  if length(p_content) > 500 then raise exception 'Message trop long (500 caractères max).'; end if;

  v_lower := lower(p_content);
  foreach v_pat in array v_bad_patterns loop
    if v_lower like '%' || v_pat || '%' then v_is_bad := true; exit; end if;
  end loop;

  if v_is_bad then
    update profiles set chat_warning_count = chat_warning_count + 1
    where id = v_auth_id returning * into v_user;

    if v_user.chat_warning_count >= 3 then
      update profiles set chat_muted_until = now() + interval '10 minutes'
      where id = v_auth_id returning * into v_user;
    end if;
  end if;

  insert into chat_messages (
    user_id, username, display_name, avatar_url,
    content, is_censored, class_id, message_type,
    expires_at
  ) values (
    v_auth_id, v_user.username, v_user.display_name, v_user.avatar_url,
    case when v_is_bad then 'Message censuré' else trim(p_content) end,
    v_is_bad, p_class_id, 'text',
    now() + interval '48 hours'
  ) returning * into v_message;

  return jsonb_build_object(
    'message',       to_jsonb(v_message),
    'warning',       v_is_bad,
    'warning_count', v_user.chat_warning_count,
    'muted',         v_user.chat_muted_until is not null
  );
end;
$$;

-- ── edit_class_message (d'après 20260608_classes_and_multichat.sql L376) ───
create or replace function public.edit_class_message(
  p_message_id uuid,
  p_content    text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_id      uuid := auth.uid();
  v_user         public.profiles%rowtype;
  v_message      public.chat_messages%rowtype;
  v_lower        text;
  v_is_bad       boolean := false;
  v_bad_patterns text[] := array[
    'connard','connasse','conne ','espece de con',
    'salope','sale pute','pute','putain de',
    'fdp','fils de pute','fille de pute',
    'nique ta','nique sa','va te faire niquer','ntm',
    'encule','enculer','va te faire enc',
    'batard','fils de',
    'trouduc','trou du cul','ta gueule','ferme ta gueule','ftg',
    'va te faire','vtff','va crever','creve',
    'abruti','imbecile','cretin','debile',
    'pede',' pd ','grosse merde',
    'je vais te tuer','je vais vous tuer','je vais te frapper',
    'je vais te casser','je vais t''eclater','on va te',
    'tue toi','suicide toi','va mourir','tu vas mourir',
    'mort a '
  ];
  v_pat text;
begin
  if v_auth_id is null then raise exception 'Non authentifié.'; end if;

  select * into v_user from profiles where id = v_auth_id;
  if v_user.id is null then raise exception 'Profil introuvable.'; end if;
  if v_user.is_banned then raise exception 'Compte banni.'; end if;

  select * into v_message from chat_messages
  where id = p_message_id and not is_deleted
  for update;

  if v_message.id is null then raise exception 'Message introuvable.'; end if;
  if v_message.user_id is distinct from v_auth_id then
    raise exception 'Modification non autorisée.';
  end if;
  if v_message.message_type <> 'text' then
    raise exception 'Ce type de message ne peut pas être modifié.';
  end if;

  -- Vérifier mute
  if v_user.chat_muted_until is not null and v_user.chat_muted_until <= now() then
    update profiles set chat_muted_until = null, chat_warning_count = 0
    where id = v_auth_id returning * into v_user;
  end if;
  if v_user.chat_muted_until is not null and v_user.chat_muted_until > now() then
    raise exception 'Chat suspendu encore % minute(s).',
      greatest(1, ceil(extract(epoch from (v_user.chat_muted_until - now())) / 60)::int);
  end if;

  if length(trim(p_content)) = 0 then raise exception 'Message vide.'; end if;
  if length(p_content) > 500 then raise exception 'Message trop long (500 caractères max).'; end if;

  v_lower := lower(p_content);
  foreach v_pat in array v_bad_patterns loop
    if v_lower like '%' || v_pat || '%' then v_is_bad := true; exit; end if;
  end loop;

  if v_is_bad then
    update profiles set chat_warning_count = chat_warning_count + 1
    where id = v_auth_id returning * into v_user;
    if v_user.chat_warning_count >= 3 then
      update profiles set chat_muted_until = now() + interval '10 minutes'
      where id = v_auth_id returning * into v_user;
    end if;
  end if;

  update chat_messages
  set content    = case when v_is_bad then 'Message censuré' else trim(p_content) end,
      is_censored = v_is_bad,
      edited_at  = now()
  where id = p_message_id
  returning * into v_message;

  return jsonb_build_object(
    'message',       to_jsonb(v_message),
    'warning',       v_is_bad,
    'warning_count', v_user.chat_warning_count,
    'muted',         v_user.chat_muted_until is not null
  );
end;
$$;

-- ── edit_chat_message (d'après 20260610_loan_and_fixes.sql L12) ────────────
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
  if v_user.is_banned then raise exception 'Compte banni.'; end if;

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
    raise exception 'Chat suspendu encore % minute(s).',
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

-- ── enforce_chat_filter (d'après 20260815_sanctions_and_filter_v2.sql L348) ───
create or replace function public.enforce_chat_filter()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_count integer;
  v_censored_24h integer;
  v_username text;
begin
  if coalesce(new.is_censored, false) then
    return new;
  end if;

  if new.content is null or not public.contains_forbidden_words(new.content) then
    return new;
  end if;

  new.content := 'Message censuré';
  new.is_censored := true;

  if new.user_id is null then
    return new;
  end if;

  update public.profiles
  set chat_warning_count = coalesce(chat_warning_count, 0) + 1
  where id = new.user_id
  returning chat_warning_count, username into v_count, v_username;

  -- Messages deja censures sur les dernieres vingt-quatre heures, celui-ci
  -- compris (il n'est pas encore insere, d'où le + 1).
  select count(*) + 1 into v_censored_24h
  from public.chat_messages
  where user_id = new.user_id
    and is_censored
    and created_at > now() - interval '24 hours';

  if v_censored_24h >= 9 then
    update public.profiles
    set chat_muted_until = now() + interval '24 hours'
    where id = new.user_id;

    insert into public.sanctions (
      user_id, username, kind, reason, until, automatic
    ) values (
      new.user_id, v_username, 'mute',
      v_censored_24h || ' messages censurés en 24 h',
      now() + interval '24 hours', true
    );

    insert into public.notifications (user_id, type, title, body)
    values (
      new.user_id, 'system', 'Chat suspendu 24 h',
      'Trop de messages inappropriés : chat fermé pendant 24 heures.'
    );
  elsif coalesce(v_count, 0) >= 3 then
    update public.profiles
    set chat_muted_until = now() + interval '10 minutes'
    where id = new.user_id;
  end if;

  return new;
end;
$$;

-- ── approve_avatar_change (d'après 20260610_loan_and_fixes.sql L134) ───────
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
    'Nouvelle photo de profil acceptée.',
    jsonb_build_object('action', 'avatar_approved'),
    false
  );
end;
$$;

-- ── reject_avatar_change (d'après 20260610_loan_and_fixes.sql L171) ────────
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
    'Nouvelle photo de profil refusée.',
    jsonb_build_object('action', 'avatar_rejected'),
    false
  );
end;
$$;

-- ── admin_ban_user_temp (d'après 20260815_sanctions_and_filter_v2.sql L227) ───
create or replace function public.admin_ban_user_temp(
  p_user_id uuid,
  p_reason text,
  p_minutes integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin public.profiles%rowtype;
  v_target public.profiles%rowtype;
  v_until timestamptz;
begin
  select * into v_admin from public.profiles where id = auth.uid();
  if v_admin.id is null or v_admin.role <> 'admin' then
    raise exception 'Action réservée à l''administrateur.';
  end if;

  select * into v_target from public.profiles where id = p_user_id;
  if v_target.id is null then
    raise exception 'Compte introuvable.';
  end if;
  if v_target.role = 'admin' then
    raise exception 'Un administrateur ne peut pas être banni.';
  end if;

  -- p_minutes nul ou negatif : bannissement sans terme.
  v_until := case
    when p_minutes is null or p_minutes <= 0 then null
    else now() + make_interval(mins => p_minutes)
  end;

  update public.profiles
  set is_banned = true,
      ban_reason = nullif(trim(coalesce(p_reason, '')), ''),
      banned_until = v_until
  where id = p_user_id;

  insert into public.sanctions (
    user_id, username, kind, reason, until,
    issued_by, issued_by_username, automatic
  ) values (
    p_user_id, v_target.username, 'ban',
    nullif(trim(coalesce(p_reason, '')), ''), v_until,
    v_admin.id, v_admin.username, false
  );

  insert into public.notifications (user_id, type, title, body)
  values (
    p_user_id, 'system', 'Compte suspendu',
    case
      when v_until is null then 'Compte suspendu.'
      else 'Compte suspendu jusqu''au ' ||
           to_char(v_until at time zone 'Europe/Paris', 'DD/MM/YYYY à HH24:MI') || '.'
    end
  );
end;
$$;

-- ── release_expired_sanctions (d'après 20260816_sanction_lifted.sql L44) ───
create or replace function public.release_expired_sanctions()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_released integer := 0;
  v_row record;
begin
  for v_row in
    select id, username from public.profiles
    where is_banned and banned_until is not null and banned_until <= now()
  loop
    -- Le declencheur trg_mark_ban_lifted date la sanction correspondante.
    update public.profiles
    set is_banned = false, ban_reason = null, banned_until = null
    where id = v_row.id;

    insert into public.notifications (user_id, type, title, body)
    values (
      v_row.id, 'system', 'Suspension levée',
      'Compte de nouveau actif.'
    );

    v_released := v_released + 1;
  end loop;

  update public.profiles
  set chat_muted_until = null, chat_warning_count = 0
  where chat_muted_until is not null and chat_muted_until <= now();

  return v_released;
end;
$$;

-- ── place_auction_bid (d'après 20260531_fix_accents.sql) ─────────────────
-- L'administrateur n'enchérit plus : il crée et clôt les enchères.
create or replace function public.place_auction_bid(
  p_bidder_id uuid,
  p_auction_id uuid,
  p_amount numeric
)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  v_auction public.auctions%rowtype;
  v_bidder public.profiles%rowtype;
  v_previous_winner uuid;
  v_previous_amount numeric(12,2);
begin
  if auth.uid() <> p_bidder_id then
    raise exception 'Non autorisé.';
  end if;

  select * into v_auction from public.auctions where id = p_auction_id for update;
  if not found then raise exception 'Enchère introuvable.'; end if;

  if v_auction.status <> 'active' then
    raise exception 'Cette enchère n''est pas active.';
  end if;

  if now() > v_auction.ends_at then
    raise exception 'Cette enchère est terminée.';
  end if;

  if p_amount <= v_auction.current_price then
    raise exception 'Le montant doit être supérieur à l''offre actuelle.';
  end if;

  select * into v_bidder from public.profiles where id = p_bidder_id for update;
  if not found or v_bidder.is_banned then
    raise exception 'Compte enchérisseur invalide.';
  end if;

  if v_bidder.role = 'admin' then
    raise exception 'Un administrateur ne peut pas enchérir.';
  end if;

  if v_bidder.balance < p_amount then
    raise exception 'Solde insuffisant.';
  end if;

  v_previous_winner := v_auction.current_winner_id;
  v_previous_amount := v_auction.current_price;

  if v_previous_winner is not null then
    update public.profiles set balance = balance + v_previous_amount
    where id = v_previous_winner;
  end if;

  update public.profiles set balance = balance - p_amount where id = p_bidder_id;

  insert into public.auction_bids (
    auction_id,
    bidder_id,
    bidder_username,
    amount,
    auction_item_name_snapshot,
    auction_item_image_url_snapshot
  )
  values (
    p_auction_id,
    p_bidder_id,
    v_bidder.username,
    p_amount,
    v_auction.item_name,
    v_auction.item_image_url
  );

  update public.auctions
  set current_price = p_amount, current_winner_id = p_bidder_id,
      current_winner_username = v_bidder.username,
      current_winner_emoji = null,
      bid_count = bid_count + 1
  where id = p_auction_id
  returning * into v_auction;

  if v_previous_winner is not null then
    insert into public.notifications (user_id, type, title, body, data)
    values (
      v_previous_winner, 'auction_outbid', 'Offre dépassée',
      'Nouvelle offre plus élevée sur ' || v_auction.item_name,
      jsonb_build_object('auction_id', p_auction_id)
    );
  end if;

  return to_jsonb(v_auction);
end;
$$;

-- ── Filet de sécurité : textes des notifications ─────────────────────────
-- Reformule les tournures directes, y compris celles d'anciennes versions
-- de fonctions qui seraient encore en place.
create or replace function public.neutral_text(p_text text)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  v_text text := p_text;
  v_rule record;
begin
  if v_text is null then
    return null;
  end if;

  for v_rule in
    select * from (values
      (1,  '^Tu as re[çc]u un remboursement de ', 'Remboursement reçu : '),
      (2,  '^Tu as re[çc]u ([0-9][0-9.,]*) SC\.', '\1 SC reçus.'),
      (3,  '^Tu as envoy[ée] ([0-9][0-9.,]*) SC\.', '\1 SC envoyés.'),
      (4,  '^Tu as [ée]t[ée] d[ée]pass[ée]', 'Offre dépassée'),
      (5,  '^Quelqu''un a surench[ée]ri sur ', 'Nouvelle offre plus élevée sur '),
      (6,  '^(Vous avez|Tu as) gagn[ée] : ', 'Enchère remportée : '),
      (7,  '^(Vous avez|Tu as) achet[ée] : ', 'Achat : '),
      (8,  ' te demande un pr[êe]t de ', ' demande un prêt de '),
      (9,  '^Ton pr[êe]t de ', 'Prêt de '),
      (10, 'Le montant restant de ton pr[êe]t a [ée]t[ée] pr[ée]lev[ée] automatiquement\.', 'Montant restant du prêt prélevé automatiquement.'),
      (11, '^Ta nouvelle photo de profil a [ée]t[ée] accept[ée]e\.?', 'Nouvelle photo de profil acceptée.'),
      (12, '^Ta demande de changement de photo a [ée]t[ée] refus[ée]e\.?', 'Nouvelle photo de profil refusée.'),
      (13, '^Ton compte SES Coin a [ée]t[ée] approuv[ée]\.', 'Compte SES Coin approuvé.'),
      (14, ' a accept[ée] ta demande de ', ' a accepté la demande de '),
      (15, ' a r[ée]cup[ée]r[ée] ton cadeau de ', ' a récupéré le cadeau de '),
      (16, '^Votre compte a [ée]t[ée] suspendu\.', 'Compte suspendu.'),
      (17, '^Votre compte est suspendu jusqu', 'Compte suspendu jusqu'),
      (18, '^Votre compte est de nouveau actif\.', 'Compte de nouveau actif.'),
      (19, '^Votre signalement a [ée]t[ée] retenu\. Merci de votre vigilance\.', 'Signalement retenu. Merci pour la vigilance.'),
      (20, '^Votre signalement a [ée]t[ée] examin[ée]', 'Signalement examiné'),
      (21, 'le chat vous est ferm[ée] pour 24 heures', 'chat fermé pendant 24 heures')
    ) as rules(position, pattern, replacement)
    order by position
  loop
    v_text := regexp_replace(v_text, v_rule.pattern, v_rule.replacement);
  end loop;

  return v_text;
end;
$$;

create or replace function public.neutralize_notification()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.title := public.neutral_text(new.title);
  new.body := public.neutral_text(new.body);
  return new;
end;
$$;

drop trigger if exists trg_neutralize_notification on public.notifications;
create trigger trg_neutralize_notification
  before insert or update of title, body on public.notifications
  for each row execute function public.neutralize_notification();

-- Notifications déjà reçues (le déclencheur les reformule à la mise à jour).
update public.notifications
set title = title, body = body
where title is distinct from public.neutral_text(title)
   or body is distinct from public.neutral_text(body);

-- ── Nom public de l'administrateur ───────────────────────────────────────
update public.profiles
set display_name = 'Mme Kajouj-Bouchelaghem'
where role = 'admin';

-- Les messages gardent le nom affiché au moment de l'envoi.
update public.chat_messages
set display_name = 'Mme Kajouj-Bouchelaghem'
where user_id in (select id from public.profiles where role = 'admin');

commit;

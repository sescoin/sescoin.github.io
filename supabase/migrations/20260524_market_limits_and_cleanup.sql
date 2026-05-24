begin;

alter table public.marketplace_items
  add column if not exists max_per_user integer not null default -1;

update public.marketplace_items
set max_per_user = -1
where max_per_user = 0;

alter table public.marketplace_items
  drop constraint if exists marketplace_items_max_per_user_check;

alter table public.marketplace_items
  add constraint marketplace_items_max_per_user_check
  check (max_per_user = -1 or max_per_user > 0);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'marketplace', 'marketplace', true, 5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update set public = true;

drop policy if exists "marketplace_public_read" on storage.objects;
drop policy if exists "marketplace_auth_write" on storage.objects;
drop policy if exists "marketplace_auth_update" on storage.objects;
drop policy if exists "marketplace_auth_delete" on storage.objects;

create policy "marketplace_public_read" on storage.objects
  for select using (bucket_id = 'marketplace');

create policy "marketplace_auth_write" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'marketplace');

create policy "marketplace_auth_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'marketplace');

create policy "marketplace_auth_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'marketplace');

create or replace function public.transfer_funds(
  p_from_user_id uuid,
  p_to_user_id uuid,
  p_amount numeric,
  p_description text,
  p_type text default 'transfer',
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_from public.profiles%rowtype;
  v_to public.profiles%rowtype;
  v_tx public.transactions%rowtype;
  v_type text := coalesce(p_type, 'transfer');
begin
  if p_amount <= 0 then
    raise exception 'Montant invalide.';
  end if;

  if p_from_user_id = p_to_user_id then
    raise exception 'Impossible de s''envoyer des fonds à soi-même.';
  end if;

  select * into v_from from public.profiles where id = p_from_user_id for update;
  if not found then
    raise exception 'Envoyeur introuvable.';
  end if;

  select * into v_to from public.profiles where id = p_to_user_id for update;
  if not found then
    raise exception 'Destinataire introuvable.';
  end if;

  if v_from.is_banned or v_to.is_banned then
    raise exception 'Un des comptes est banni.';
  end if;

  if v_from.role <> 'admin' and v_from.balance < p_amount then
    raise exception 'Solde insuffisant.';
  end if;

  if v_from.role <> 'admin' then
    update public.profiles
    set balance = balance - p_amount
    where id = p_from_user_id;
  end if;

  update public.profiles
  set balance = balance + p_amount
  where id = p_to_user_id;

  insert into public.transactions (
    from_user_id,
    to_user_id,
    amount,
    type,
    description,
    metadata
  )
  values (
    p_from_user_id,
    p_to_user_id,
    p_amount,
    v_type,
    p_description,
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning * into v_tx;

  if v_type <> 'purchase' then
    insert into public.notifications (user_id, type, title, body, data)
    values
      (
        p_to_user_id,
        'transaction_received',
        'Paiement reçu',
        'Tu as reçu ' || p_amount || ' SC.',
        jsonb_build_object('transaction_id', v_tx.id)
      ),
      (
        p_from_user_id,
        'transaction_sent',
        'Paiement envoyé',
        'Tu as envoyé ' || p_amount || ' SC.',
        jsonb_build_object('transaction_id', v_tx.id)
      );
  end if;

  return to_jsonb(v_tx);
end;
$$;

create or replace function public.purchase_marketplace_item(
  p_buyer_id uuid,
  p_item_id uuid,
  p_quantity integer default 1
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.marketplace_items%rowtype;
  v_total numeric(12,2);
  v_admin_id uuid;
  v_tx jsonb;
  v_tx_id uuid;
  v_purchase_id uuid;
  v_already_bought integer := 0;
begin
  if auth.uid() <> p_buyer_id then
    raise exception 'Non autorisé.';
  end if;

  if p_quantity < 1 then
    raise exception 'Quantité invalide.';
  end if;

  select * into v_item
  from public.marketplace_items
  where id = p_item_id and is_active = true
  for update;

  if not found then
    raise exception 'Offre indisponible.';
  end if;

  if v_item.stock <> -1 and v_item.stock < p_quantity then
    raise exception 'Stock insuffisant.';
  end if;

  select coalesce(sum(quantity), 0)::integer
  into v_already_bought
  from public.purchases
  where buyer_id = p_buyer_id
    and item_id = p_item_id;

  if v_item.max_per_user <> -1
     and v_already_bought + p_quantity > v_item.max_per_user then
    raise exception 'Limite d''achat atteinte pour cette offre.';
  end if;

  select id into v_admin_id
  from public.profiles
  where role = 'admin'
  order by created_at asc
  limit 1;

  if v_admin_id is null then
    raise exception 'Aucun compte admin trouvé.';
  end if;

  v_total := v_item.price * p_quantity;

  v_tx := public.transfer_funds(
    p_buyer_id,
    v_admin_id,
    v_total,
    'Achat boutique : ' || v_item.name,
    'purchase',
    jsonb_build_object(
      'item_id', v_item.id,
      'item_name', v_item.name,
      'item_category', v_item.category,
      'quantity', p_quantity
    )
  );
  v_tx_id := (v_tx ->> 'id')::uuid;

  if v_item.stock <> -1 then
    update public.marketplace_items
    set stock = stock - p_quantity
    where id = p_item_id
    returning * into v_item;
  end if;

  insert into public.purchases (
    buyer_id,
    item_id,
    quantity,
    total_price,
    transaction_id,
    item_name_snapshot,
    item_description_snapshot,
    item_image_url_snapshot,
    item_category_snapshot,
    unit_price_snapshot
  )
  values (
    p_buyer_id,
    p_item_id,
    p_quantity,
    v_total,
    v_tx_id,
    v_item.name,
    v_item.description,
    v_item.image_url,
    v_item.category,
    v_item.price
  )
  returning id into v_purchase_id;

  insert into public.notifications (user_id, type, title, body, data)
  values (
    p_buyer_id,
    'marketplace_purchase',
    'Achat confirmé',
    'Vous avez acheté : ' || v_item.name,
    jsonb_build_object('purchase_id', v_purchase_id, 'item_id', p_item_id)
  );

  return jsonb_build_object(
    'purchase_id', v_purchase_id,
    'transaction', v_tx,
    'item', to_jsonb(v_item)
  );
end;
$$;

create or replace function public.admin_delete_purchase_record(p_purchase_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.current_profile_is_admin() then
    raise exception 'Action réservée à l''administrateur.';
  end if;

  delete from public.notifications
  where type = 'marketplace_purchase'
    and data->>'purchase_id' = p_purchase_id::text;

  delete from public.purchases
  where id = p_purchase_id;
end;
$$;

create or replace function public.admin_delete_auction_bid(p_bid_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_bid public.auction_bids%rowtype;
  v_auction public.auctions%rowtype;
  v_top_bid record;
  v_bid_count integer;
  v_previous_winner uuid;
begin
  if not public.current_profile_is_admin() then
    raise exception 'Action réservée à l''administrateur.';
  end if;

  select * into v_bid
  from public.auction_bids
  where id = p_bid_id;

  if not found then
    raise exception 'Offre introuvable.';
  end if;

  select * into v_auction
  from public.auctions
  where id = v_bid.auction_id
  for update;

  if not found then
    raise exception 'Enchère introuvable.';
  end if;

  v_previous_winner := v_auction.current_winner_id;

  delete from public.auction_bids
  where id = p_bid_id;

  select count(*)::integer
  into v_bid_count
  from public.auction_bids
  where auction_id = v_bid.auction_id;

  select bidder_id, bidder_username, amount
  into v_top_bid
  from public.auction_bids
  where auction_id = v_bid.auction_id
  order by amount desc, created_at asc
  limit 1;

  update public.auctions
  set
    current_winner_id = v_top_bid.bidder_id,
    current_winner_username = v_top_bid.bidder_username,
    current_price = coalesce(v_top_bid.amount, starting_price),
    bid_count = v_bid_count,
    current_winner_emoji = case
      when v_top_bid.bidder_id is null then null
      when v_top_bid.bidder_id = v_previous_winner then current_winner_emoji
      else null
    end
  where id = v_bid.auction_id;
end;
$$;

delete from public.notifications n
using public.transactions t
where n.type = 'transaction_sent'
  and n.data ? 'transaction_id'
  and n.data->>'transaction_id' = t.id::text
  and t.type = 'purchase';

grant execute on function public.admin_delete_purchase_record(uuid) to authenticated;
grant execute on function public.admin_delete_auction_bid(uuid) to authenticated;

commit;

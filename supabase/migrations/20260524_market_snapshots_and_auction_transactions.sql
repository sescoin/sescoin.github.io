begin;

alter table public.purchases
  add column if not exists item_name_snapshot text,
  add column if not exists item_description_snapshot text,
  add column if not exists item_image_url_snapshot text,
  add column if not exists item_category_snapshot text,
  add column if not exists unit_price_snapshot numeric(12, 2);

update public.purchases p
set
  item_name_snapshot = coalesce(p.item_name_snapshot, i.name),
  item_description_snapshot = coalesce(p.item_description_snapshot, i.description),
  item_image_url_snapshot = coalesce(p.item_image_url_snapshot, i.image_url),
  item_category_snapshot = coalesce(p.item_category_snapshot, i.category),
  unit_price_snapshot = coalesce(p.unit_price_snapshot, i.price)
from public.marketplace_items i
where i.id = p.item_id;

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
  v_total numeric(12,2);
  v_admin_id uuid;
  v_tx jsonb;
  v_tx_id uuid;
  v_purchase_id uuid;
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
      'Vous avez gagné : ' || v_auction.item_name,
      jsonb_build_object('auction_id', p_auction_id)
    );
  end if;
end;
$$;

create or replace function public.finalize_expired_auctions()
returns integer
language plpgsql security definer set search_path = public
as $$
declare
  v_auction record;
  v_count integer := 0;
begin
  for v_auction in
    select id
    from public.auctions
    where status in ('active', 'upcoming')
      and ends_at <= now()
  loop
    perform public.finalize_auction(v_auction.id);
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

update public.notifications
set
  title = replace(title, 'Achat confirme', 'Achat confirmé'),
  body = replace(body, 'Tu as achete', 'Vous avez acheté')
where title like '%Achat confirme%'
   or body like '%Tu as achete%';

commit;

begin;

alter table public.purchases
  add column if not exists buyer_username_snapshot text;

update public.purchases p
set buyer_username_snapshot = pr.username
from public.profiles pr
where p.buyer_id = pr.id
  and p.buyer_username_snapshot is null;

update public.purchases
set buyer_username_snapshot = ''
where buyer_username_snapshot is null;

alter table public.purchases
  alter column buyer_username_snapshot set default '',
  alter column buyer_username_snapshot set not null;

alter table public.purchases
  drop constraint if exists purchases_buyer_id_fkey,
  drop constraint if exists purchases_item_id_fkey;

alter table public.purchases
  alter column item_id drop not null;

alter table public.purchases
  add constraint purchases_buyer_id_fkey
    foreign key (buyer_id) references public.profiles(id) on delete set null,
  add constraint purchases_item_id_fkey
    foreign key (item_id) references public.marketplace_items(id) on delete set null;

alter table public.auction_bids
  add column if not exists auction_item_name_snapshot text,
  add column if not exists auction_item_image_url_snapshot text;

update public.auction_bids b
set
  auction_item_name_snapshot = a.item_name,
  auction_item_image_url_snapshot = a.item_image_url
from public.auctions a
where b.auction_id = a.id
  and (
    b.auction_item_name_snapshot is null
    or b.auction_item_image_url_snapshot is null
  );

update public.auction_bids
set auction_item_name_snapshot = ''
where auction_item_name_snapshot is null;

alter table public.auction_bids
  alter column auction_item_name_snapshot set default '',
  alter column auction_item_name_snapshot set not null;

alter table public.auction_bids
  drop constraint if exists auction_bids_auction_id_fkey,
  drop constraint if exists auction_bids_bidder_id_fkey;

alter table public.auction_bids
  alter column auction_id drop not null;

alter table public.auction_bids
  add constraint auction_bids_auction_id_fkey
    foreign key (auction_id) references public.auctions(id) on delete set null,
  add constraint auction_bids_bidder_id_fkey
    foreign key (bidder_id) references public.profiles(id) on delete set null;

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
    raise exception 'Non autorise.';
  end if;

  select * into v_auction from public.auctions where id = p_auction_id for update;
  if not found then raise exception 'Enchere introuvable.'; end if;

  if v_auction.status <> 'active' then
    raise exception 'Cette enchere n''est pas active.';
  end if;

  if now() > v_auction.ends_at then
    raise exception 'Cette enchere est terminee.';
  end if;

  if p_amount <= v_auction.current_price then
    raise exception 'Le montant doit etre superieur a l''offre actuelle.';
  end if;

  select * into v_bidder from public.profiles where id = p_bidder_id for update;
  if not found or v_bidder.is_banned then
    raise exception 'Compte encherisseur invalide.';
  end if;

  if v_bidder.role <> 'admin' and v_bidder.balance < p_amount then
    raise exception 'Solde insuffisant.';
  end if;

  v_previous_winner := v_auction.current_winner_id;
  v_previous_amount := v_auction.current_price;

  if v_previous_winner is not null then
    update public.profiles set balance = balance + v_previous_amount
    where id = v_previous_winner;
  end if;

  if v_bidder.role <> 'admin' then
    update public.profiles set balance = balance - p_amount where id = p_bidder_id;
  end if;

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
      v_previous_winner, 'auction_outbid', 'Tu as ete depasse',
      'Quelqu''un a surencheri sur ' || v_auction.item_name,
      jsonb_build_object('auction_id', p_auction_id)
    );
  end if;

  return to_jsonb(v_auction);
end;
$$;

create or replace function public.admin_delete_auction(p_auction_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auction public.auctions%rowtype;
begin
  if not public.current_profile_is_admin() then
    raise exception 'Action reservee a l''administrateur.';
  end if;

  select * into v_auction
  from public.auctions
  where id = p_auction_id
  for update;

  if not found then
    raise exception 'Enchere introuvable.';
  end if;

  if v_auction.status in ('active', 'upcoming')
     and v_auction.current_winner_id is not null then
    update public.profiles
    set balance = balance + v_auction.current_price
    where id = v_auction.current_winner_id;
  end if;

  delete from public.notifications
  where data->>'auction_id' = p_auction_id::text;

  delete from public.auctions
  where id = p_auction_id;
end;
$$;

create or replace function public.admin_delete_user(p_user_id uuid)
returns void
language plpgsql security definer set search_path = public, auth
as $$
begin
  if not public.current_profile_is_admin() then
    raise exception 'Action reservee a l''administrateur.';
  end if;

  delete from auth.users where id = p_user_id;
end;
$$;

grant execute on function public.admin_delete_auction(uuid) to authenticated;
grant execute on function public.admin_delete_user(uuid) to authenticated;

commit;

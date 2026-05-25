begin;

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
  v_tx public.transactions%rowtype;
  v_purchase_id uuid;
  v_already_bought integer := 0;
begin
  if auth.uid() <> p_buyer_id then
    raise exception 'Non autorise.';
  end if;

  if p_quantity < 1 then
    raise exception 'Quantite invalide.';
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
    raise exception 'Aucun compte admin trouve.';
  end if;

  v_total := v_item.price * p_quantity;

  update public.profiles
  set balance = balance - v_total
  where id = p_buyer_id
    and (role = 'admin' or balance >= v_total);

  if not found then
    raise exception 'Solde insuffisant.';
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
    p_buyer_id,
    v_admin_id,
    v_total,
    'purchase',
    'Achat boutique',
    jsonb_build_object(
      'item_id', v_item.id,
      'item_name', v_item.name,
      'item_category', v_item.category,
      'quantity', p_quantity,
      'burned', true
    )
  )
  returning * into v_tx;

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
    unit_price_snapshot,
    buyer_username_snapshot
  )
  select
    p_buyer_id,
    p_item_id,
    p_quantity,
    v_total,
    v_tx.id,
    v_item.name,
    v_item.description,
    v_item.image_url,
    v_item.category,
    v_item.price,
    username
  from public.profiles
  where id = p_buyer_id
  returning id into v_purchase_id;

  insert into public.notifications (user_id, type, title, body, data)
  values (
    p_buyer_id,
    'marketplace_purchase',
    'Achat confirme',
    'Vous avez achete : ' || v_item.name,
    jsonb_build_object('purchase_id', v_purchase_id, 'item_id', p_item_id)
  );

  return jsonb_build_object(
    'purchase_id', v_purchase_id,
    'transaction', to_jsonb(v_tx),
    'item', to_jsonb(v_item)
  );
end;
$$;

create or replace function public.request_loan(
  p_borrower_id uuid,
  p_lender_id uuid,
  p_principal numeric,
  p_interest_rate numeric,
  p_total_due numeric,
  p_due_date timestamptz default null,
  p_note text default null
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
  if auth.uid() <> p_borrower_id then
    raise exception 'Non autorise.';
  end if;
  if p_borrower_id = p_lender_id then
    raise exception 'Impossible de se preter a soi-meme.';
  end if;
  if p_principal <= 0 then
    raise exception 'Montant invalide.';
  end if;

  select * into v_borrower from public.profiles where id = p_borrower_id;
  select * into v_lender from public.profiles where id = p_lender_id;

  if v_borrower.id is null or v_lender.id is null then
    raise exception 'Compte introuvable.';
  end if;

  if v_lender.role = 'admin' then
    raise exception 'Impossible de demander un pret a un administrateur.';
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
    p_note
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

commit;

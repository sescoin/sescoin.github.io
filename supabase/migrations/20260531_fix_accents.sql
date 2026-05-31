begin;

-- Correction des notifications existantes en base
update public.notifications set
  title = case title
    when 'Demande de pret'   then 'Demande de prêt'
    when 'Pret en retard'    then 'Prêt en retard'
    when 'Pret accepte'      then 'Prêt accepté'
    when 'Pret accorde'      then 'Prêt accordé'
    when 'Tu as ete depasse' then 'Tu as été dépassé'
    else title
  end,
  body = replace(replace(replace(replace(replace(replace(replace(
    body,
    'te demande un pret de ', 'te demande un prêt de '),
    'ton pret a ete preleve automatiquement.', 'ton prêt a été prélevé automatiquement.'),
    'Quelqu''un a surencheri', 'Quelqu''un a surenchéri'),
    'ete depasse', 'été dépassé'),
    'Prelevement automatique pret en retard', 'Prélèvement automatique prêt en retard'),
    'montant restant de ton pret', 'montant restant de ton prêt'),
    'a ete preleve', 'a été prélevé')
where type in ('loan_requested', 'loan_overdue', 'loan_accepted', 'auction_outbid');

-- Correction des descriptions de transactions existantes
update public.transactions set
  description = case description
    when 'Prelevement automatique pret en retard' then 'Prélèvement automatique prêt en retard'
    when 'Pret accorde'                           then 'Prêt accordé'
    when 'Remboursement de pret'                  then 'Remboursement de prêt'
    else description
  end
where description in (
  'Prelevement automatique pret en retard',
  'Pret accorde',
  'Remboursement de pret'
);

-- Recréation de process_overdue_loans avec accents corrects
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
      'Le montant restant de ton prêt a été prélevé automatiquement.',
      jsonb_build_object('loan_id', v_loan.id, 'amount', v_remaining)
    );

    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

-- Recréation de request_loan avec accents corrects
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
  perform public.process_overdue_loans();

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
    'Demande de prêt',
    v_borrower.username || ' te demande un prêt de ' || p_principal || ' SC.',
    jsonb_build_object('loan_id', v_loan.id)
  );

  return to_jsonb(v_loan);
end;
$$;

-- Recréation de place_auction_bid avec accents corrects
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
      v_previous_winner, 'auction_outbid', 'Tu as été dépassé',
      'Quelqu''un a surenchéri sur ' || v_auction.item_name,
      jsonb_build_object('auction_id', p_auction_id)
    );
  end if;

  return to_jsonb(v_auction);
end;
$$;

grant execute on function public.process_overdue_loans() to authenticated;

commit;

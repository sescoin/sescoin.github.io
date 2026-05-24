begin;

alter table public.payment_requests
  add column if not exists payment_method text;

alter table public.payment_requests
  drop constraint if exists payment_requests_payment_method_check;

alter table public.payment_requests
  add constraint payment_requests_payment_method_check
  check (payment_method in ('qr', 'nfc'));

drop function if exists public.transfer_funds(uuid, uuid, numeric, text, text);
drop function if exists public.create_payment_request(uuid, numeric, text);

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
    coalesce(p_type, 'transfer'),
    p_description,
    coalesce(p_metadata, '{}'::jsonb)
  )
  returning * into v_tx;

  insert into public.notifications (user_id, type, title, body, data)
  values
    (p_to_user_id, 'transaction_received', 'Paiement reçu',
     'Tu as reçu ' || p_amount || ' SC.',
     jsonb_build_object('transaction_id', v_tx.id)),
    (p_from_user_id, 'transaction_sent', 'Paiement envoyé',
     'Tu as envoyé ' || p_amount || ' SC.',
     jsonb_build_object('transaction_id', v_tx.id));

  return to_jsonb(v_tx);
end;
$$;

create or replace function public.create_payment_request(
  p_recipient_id uuid,
  p_amount numeric,
  p_description text,
  p_payment_method text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token uuid;
begin
  if auth.uid() <> p_recipient_id then
    raise exception 'Non autorisé.';
  end if;

  if p_amount <= 0 then
    raise exception 'Montant invalide.';
  end if;

  if p_payment_method is not null and p_payment_method not in ('qr', 'nfc') then
    raise exception 'Méthode de paiement invalide.';
  end if;

  insert into public.payment_requests (recipient_id, amount, description, payment_method)
  values (p_recipient_id, p_amount, p_description, p_payment_method)
  returning token into v_token;

  return v_token;
end;
$$;

create or replace function public.confirm_payment_request(
  p_payer_id uuid,
  p_payment_token uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_req public.payment_requests%rowtype;
  v_tx jsonb;
  v_tx_id uuid;
begin
  if auth.uid() <> p_payer_id then
    raise exception 'Non autorisé.';
  end if;

  select * into v_req
  from public.payment_requests
  where token = p_payment_token and status = 'pending'
  for update;

  if not found then
    raise exception 'Demande de paiement introuvable ou expirée.';
  end if;

  if v_req.expires_at < now() then
    update public.payment_requests set status = 'expired' where token = p_payment_token;
    raise exception 'Demande de paiement expirée.';
  end if;

  v_tx := public.transfer_funds(
    p_payer_id,
    v_req.recipient_id,
    v_req.amount,
    v_req.description,
    'transfer',
    jsonb_strip_nulls(jsonb_build_object('payment_method', v_req.payment_method))
  );
  v_tx_id := (v_tx ->> 'id')::uuid;

  update public.payment_requests
  set payer_id = p_payer_id, transaction_id = v_tx_id, status = 'confirmed'
  where token = p_payment_token;

  insert into public.notifications (user_id, type, title, body, data)
  values (
    v_req.recipient_id, 'transaction_confirmation_required',
    'Paiement à confirmer',
    'Un paiement de ' || v_req.amount || ' SC a été effectué. Confirme la réception.',
    jsonb_build_object('transaction_id', v_tx_id, 'payment_token', p_payment_token)
  );

  return v_tx;
end;
$$;

update public.notifications
set
  title = case title
    when 'Paiement recu' then 'Paiement reçu'
    when 'Paiement envoye' then 'Paiement envoyé'
    when 'Taxe appliquee' then 'Taxe appliquée'
    when 'Enchere gagnee' then 'Enchère gagnée'
    when 'Remboursement recu' then 'Remboursement reçu'
    when 'Recompense recue' then 'Récompense reçue'
    when 'Pret accepte' then 'Prêt accepté'
    when 'Demande de pret' then 'Demande de prêt'
    when 'Demande de pr?t' then 'Demande de prêt'
    when 'Pret accepte' then 'Prêt accepté'
    when 'Pret accorde' then 'Prêt accordé'
    else title
  end,
  body = replace(
    replace(
      replace(
        replace(
          replace(
            replace(
              replace(
                replace(
                  replace(
                    replace(
                      replace(body, 'Tu as recu', 'Tu as reçu'),
                      'Tu as envoye', 'Tu as envoyé'
                    ),
                    'a ete appliquee', 'a été appliquée'
                  ),
                  'Paiement a confirmer', 'Paiement à confirmer'
                ),
                'a ete effectue', 'a été effectué'
              ),
              'Confirme la reception', 'Confirme la réception'
            ),
            'Tu as gagne', 'Tu as gagné'
          ),
          'pr?t', 'prêt'
        ),
        'a ?t?', 'a été'
      ),
      'accept?.', 'accepté.'
    ),
    'Demande de pret', 'Demande de prêt'
  )
where title in (
    'Paiement recu',
    'Paiement envoye',
    'Taxe appliquee',
    'Enchere gagnee',
    'Remboursement recu',
    'Recompense recue',
    'Pret accepte',
    'Demande de pret',
    'Demande de pr?t',
    'Pret accorde'
  )
  or body like '%Tu as recu%'
  or body like '%Tu as envoye%'
  or body like '%a ete appliquee%'
  or body like '%Paiement a confirmer%'
  or body like '%a ete effectue%'
  or body like '%Confirme la reception%'
  or body like '%Tu as gagne%'
  or body like '%pr?t%'
  or body like '%a ?t?%'
  or body like '%accept?.%'
  or body like '%Demande de pret%';

update public.transactions
set description = case description
  when 'Pret accorde' then 'Prêt accordé'
  when 'Remboursement de pr?t' then 'Remboursement de prêt'
  else description
end
where description in ('Pret accorde', 'Remboursement de pr?t');

update public.notifications
set body = replace(body, 'te demande un pr?t de ', 'te demande un prêt de ')
where body like '%te demande un pr?t de %';

commit;

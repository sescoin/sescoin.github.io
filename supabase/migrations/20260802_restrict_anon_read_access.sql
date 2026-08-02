-- ============================================================
-- Fermeture de la lecture anonyme sur les tables contenant des
-- donnees personnelles.
--
-- CONSTAT
-- La cle publishable est publique par nature : elle est embarquee
-- dans le bundle Flutter web servi par GitHub Pages et visible en
-- clair dans lib/main.dart sur un depot public. Une policy
-- "using (true)" SANS clause "to authenticated" s'applique donc au
-- role "anon" : la table devient lisible par n'importe qui sur
-- Internet, sans compte.
--
-- Verifie par requete REST anonyme avant cette migration :
--   profiles      -> balance, role, is_banned, ban_reason, fcm_token
--   chat_messages -> integralite des conversations, y compris les
--                    messages marques is_deleted / is_censored
--   chat_reads    -> qui a lu quoi et quand
--   auction_bids  -> bidder_id, bidder_username, amount
--
-- Ces quatre tables passent en lecture reservee aux comptes
-- connectes. Les tables de catalogue (marketplace_items, auctions,
-- exchange_rates) restent lisibles publiquement : elles ne
-- contiennent aucune donnee personnelle.
--
-- COMPATIBILITE APPLICATIVE
-- auth_service.dart lit profiles avant connexion dans
-- isUsernameTaken() et _wasAccountDeleted(). Ces appels deviennent
-- silencieusement vides, sans consequence fonctionnelle :
-- submit_account_request est SECURITY DEFINER et revalide deja
-- l'unicite du username, la collision auth.users et la limite de
-- 3 demandes par appareil. L'erreur remonte simplement du serveur
-- au lieu d'etre anticipee par le client.
-- ============================================================

-- profiles : solde, role, statut de bannissement, token de push
drop policy if exists "profiles_select_all" on public.profiles;
create policy "profiles_select_authenticated" on public.profiles
  for select to authenticated using (true);

-- chat_messages : contenu des conversations
drop policy if exists "chat_read_all" on public.chat_messages;
create policy "chat_read_authenticated" on public.chat_messages
  for select to authenticated using (true);

-- chat_reads : accuses de lecture
drop policy if exists "reads_select_all" on public.chat_reads;
create policy "reads_select_authenticated" on public.chat_reads
  for select to authenticated using (true);

-- auction_bids : identite des encherisseurs et montants
drop policy if exists "auction_bids_select_all" on public.auction_bids;
create policy "auction_bids_select_authenticated" on public.auction_bids
  for select to authenticated using (true);

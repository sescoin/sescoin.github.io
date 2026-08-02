-- ============================================================
-- Activation du temps réel sur les tables déjà consommées en
-- `.stream()` par l'application Flutter.
--
-- CONSTAT
-- Seules chat_messages et chat_reads avaient été ajoutées à la
-- publication `supabase_realtime` (migrations 20260531 et
-- 20260604). Or profile_service, transaction_service,
-- notification_service, loan_service, marketplace_service et
-- currency_service appellent tous `.stream(primaryKey: [...])`
-- sur d'autres tables.
--
-- Un `.stream()` sur une table absente de la publication ne
-- lève aucune erreur : il effectue son chargement initial puis
-- attend indéfiniment des événements qui n'arriveront jamais.
-- La liste se fige donc sur son premier état.
--
-- Symptômes corrigés :
--   * account_requests → l'admin reçoit la notification d'une
--     nouvelle demande mais doit rafraîchir « Demandes de
--     comptes » pour la voir ; idem après reconnexion.
--   * profiles → le classement reste sur « Aucun profil » après
--     l'approbation d'un compte jusqu'à redémarrage de l'app.
--
-- Les RLS continuent de s'appliquer aux flux temps réel : un
-- élève ne reçoit que les lignes que ses policies autorisent.
-- ============================================================

do $$
declare
  target_table text;
begin
  foreach target_table in array array[
    'profiles',
    'account_requests',
    'transactions',
    'notifications',
    'loans',
    'marketplace_items',
    'exchange_rates'
  ] loop
    -- Idempotent : `alter publication ... add table` échoue si la
    -- table est déjà publiée.
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = target_table
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        target_table
      );
    end if;
  end loop;
end $$;

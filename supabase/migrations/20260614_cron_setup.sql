-- Ce script doit être exécuté HORS transaction (pas de begin/commit)
-- pg_cron ne fonctionne pas à l'intérieur d'une transaction.
--
-- Pré-requis : activer l'extension pg_cron dans le dashboard Supabase
--   Dashboard → Database → Extensions → pg_cron → Enable
--
-- Ensuite, coller ce bloc dans l'éditeur SQL de Supabase (SQL Editor).

-- Supprimer l'ancien job si existant
select cron.unschedule('process-overdue-loans')
where exists (
  select 1 from cron.job where jobname = 'process-overdue-loans'
);

-- Planifier toutes les 15 minutes
select cron.schedule(
  'process-overdue-loans',
  '* * * * *',
  $$select public.process_overdue_loans()$$
);

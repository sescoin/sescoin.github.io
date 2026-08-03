-- ============================================================
-- Retention des messages de chat
--
-- Deux regles distinctes :
--   * chat de classe (class_id non nul) : les messages disparaissent au bout
--     de 24 heures ;
--   * annonces (class_id nul) : elles restent affichees jusqu'au 1er septembre
--     suivant, autrement dit jusqu'au changement d'annee scolaire.
--
-- La colonne expires_at n'est PAS reutilisee ici : elle porte deja la duree de
-- validite des offres de cadeau et de pret (« ce cadeau a expire »). La purge
-- s'appuie donc sur created_at.
-- ============================================================

-- Debut de l'annee scolaire en cours : le 1er septembre revolu le plus
-- recent. Toute annonce anterieure appartient a l'annee precedente.
create or replace function public.current_school_year_start()
returns timestamptz
language sql
immutable
as $$
  select make_timestamptz(
    case
      when extract(month from now()) >= 9 then extract(year from now())::int
      else extract(year from now())::int - 1
    end,
    9, 1, 0, 0, 0
  );
$$;

create or replace function public.purge_expired_chat_messages()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deleted integer;
begin
  with removed as (
    delete from public.chat_messages
    where (class_id is not null and created_at < now() - interval '24 hours')
       or (class_id is null and created_at < public.current_school_year_start())
    returning 1
  )
  select count(*) into v_deleted from removed;

  return v_deleted;
end;
$$;

revoke all on function public.purge_expired_chat_messages() from public;
revoke all on function public.purge_expired_chat_messages() from anon;

-- ============================================================
-- Planification (a EXECUTER HORS TRANSACTION, comme 20260614_cron_setup.sql)
--
-- Si pg_cron n'est pas active : Dashboard -> Database -> Extensions -> pg_cron
--
-- Toutes les 15 minutes : la granularite d'une suppression a 24 h n'exige pas
-- mieux, et cela evite de reveiller la base a chaque minute.
-- ============================================================

select cron.unschedule('purge-expired-chat-messages')
where exists (
  select 1 from cron.job where jobname = 'purge-expired-chat-messages'
);

select cron.schedule(
  'purge-expired-chat-messages',
  '*/15 * * * *',
  $$select public.purge_expired_chat_messages()$$
);

-- ============================================================
-- Simplification de la moderation et temps reel des signalements
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. Plus de notification au signaleur, plus de sanction sur recidive
--
-- Prevenir celui qui signale ajoutait du bruit sans rien apprendre d'utile,
-- et la sanction automatique au troisieme signalement retenu retirait a
-- l'administrateur une decision qui lui revient : il voit lui-meme qu'un
-- compte revient souvent.
--
-- Le declencheur perdait ainsi ses deux raisons d'etre : il est supprime.
-- ─────────────────────────────────────────────────────────────
drop trigger if exists trg_on_report_reviewed on public.reports;
drop function if exists public.on_report_reviewed();
drop function if exists public.confirmed_reports_count(uuid);

-- ─────────────────────────────────────────────────────────────
-- 2. Censure immediate lorsque l'administrateur signale
--
-- Un signalement venant de l'administrateur ne demande pas d'arbitrage :
-- le message part directement en censure, et le signalement est enregistre
-- comme deja traite.
-- ─────────────────────────────────────────────────────────────
create or replace function public.admin_censor_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_msg public.chat_messages%rowtype;
  v_me public.profiles%rowtype;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if v_me.id is null or v_me.role <> 'admin' then
    raise exception 'Action réservée à l''administrateur.';
  end if;

  select * into v_msg from public.chat_messages where id = p_message_id;
  if v_msg.id is null then
    raise exception 'Message introuvable.';
  end if;
  if coalesce(v_msg.is_censored, false) then
    raise exception 'Ce message est déjà censuré.';
  end if;

  -- Conserve le texte d'origine : c'est lui qui figurera dans la
  -- transcription remise a la moderation.
  update public.chat_messages
  set original_content = coalesce(original_content, content),
      content = 'Message censuré',
      is_censored = true
  where id = p_message_id;

  -- Trace du signalement, deja clos.
  insert into public.reports (
    message_id, reporter_id, reporter_username,
    reported_id, reported_username, message_content, class_id,
    status, reviewed_at
  ) values (
    p_message_id, v_me.id, v_me.username,
    v_msg.user_id, v_msg.username, v_msg.content, v_msg.class_id,
    'reviewed', now()
  )
  on conflict do nothing;
end;
$$;

revoke all on function public.admin_censor_message(uuid) from public, anon;
grant execute on function public.admin_censor_message(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- 3. Temps reel
--
-- Un `.stream()` sur une table absente de la publication se fige en silence,
-- sans lever d'erreur : c'est pourquoi un signalement n'apparaissait qu'apres
-- rechargement complet de l'application, alors meme que la notification
-- arrivait a l'heure.
-- ─────────────────────────────────────────────────────────────
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'reports'
  ) then
    alter publication supabase_realtime add table public.reports;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'sanctions'
  ) then
    alter publication supabase_realtime add table public.sanctions;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end
$$;

-- REPLICA IDENTITY FULL : sans quoi les evenements de mise a jour et de
-- suppression ne transportent que la cle primaire, et les filtres cote
-- client ne s'appliquent pas.
alter table public.reports replica identity full;
alter table public.sanctions replica identity full;

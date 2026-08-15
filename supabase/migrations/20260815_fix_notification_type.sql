-- ============================================================
-- Corrige le type des notifications de moderation
--
-- report_chat_message inserait une notification de type « admin », valeur
-- absente de la contrainte notifications_type_check. Signaler un message
-- echouait donc avec :
--   new row for relation "notifications" violates check constraint
--   "notifications_type_check"
--
-- Le type generique prevu par le schema est « system ». Cette migration
-- redefinit la seule fonction deja en base ; les autres fonctions concernees
-- sont corrigees directement dans 20260815_sanctions_and_filter_v2.sql.
-- ============================================================

create or replace function public.report_chat_message(p_message_id uuid)
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
  if v_me.id is null then
    raise exception 'Non authentifié.';
  end if;

  select * into v_msg from public.chat_messages where id = p_message_id;
  if v_msg.id is null then
    raise exception 'Message introuvable.';
  end if;

  if v_msg.user_id = auth.uid() then
    raise exception 'Impossible de signaler son propre message.';
  end if;

  if exists (
    select 1 from public.reports
    where reporter_id = auth.uid() and message_id = p_message_id
  ) then
    raise exception 'Ce message a déjà été signalé.';
  end if;

  insert into public.reports (
    message_id, reporter_id, reporter_username,
    reported_id, reported_username, message_content, class_id
  ) values (
    p_message_id, auth.uid(), v_me.username,
    v_msg.user_id, v_msg.username, v_msg.content, v_msg.class_id
  );

  -- L'administrateur est prevenu immediatement.
  insert into public.notifications (user_id, type, title, body)
  select p.id, 'system', 'Nouveau signalement',
         'Message de @' || v_msg.username || ' signalé par @' || v_me.username
  from public.profiles p
  where p.role = 'admin';
end;
$$;

revoke all on function public.report_chat_message(uuid) from public, anon;
grant execute on function public.report_chat_message(uuid) to authenticated;

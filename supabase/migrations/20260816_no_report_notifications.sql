-- ============================================================
-- Plus aucune notification declenchee par un signalement
--
-- Le signalement se lit deja la ou il compte : la pastille de l'ecran
-- Administration pour l'administrateur, le bandeau du chat pour le compte
-- mis en sourdine. Les notifications faisaient doublon.
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- Depot d'un signalement : plus d'alerte aux administrateurs
-- ─────────────────────────────────────────────────────────────
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
end;
$$;

revoke all on function public.report_chat_message(uuid) from public, anon;
grant execute on function public.report_chat_message(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- Sourdine apres trois signalements retenus : plus de notification
--
-- Le champ de saisie du chat est desactive et porte la mention « Compte
-- muet », l'information ne se perd donc pas.
-- ─────────────────────────────────────────────────────────────
create or replace function public.on_report_reviewed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_confirmed integer;
  v_username text;
begin
  if old.status = new.status or new.status <> 'reviewed' then
    return new;
  end if;

  v_confirmed := public.confirmed_reports_count(new.reported_id);
  if v_confirmed < 3 then
    return new;
  end if;

  select username into v_username
  from public.profiles where id = new.reported_id;

  update public.profiles
  set chat_muted_until = greatest(
    coalesce(chat_muted_until, now()),
    now() + interval '24 hours'
  )
  where id = new.reported_id;

  insert into public.sanctions (
    user_id, username, kind, reason, until, automatic
  ) values (
    new.reported_id, v_username, 'mute',
    v_confirmed || ' signalements retenus',
    now() + interval '24 hours', true
  );

  return new;
end;
$$;

drop trigger if exists trg_on_report_reviewed on public.reports;
create trigger trg_on_report_reviewed
  after update of status on public.reports
  for each row execute function public.on_report_reviewed();

-- ─────────────────────────────────────────────────────────────
-- Celles deja distribuees sont retirees des boites de reception
--
-- La sourdine du filtre porte le meme titre mais un autre corps : elle ne
-- vient pas d'un signalement et reste en place.
-- ─────────────────────────────────────────────────────────────
delete from public.notifications
where title in ('Nouveau signalement', 'Signalement traité')
   or (title = 'Chat suspendu 24 h' and body like '%signalés%');

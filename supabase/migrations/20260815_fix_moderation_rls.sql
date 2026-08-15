-- ============================================================
-- Corrige les deux erreurs de moderation remontees a l'usage
--
-- 1. « New row violates row-level security policy for table notifications »
--    en traitant ou ecartant un signalement.
--    Le declencheur on_report_reviewed s'execute avec les droits de
--    l'appelant, et non de son proprietaire : l'insertion de la notification
--    destinee au signaleur se heurtait aux policies de notifications.
--    La fonction passe en security definer.
--
-- 2. « violates check constraint notifications_type_check » en bannissant.
--    Les fonctions ecrites avec le type « admin » sont redefinies ici avec
--    « system », le type generique prevu par le schema. Elles sont deja en
--    base : corriger le fichier source ne suffisait pas.
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. Suspension a duree choisie
-- ─────────────────────────────────────────────────────────────
create or replace function public.admin_ban_user_temp(
  p_user_id uuid,
  p_reason text,
  p_minutes integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin public.profiles%rowtype;
  v_target public.profiles%rowtype;
  v_until timestamptz;
begin
  select * into v_admin from public.profiles where id = auth.uid();
  if v_admin.id is null or v_admin.role <> 'admin' then
    raise exception 'Action réservée à l''administrateur.';
  end if;

  select * into v_target from public.profiles where id = p_user_id;
  if v_target.id is null then
    raise exception 'Compte introuvable.';
  end if;
  if v_target.role = 'admin' then
    raise exception 'Un administrateur ne peut pas être banni.';
  end if;

  v_until := case
    when p_minutes is null or p_minutes <= 0 then null
    else now() + make_interval(mins => p_minutes)
  end;

  update public.profiles
  set is_banned = true,
      ban_reason = nullif(trim(coalesce(p_reason, '')), ''),
      banned_until = v_until
  where id = p_user_id;

  insert into public.sanctions (
    user_id, username, kind, reason, until,
    issued_by, issued_by_username, automatic
  ) values (
    p_user_id, v_target.username, 'ban',
    nullif(trim(coalesce(p_reason, '')), ''), v_until,
    v_admin.id, v_admin.username, false
  );

  insert into public.notifications (user_id, type, title, body)
  values (
    p_user_id, 'system', 'Compte suspendu',
    case
      when v_until is null then 'Votre compte a été suspendu.'
      else 'Votre compte est suspendu jusqu''au ' ||
           to_char(v_until at time zone 'Europe/Paris', 'DD/MM/YYYY à HH24:MI') || '.'
    end
  );
end;
$$;

revoke all on function public.admin_ban_user_temp(uuid, text, integer) from public, anon;
grant execute on function public.admin_ban_user_temp(uuid, text, integer) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- 2. Levee automatique
-- ─────────────────────────────────────────────────────────────
create or replace function public.release_expired_sanctions()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_released integer := 0;
  v_row record;
begin
  for v_row in
    select id, username from public.profiles
    where is_banned and banned_until is not null and banned_until <= now()
  loop
    update public.profiles
    set is_banned = false, ban_reason = null, banned_until = null
    where id = v_row.id;

    insert into public.sanctions (user_id, username, kind, reason, automatic)
    values (v_row.id, v_row.username, 'unban', 'Fin de la suspension', true);

    insert into public.notifications (user_id, type, title, body)
    values (
      v_row.id, 'system', 'Suspension levée',
      'Votre compte est de nouveau actif.'
    );

    v_released := v_released + 1;
  end loop;

  update public.profiles
  set chat_muted_until = null, chat_warning_count = 0
  where chat_muted_until is not null and chat_muted_until <= now();

  return v_released;
end;
$$;

revoke all on function public.release_expired_sanctions() from public, anon;

-- ─────────────────────────────────────────────────────────────
-- 3. Cloture d'un signalement
--
-- security definer : le declencheur tourne sinon avec les droits de
-- l'administrateur connecte, qui n'a pas le droit d'inserer une notification
-- destinee a quelqu'un d'autre.
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
  if old.status = new.status then
    return new;
  end if;

  insert into public.notifications (user_id, type, title, body)
  values (
    new.reporter_id, 'system', 'Signalement traité',
    case
      when new.status = 'reviewed'
        then 'Votre signalement a été retenu. Merci de votre vigilance.'
      else 'Votre signalement a été examiné, aucune suite n''a été donnée.'
    end
  );

  if new.status = 'reviewed' then
    v_confirmed := public.confirmed_reports_count(new.reported_id);

    if v_confirmed >= 3 then
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
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_on_report_reviewed on public.reports;
create trigger trg_on_report_reviewed
  after update of status on public.reports
  for each row execute function public.on_report_reviewed();

-- ─────────────────────────────────────────────────────────────
-- 4. Sourdine automatique : type de notification corrige, et le message
--    d'origine est conserve avant censure
--
-- Le contenu fautif etait perdu : l'export d'une discussion ne montrait que
-- « Message censuré », alors que c'est justement ce qui a ete ecrit qui
-- interesse la moderation. Le chat, lui, continue de n'afficher que la
-- mention — sans quoi le filtre ne servirait a rien.
-- ─────────────────────────────────────────────────────────────
create or replace function public.enforce_chat_filter()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
  v_censored_24h integer;
  v_username text;
begin
  if coalesce(new.is_censored, false) then
    return new;
  end if;

  if new.content is null or not public.contains_forbidden_words(new.content) then
    return new;
  end if;

  -- Archive avant remplacement, sauf si une version anterieure y figure deja.
  if new.original_content is null then
    new.original_content := new.content;
  end if;

  new.content := 'Message censuré';
  new.is_censored := true;

  if new.user_id is null then
    return new;
  end if;

  update public.profiles
  set chat_warning_count = coalesce(chat_warning_count, 0) + 1
  where id = new.user_id
  returning chat_warning_count, username into v_count, v_username;

  select count(*) + 1 into v_censored_24h
  from public.chat_messages
  where user_id = new.user_id
    and is_censored
    and created_at > now() - interval '24 hours';

  if v_censored_24h >= 9 then
    update public.profiles
    set chat_muted_until = now() + interval '24 hours'
    where id = new.user_id;

    insert into public.sanctions (
      user_id, username, kind, reason, until, automatic
    ) values (
      new.user_id, v_username, 'mute',
      v_censored_24h || ' messages censurés en 24 h',
      now() + interval '24 hours', true
    );

    insert into public.notifications (user_id, type, title, body)
    values (
      new.user_id, 'system', 'Chat suspendu 24 h',
      'Trop de messages inappropriés : le chat vous est fermé pour 24 heures.'
    );
  elsif coalesce(v_count, 0) >= 3 then
    update public.profiles
    set chat_muted_until = now() + interval '10 minutes'
    where id = new.user_id;
  end if;

  return new;
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- 5. Signalement : les messages de l'administrateur sont hors de portee
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
  v_author_role text;
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

  select role into v_author_role
  from public.profiles where id = v_msg.user_id;

  if v_author_role = 'admin' then
    raise exception 'Les messages de l''administrateur ne peuvent pas être signalés.';
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

  insert into public.notifications (user_id, type, title, body)
  select p.id, 'system', 'Nouveau signalement',
         'Message de @' || v_msg.username || ' signalé par @' || v_me.username
  from public.profiles p
  where p.role = 'admin';
end;
$$;

revoke all on function public.report_chat_message(uuid) from public, anon;
grant execute on function public.report_chat_message(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- 6. Transcription : montrer le message d'origine plutot que la mention
-- ─────────────────────────────────────────────────────────────
create or replace function public.admin_chat_transcript(p_class_id uuid)
returns table (
  created_at timestamptz,
  username text,
  display_name text,
  content text,
  original_content text,
  is_deleted boolean,
  is_censored boolean,
  edited_at timestamptz,
  message_type text
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.current_profile_is_admin() then
    raise exception 'Action réservée à l''administrateur.';
  end if;

  return query
  select m.created_at, m.username, m.display_name,
         -- Un message censure est restitue tel qu'il a ete ecrit : c'est ce
         -- qui interesse la moderation.
         case
           when m.is_censored and m.original_content is not null
             then m.original_content
           else m.content
         end,
         m.original_content, m.is_deleted, m.is_censored, m.edited_at,
         m.message_type
  from public.chat_messages m
  where (p_class_id is null and m.class_id is null)
     or (p_class_id is not null and m.class_id = p_class_id)
  order by m.created_at;
end;
$$;

revoke all on function public.admin_chat_transcript(uuid) from public, anon;
grant execute on function public.admin_chat_transcript(uuid) to authenticated;

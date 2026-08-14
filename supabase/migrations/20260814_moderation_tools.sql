-- ============================================================
-- Outils de moderation : historique, delai de suppression, transcription
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. Conserver le contenu d'origine d'un message modifie
--
-- Sans cela, un eleve pouvait poster une insulte puis la remplacer par un
-- texte anodin : l'administrateur ne voyait plus que la version corrigee.
-- ─────────────────────────────────────────────────────────────
alter table public.chat_messages
  add column if not exists original_content text;

create or replace function public.keep_original_content()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  -- Seulement a la premiere modification : les suivantes ne doivent pas
  -- ecraser la version initiale.
  if new.content is distinct from old.content
     and old.original_content is null
     and not coalesce(old.is_deleted, false) then
    new.original_content := old.content;
  end if;
  return new;
end;
$$;

-- Nom volontairement place apres « trg_enforce_chat_filter » dans l'ordre
-- alphabetique : le filtre s'applique d'abord, on archive ensuite l'ancien
-- contenu, jamais la version censuree.
drop trigger if exists trg_keep_original_content on public.chat_messages;
create trigger trg_keep_original_content
  before update of content on public.chat_messages
  for each row execute function public.keep_original_content();

-- ─────────────────────────────────────────────────────────────
-- 2. Delai avant suppression
--
-- Un message ne peut etre retire par son auteur qu'apres quinze secondes.
-- Sans ce delai, il suffisait d'envoyer une insulte et de l'effacer aussitot
-- pour qu'elle reste invisible a la moderation tout en ayant ete lue.
-- L'administrateur, lui, supprime sans attendre.
-- ─────────────────────────────────────────────────────────────
create or replace function public.delete_chat_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_id  uuid := auth.uid();
  v_msg      public.chat_messages%rowtype;
  v_is_admin boolean;
  v_age      interval;
begin
  if v_auth_id is null then
    raise exception 'Non authentifié.';
  end if;

  select * into v_msg
  from public.chat_messages
  where id = p_message_id
    and not is_deleted;

  if v_msg.id is null then
    raise exception 'Message introuvable.';
  end if;

  select (role = 'admin') into v_is_admin
  from public.profiles
  where id = v_auth_id;

  if not coalesce(v_is_admin, false) then
    if v_msg.user_id is distinct from v_auth_id then
      raise exception 'Suppression non autorisée.';
    end if;

    v_age := now() - v_msg.created_at;
    if v_age < interval '15 seconds' then
      raise exception 'Un message ne peut être supprimé que 15 secondes après son envoi (encore %s).',
        greatest(1, ceil(extract(epoch from (interval '15 seconds' - v_age)))::int);
    end if;
  end if;

  update public.chat_messages
  set is_deleted = true
  where id = p_message_id;
end;
$$;

grant execute on function public.delete_chat_message(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- 3. Transcription d'une discussion
--
-- Alimente le fichier telechargeable depuis un signalement. Reserve a
-- l'administrateur : la fonction contourne les policies, le controle de role
-- doit donc figurer dans son corps.
--
-- Les messages supprimes sont conserves en base (is_deleted) et ressortent
-- donc ici, sauf s'ils ont ete purges par la retention.
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
  select m.created_at, m.username, m.display_name, m.content,
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

-- ─────────────────────────────────────────────────────────────
-- 4. Signalements groupes par message
--
-- L'ecran d'administration classe les messages du plus signale au moins
-- signale. Agreger cote base evite de rapatrier tous les signalements pour
-- les regrouper ensuite.
-- ─────────────────────────────────────────────────────────────
create or replace function public.admin_grouped_reports()
returns table (
  message_id uuid,
  message_content text,
  reported_id uuid,
  reported_username text,
  class_id uuid,
  report_count bigint,
  reporters text[],
  first_reported_at timestamptz,
  last_reported_at timestamptz,
  pending_count bigint,
  report_ids uuid[]
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
  select
    r.message_id,
    -- Le contenu est copie a chaque signalement : on retient le plus recent.
    (array_agg(r.message_content order by r.created_at desc))[1],
    r.reported_id,
    r.reported_username,
    (array_agg(r.class_id order by r.created_at desc))[1],
    count(*),
    array_agg(distinct r.reporter_username),
    min(r.created_at),
    max(r.created_at),
    count(*) filter (where r.status = 'pending'),
    array_agg(r.id)
  from public.reports r
  group by r.message_id, r.reported_id, r.reported_username
  order by count(*) filter (where r.status = 'pending') desc, count(*) desc,
           max(r.created_at) desc;
end;
$$;

revoke all on function public.admin_grouped_reports() from public, anon;
grant execute on function public.admin_grouped_reports() to authenticated;

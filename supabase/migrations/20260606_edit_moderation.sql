begin;

-- Rebuild edit/delete RPCs so Flutter receives the same JSON shape as send.
drop function if exists public.edit_chat_message(uuid, text);
drop function if exists public.delete_chat_message(uuid);

create or replace function public.edit_chat_message(
  p_message_id uuid,
  p_content    text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_id       uuid := auth.uid();
  v_user          public.profiles%rowtype;
  v_message       public.chat_messages%rowtype;
  v_lower         text;
  v_is_bad        boolean := false;
  v_bad_patterns  text[] := array[
    'connard', 'connasse', 'conne ', 'espece de con', 'espece de con',
    'salope', 'sale pute', 'pute', 'putain de',
    'fdp', 'fils de pute', 'fille de pute',
    'nique ta', 'nique sa', 'va te faire niquer', 'ntm',
    'encule', 'encule', 'enculer', 'va te faire enc',
    'batard', 'batard', 'fils de',
    'trouduc', 'trou du cul', 'ta gueule', 'ferme ta gueule', 'ftg',
    'va te faire', 'vtff', 'va crever', 'creve',
    'abruti', 'imbecile', 'imbecile', 'cretin', 'cretin', 'debile', 'debile',
    'pede', 'pede', ' pd ', 'grosse merde',
    'je vais te tuer', 'je vais vous tuer', 'je vais te frapper',
    'je vais te casser', 'je vais t''eclater', 'on va te',
    'tue toi', 'suicide toi', 'va mourir', 'tu vas mourir',
    'mort a', 'mort a '
  ];
  v_pat text;
begin
  if v_auth_id is null then
    raise exception 'Non authentifie.';
  end if;

  select * into v_user
  from public.profiles
  where id = v_auth_id;

  if v_user.id is null then
    raise exception 'Profil introuvable.';
  end if;

  if v_user.is_banned then
    raise exception 'Votre compte est banni.';
  end if;

  select * into v_message
  from public.chat_messages
  where id = p_message_id
    and not is_deleted
  for update;

  if v_message.id is null then
    raise exception 'Message introuvable.';
  end if;

  if v_message.user_id is distinct from v_auth_id then
    raise exception 'Modification non autorisee.';
  end if;

  if v_user.chat_muted_until is not null and v_user.chat_muted_until <= now() then
    update public.profiles
    set chat_muted_until = null,
        chat_warning_count = 0
    where id = v_auth_id
    returning * into v_user;
  end if;

  if v_user.chat_muted_until is not null and v_user.chat_muted_until > now() then
    raise exception 'Vous etes muet pour encore % minute(s).',
      greatest(1, ceil(extract(epoch from (v_user.chat_muted_until - now())) / 60)::int);
  end if;

  if length(trim(p_content)) = 0 then
    raise exception 'Message vide.';
  end if;

  if length(p_content) > 500 then
    raise exception 'Message trop long (500 caracteres max).';
  end if;

  v_lower := lower(p_content);
  foreach v_pat in array v_bad_patterns loop
    if v_lower like '%' || v_pat || '%' then
      v_is_bad := true;
      exit;
    end if;
  end loop;

  if v_is_bad then
    update public.profiles
    set chat_warning_count = chat_warning_count + 1
    where id = v_auth_id
    returning * into v_user;

    if v_user.chat_warning_count >= 3 then
      update public.profiles
      set chat_muted_until = now() + interval '10 minutes'
      where id = v_auth_id
      returning * into v_user;
    end if;

    update public.chat_messages
    set content = 'Message censure',
        is_censored = true,
        edited_at = now()
    where id = p_message_id
    returning * into v_message;

    return jsonb_build_object(
      'message',       to_jsonb(v_message),
      'warning',       true,
      'warning_count', v_user.chat_warning_count,
      'muted',         v_user.chat_muted_until is not null
    );
  end if;

  update public.chat_messages
  set content = trim(p_content),
      is_censored = false,
      edited_at = now()
  where id = p_message_id
  returning * into v_message;

  return jsonb_build_object(
    'message',       to_jsonb(v_message),
    'warning',       false,
    'warning_count', v_user.chat_warning_count,
    'muted',         false
  );
end;
$$;

grant execute on function public.edit_chat_message(uuid, text) to authenticated;

create or replace function public.delete_chat_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_id uuid := auth.uid();
  v_owner_id uuid;
begin
  if v_auth_id is null then
    raise exception 'Non authentifie.';
  end if;

  select user_id into v_owner_id
  from public.chat_messages
  where id = p_message_id
    and not is_deleted;

  if v_owner_id is null then
    raise exception 'Message introuvable.';
  end if;

  if v_owner_id is distinct from v_auth_id then
    raise exception 'Suppression non autorisee.';
  end if;

  update public.chat_messages
  set is_deleted = true
  where id = p_message_id;
end;
$$;

grant execute on function public.delete_chat_message(uuid) to authenticated;

commit;

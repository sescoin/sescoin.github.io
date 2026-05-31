begin;

-- Colonnes de modération sur les profils
alter table public.profiles
  add column if not exists chat_warning_count int not null default 0,
  add column if not exists chat_muted_until timestamptz;

-- Table des messages du chat
create table if not exists public.chat_messages (
  id           uuid        primary key default gen_random_uuid(),
  user_id      uuid        references public.profiles(id) on delete set null,
  username     text        not null,
  display_name text        not null,
  avatar_url   text,
  content      text        not null,
  is_censored  boolean     not null default false,
  created_at   timestamptz not null default now()
);

-- RLS
alter table public.chat_messages enable row level security;

create policy "chat_read_all" on public.chat_messages
  for select using (true);

create policy "chat_insert_own" on public.chat_messages
  for insert with check (auth.uid() = user_id);

-- Realtime
alter publication supabase_realtime add table public.chat_messages;

-- Fonction d'envoi avec modération
create or replace function public.send_chat_message(p_content text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user          public.profiles%rowtype;
  v_lower         text;
  v_is_bad        boolean := false;
  v_message       public.chat_messages%rowtype;
  v_bad_patterns  text[] := array[
    -- Insultes courantes
    'connard', 'connasse', 'conne ', 'espece de con', 'espèce de con',
    'salope', 'sale pute', 'pute', 'putain de',
    'fdp', 'fils de pute', 'fille de pute',
    'nique ta', 'nique sa', 'va te faire niquer', 'ntm',
    'encule', 'enculé', 'enculer', 'va te faire enc',
    'batard', 'bâtard', 'fils de',
    'trouduc', 'trou du cul', 'ta gueule', 'ferme ta gueule', 'ftg',
    'va te faire', 'vtff', 'va crever', 'crève',
    'abruti', 'imbécile', 'imbecile', 'crétin', 'cretin', 'débile', 'debile',
    'pédé', 'pede', ' pd ', 'grosse merde',
    -- Menaces
    'je vais te tuer', 'je vais vous tuer', 'je vais te frapper',
    'je vais te casser', 'je vais t''éclater', 'on va te',
    'tue toi', 'suicide toi', 'va mourir', 'tu vas mourir',
    'mort à', 'mort a '
  ];
  v_pat text;
begin
  -- Charger l'utilisateur
  select * into v_user from public.profiles where id = auth.uid();

  if v_user.id is null then
    raise exception 'Non authentifié.';
  end if;

  if v_user.is_banned then
    raise exception 'Votre compte est banni.';
  end if;

  -- Réinitialiser le mute si expiré
  if v_user.chat_muted_until is not null and v_user.chat_muted_until <= now() then
    update public.profiles
    set chat_muted_until = null, chat_warning_count = 0
    where id = auth.uid();
    v_user.chat_muted_until := null;
    v_user.chat_warning_count := 0;
  end if;

  -- Vérifier si muet
  if v_user.chat_muted_until is not null and v_user.chat_muted_until > now() then
    raise exception 'Vous êtes muet pour encore % minute(s).',
      greatest(1, ceil(extract(epoch from (v_user.chat_muted_until - now())) / 60)::int);
  end if;

  -- Valider le contenu
  if length(trim(p_content)) = 0 then
    raise exception 'Message vide.';
  end if;

  if length(p_content) > 500 then
    raise exception 'Message trop long (500 caractères max).';
  end if;

  -- Détecter les mots interdits
  v_lower := lower(p_content);
  foreach v_pat in array v_bad_patterns loop
    if v_lower like '%' || v_pat || '%' then
      v_is_bad := true;
      exit;
    end if;
  end loop;

  if v_is_bad then
    -- Incrémenter l'avertissement
    update public.profiles
    set chat_warning_count = chat_warning_count + 1
    where id = auth.uid()
    returning * into v_user;

    -- Mute après 3 avertissements
    if v_user.chat_warning_count >= 3 then
      update public.profiles
      set chat_muted_until = now() + interval '10 minutes'
      where id = auth.uid()
      returning chat_muted_until into v_user.chat_muted_until;
    end if;

    -- Message censuré visible dans le chat
    insert into public.chat_messages (user_id, username, display_name, avatar_url, content, is_censored)
    values (
      auth.uid(), v_user.username, v_user.display_name, v_user.avatar_url,
      '🚫 Message censuré', true
    )
    returning * into v_message;

    return jsonb_build_object(
      'message',       to_jsonb(v_message),
      'warning',       true,
      'warning_count', v_user.chat_warning_count,
      'muted',         v_user.chat_muted_until is not null
    );
  end if;

  -- Message normal
  insert into public.chat_messages (user_id, username, display_name, avatar_url, content, is_censored)
  values (
    auth.uid(), v_user.username, v_user.display_name, v_user.avatar_url,
    trim(p_content), false
  )
  returning * into v_message;

  return jsonb_build_object(
    'message',       to_jsonb(v_message),
    'warning',       false,
    'warning_count', v_user.chat_warning_count,
    'muted',         false
  );
end;
$$;

grant execute on function public.send_chat_message(text) to authenticated;

commit;

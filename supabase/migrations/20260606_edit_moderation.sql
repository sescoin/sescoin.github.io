begin;

-- Refaire edit_chat_message avec la même vérification anti-insultes que send_chat_message
create or replace function public.edit_chat_message(
  p_message_id uuid,
  p_content    text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user         public.profiles%rowtype;
  v_lower        text;
  v_is_bad       boolean := false;
  v_bad_patterns text[] := array[
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
    'je vais te tuer', 'je vais vous tuer', 'je vais te frapper',
    'je vais te casser', 'je vais t''éclater', 'on va te',
    'tue toi', 'suicide toi', 'va mourir', 'tu vas mourir',
    'mort à', 'mort a '
  ];
  v_pat text;
begin
  select * into v_user from public.profiles where id = auth.uid();
  if v_user.id is null then
    raise exception 'Non authentifié.';
  end if;

  if length(trim(p_content)) = 0 then
    raise exception 'Message vide.';
  end if;

  if length(p_content) > 500 then
    raise exception 'Message trop long (500 caractères max).';
  end if;

  -- Vérification anti-insultes
  v_lower := lower(p_content);
  foreach v_pat in array v_bad_patterns loop
    if v_lower like '%' || v_pat || '%' then
      v_is_bad := true;
      exit;
    end if;
  end loop;

  if v_is_bad then
    -- Même logique d'avertissement que l'envoi
    update public.profiles
    set chat_warning_count = chat_warning_count + 1
    where id = auth.uid()
    returning * into v_user;

    if v_user.chat_warning_count >= 3 then
      update public.profiles
      set chat_muted_until = now() + interval '10 minutes'
      where id = auth.uid();
    end if;

    raise exception 'Modification refusée : contenu inapproprié (avertissement %/3).',
      v_user.chat_warning_count;
  end if;

  update public.chat_messages
  set content   = trim(p_content),
      edited_at = now()
  where id      = p_message_id
    and user_id = auth.uid()
    and not is_deleted;

  if not found then
    raise exception 'Message introuvable ou modification non autorisée.';
  end if;
end;
$$;

commit;

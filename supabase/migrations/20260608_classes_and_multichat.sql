begin;

-- ── 1. Table classes ──────────────────────────────────────────────────────────

create table public.classes (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  created_at timestamptz not null default now()
);

alter table public.classes enable row level security;

create policy "classes_select" on public.classes
  for select to authenticated using (true);

-- ── 2. Lier profils et demandes aux classes ───────────────────────────────────

alter table public.profiles
  add column if not exists class_id uuid references public.classes(id) on delete set null;

alter table public.account_requests
  add column if not exists class_id uuid references public.classes(id) on delete set null;

-- ── 3. Enrichir chat_messages pour le multi-room ─────────────────────────────
-- class_id IS NULL  → chat global
-- class_id IS NOT NULL → chat de la classe

alter table public.chat_messages
  add column if not exists class_id      uuid references public.classes(id) on delete cascade,
  add column if not exists message_type  text not null default 'text',
  add column if not exists loan_amount   numeric,
  add column if not exists loan_note     text;

-- ── 4. get_classes() ──────────────────────────────────────────────────────────

create or replace function public.get_classes()
returns table(id uuid, name text, member_count bigint, created_at timestamptz)
language sql
security definer
set search_path = public
as $$
  select c.id, c.name, count(p.id) as member_count, c.created_at
  from classes c
  left join profiles p on p.class_id = c.id
  group by c.id, c.name, c.created_at
  order by c.created_at;
$$;

grant execute on function public.get_classes() to authenticated;

-- ── 5. create_class(p_name) ───────────────────────────────────────────────────

create or replace function public.create_class(p_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_id  uuid := auth.uid();
  v_class_id uuid;
begin
  if not exists (select 1 from profiles where id = v_auth_id and role = 'admin') then
    raise exception 'Non autorisé.';
  end if;
  if length(trim(p_name)) = 0 then
    raise exception 'Le nom de la classe ne peut pas être vide.';
  end if;
  insert into classes (name) values (trim(p_name)) returning id into v_class_id;
  return v_class_id;
end;
$$;

grant execute on function public.create_class(text) to authenticated;

-- ── 6. rename_class(p_class_id, p_name) ──────────────────────────────────────

create or replace function public.rename_class(p_class_id uuid, p_name text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_id uuid := auth.uid();
begin
  if not exists (select 1 from profiles where id = v_auth_id and role = 'admin') then
    raise exception 'Non autorisé.';
  end if;
  if length(trim(p_name)) = 0 then
    raise exception 'Le nom de la classe ne peut pas être vide.';
  end if;
  update classes set name = trim(p_name) where id = p_class_id;
  if not found then
    raise exception 'Classe introuvable.';
  end if;
end;
$$;

grant execute on function public.rename_class(uuid, text) to authenticated;

-- ── 7. delete_class(p_class_id) ───────────────────────────────────────────────

create or replace function public.delete_class(p_class_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_id uuid := auth.uid();
begin
  if not exists (select 1 from profiles where id = v_auth_id and role = 'admin') then
    raise exception 'Non autorisé.';
  end if;
  -- Retirer les membres de la classe avant suppression
  update profiles set class_id = null where class_id = p_class_id;
  delete from classes where id = p_class_id;
  if not found then
    raise exception 'Classe introuvable.';
  end if;
end;
$$;

grant execute on function public.delete_class(uuid) to authenticated;

-- ── 8. set_user_class(p_user_id, p_class_id) ─────────────────────────────────

create or replace function public.set_user_class(p_user_id uuid, p_class_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_id uuid := auth.uid();
begin
  if not exists (select 1 from profiles where id = v_auth_id and role = 'admin') then
    raise exception 'Non autorisé.';
  end if;
  update profiles set class_id = p_class_id where id = p_user_id;
  if not found then
    raise exception 'Utilisateur introuvable.';
  end if;
end;
$$;

grant execute on function public.set_user_class(uuid, uuid) to authenticated;

-- ── 9. send_global_message(p_content) — admin seulement ──────────────────────

create or replace function public.send_global_message(p_content text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_id      uuid := auth.uid();
  v_user         public.profiles%rowtype;
  v_message      public.chat_messages%rowtype;
  v_lower        text;
  v_is_bad       boolean := false;
  v_bad_patterns text[] := array[
    'connard','connasse','conne ','espece de con',
    'salope','sale pute','pute','putain de',
    'fdp','fils de pute','fille de pute',
    'nique ta','nique sa','va te faire niquer','ntm',
    'encule','enculer','va te faire enc',
    'batard','fils de',
    'trouduc','trou du cul','ta gueule','ferme ta gueule','ftg',
    'va te faire','vtff','va crever','creve',
    'abruti','imbecile','cretin','debile',
    'pede',' pd ','grosse merde',
    'je vais te tuer','je vais vous tuer','je vais te frapper',
    'je vais te casser','je vais t''eclater','on va te',
    'tue toi','suicide toi','va mourir','tu vas mourir',
    'mort a '
  ];
  v_pat text;
begin
  if v_auth_id is null then raise exception 'Non authentifié.'; end if;

  select * into v_user from profiles where id = v_auth_id;
  if v_user.id is null then raise exception 'Profil introuvable.'; end if;

  if v_user.role <> 'admin' then
    raise exception 'Seul l''administrateur peut envoyer des messages dans le chat global.';
  end if;

  if length(trim(p_content)) = 0 then raise exception 'Message vide.'; end if;
  if length(p_content) > 500 then raise exception 'Message trop long (500 caractères max).'; end if;

  v_lower := lower(p_content);
  foreach v_pat in array v_bad_patterns loop
    if v_lower like '%' || v_pat || '%' then v_is_bad := true; exit; end if;
  end loop;

  insert into chat_messages (
    user_id, username, display_name, avatar_url,
    content, is_censored, class_id, message_type,
    expires_at
  ) values (
    v_auth_id, v_user.username, v_user.display_name, v_user.avatar_url,
    case when v_is_bad then 'Message censuré' else trim(p_content) end,
    v_is_bad, null, 'text',
    now() + interval '7 days'
  ) returning * into v_message;

  return jsonb_build_object(
    'message', to_jsonb(v_message),
    'warning', false,
    'warning_count', 0,
    'muted', false
  );
end;
$$;

grant execute on function public.send_global_message(text) to authenticated;

-- ── 10. send_loan_request_chat(p_amount, p_note) ─────────────────────────────
-- Tout utilisateur peut envoyer une demande de prêt dans le chat global

create or replace function public.send_loan_request_chat(
  p_amount numeric,
  p_note   text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_id uuid := auth.uid();
  v_user    public.profiles%rowtype;
  v_message public.chat_messages%rowtype;
begin
  if v_auth_id is null then raise exception 'Non authentifié.'; end if;

  select * into v_user from profiles where id = v_auth_id;
  if v_user.id is null then raise exception 'Profil introuvable.'; end if;
  if v_user.is_banned then raise exception 'Votre compte est banni.'; end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'Montant invalide.';
  end if;

  insert into chat_messages (
    user_id, username, display_name, avatar_url,
    content, is_censored, class_id, message_type,
    loan_amount, loan_note,
    expires_at
  ) values (
    v_auth_id, v_user.username, v_user.display_name, v_user.avatar_url,
    coalesce(nullif(trim(p_note), ''), ''),
    false, null, 'loan_request',
    p_amount, nullif(trim(coalesce(p_note, '')), ''),
    now() + interval '7 days'
  ) returning * into v_message;

  return jsonb_build_object(
    'message', to_jsonb(v_message),
    'warning', false,
    'warning_count', 0,
    'muted', false
  );
end;
$$;

grant execute on function public.send_loan_request_chat(numeric, text) to authenticated;

-- ── 11. send_class_message(p_class_id, p_content) ────────────────────────────

create or replace function public.send_class_message(
  p_class_id uuid,
  p_content  text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_id      uuid := auth.uid();
  v_user         public.profiles%rowtype;
  v_message      public.chat_messages%rowtype;
  v_lower        text;
  v_is_bad       boolean := false;
  v_bad_patterns text[] := array[
    'connard','connasse','conne ','espece de con',
    'salope','sale pute','pute','putain de',
    'fdp','fils de pute','fille de pute',
    'nique ta','nique sa','va te faire niquer','ntm',
    'encule','enculer','va te faire enc',
    'batard','fils de',
    'trouduc','trou du cul','ta gueule','ferme ta gueule','ftg',
    'va te faire','vtff','va crever','creve',
    'abruti','imbecile','cretin','debile',
    'pede',' pd ','grosse merde',
    'je vais te tuer','je vais vous tuer','je vais te frapper',
    'je vais te casser','je vais t''eclater','on va te',
    'tue toi','suicide toi','va mourir','tu vas mourir',
    'mort a '
  ];
  v_pat text;
begin
  if v_auth_id is null then raise exception 'Non authentifié.'; end if;

  select * into v_user from profiles where id = v_auth_id;
  if v_user.id is null then raise exception 'Profil introuvable.'; end if;
  if v_user.is_banned then raise exception 'Votre compte est banni.'; end if;

  -- Vérifier que l'utilisateur appartient à la classe (ou est admin)
  if v_user.role <> 'admin' and v_user.class_id is distinct from p_class_id then
    raise exception 'Vous n''appartenez pas à cette classe.';
  end if;

  -- Vérifier que la classe existe
  if not exists (select 1 from classes where id = p_class_id) then
    raise exception 'Classe introuvable.';
  end if;

  -- Vérifier mute
  if v_user.chat_muted_until is not null and v_user.chat_muted_until <= now() then
    update profiles set chat_muted_until = null, chat_warning_count = 0
    where id = v_auth_id returning * into v_user;
  end if;

  if v_user.chat_muted_until is not null and v_user.chat_muted_until > now() then
    raise exception 'Vous êtes muet pour encore % minute(s).',
      greatest(1, ceil(extract(epoch from (v_user.chat_muted_until - now())) / 60)::int);
  end if;

  if length(trim(p_content)) = 0 then raise exception 'Message vide.'; end if;
  if length(p_content) > 500 then raise exception 'Message trop long (500 caractères max).'; end if;

  v_lower := lower(p_content);
  foreach v_pat in array v_bad_patterns loop
    if v_lower like '%' || v_pat || '%' then v_is_bad := true; exit; end if;
  end loop;

  if v_is_bad then
    update profiles set chat_warning_count = chat_warning_count + 1
    where id = v_auth_id returning * into v_user;

    if v_user.chat_warning_count >= 3 then
      update profiles set chat_muted_until = now() + interval '10 minutes'
      where id = v_auth_id returning * into v_user;
    end if;
  end if;

  insert into chat_messages (
    user_id, username, display_name, avatar_url,
    content, is_censored, class_id, message_type,
    expires_at
  ) values (
    v_auth_id, v_user.username, v_user.display_name, v_user.avatar_url,
    case when v_is_bad then 'Message censuré' else trim(p_content) end,
    v_is_bad, p_class_id, 'text',
    now() + interval '48 hours'
  ) returning * into v_message;

  return jsonb_build_object(
    'message',       to_jsonb(v_message),
    'warning',       v_is_bad,
    'warning_count', v_user.chat_warning_count,
    'muted',         v_user.chat_muted_until is not null
  );
end;
$$;

grant execute on function public.send_class_message(uuid, text) to authenticated;

-- ── 12. edit_class_message(p_message_id, p_content) ──────────────────────────

create or replace function public.edit_class_message(
  p_message_id uuid,
  p_content    text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_id      uuid := auth.uid();
  v_user         public.profiles%rowtype;
  v_message      public.chat_messages%rowtype;
  v_lower        text;
  v_is_bad       boolean := false;
  v_bad_patterns text[] := array[
    'connard','connasse','conne ','espece de con',
    'salope','sale pute','pute','putain de',
    'fdp','fils de pute','fille de pute',
    'nique ta','nique sa','va te faire niquer','ntm',
    'encule','enculer','va te faire enc',
    'batard','fils de',
    'trouduc','trou du cul','ta gueule','ferme ta gueule','ftg',
    'va te faire','vtff','va crever','creve',
    'abruti','imbecile','cretin','debile',
    'pede',' pd ','grosse merde',
    'je vais te tuer','je vais vous tuer','je vais te frapper',
    'je vais te casser','je vais t''eclater','on va te',
    'tue toi','suicide toi','va mourir','tu vas mourir',
    'mort a '
  ];
  v_pat text;
begin
  if v_auth_id is null then raise exception 'Non authentifié.'; end if;

  select * into v_user from profiles where id = v_auth_id;
  if v_user.id is null then raise exception 'Profil introuvable.'; end if;
  if v_user.is_banned then raise exception 'Votre compte est banni.'; end if;

  select * into v_message from chat_messages
  where id = p_message_id and not is_deleted
  for update;

  if v_message.id is null then raise exception 'Message introuvable.'; end if;
  if v_message.user_id is distinct from v_auth_id then
    raise exception 'Modification non autorisée.';
  end if;
  if v_message.message_type <> 'text' then
    raise exception 'Ce type de message ne peut pas être modifié.';
  end if;

  -- Vérifier mute
  if v_user.chat_muted_until is not null and v_user.chat_muted_until <= now() then
    update profiles set chat_muted_until = null, chat_warning_count = 0
    where id = v_auth_id returning * into v_user;
  end if;
  if v_user.chat_muted_until is not null and v_user.chat_muted_until > now() then
    raise exception 'Vous êtes muet pour encore % minute(s).',
      greatest(1, ceil(extract(epoch from (v_user.chat_muted_until - now())) / 60)::int);
  end if;

  if length(trim(p_content)) = 0 then raise exception 'Message vide.'; end if;
  if length(p_content) > 500 then raise exception 'Message trop long (500 caractères max).'; end if;

  v_lower := lower(p_content);
  foreach v_pat in array v_bad_patterns loop
    if v_lower like '%' || v_pat || '%' then v_is_bad := true; exit; end if;
  end loop;

  if v_is_bad then
    update profiles set chat_warning_count = chat_warning_count + 1
    where id = v_auth_id returning * into v_user;
    if v_user.chat_warning_count >= 3 then
      update profiles set chat_muted_until = now() + interval '10 minutes'
      where id = v_auth_id returning * into v_user;
    end if;
  end if;

  update chat_messages
  set content    = case when v_is_bad then 'Message censuré' else trim(p_content) end,
      is_censored = v_is_bad,
      edited_at  = now()
  where id = p_message_id
  returning * into v_message;

  return jsonb_build_object(
    'message',       to_jsonb(v_message),
    'warning',       v_is_bad,
    'warning_count', v_user.chat_warning_count,
    'muted',         v_user.chat_muted_until is not null
  );
end;
$$;

grant execute on function public.edit_class_message(uuid, text) to authenticated;

-- ── 13. admin_delete_message(p_message_id) — admin peut supprimer n'importe quel message

create or replace function public.admin_delete_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_auth_id uuid := auth.uid();
begin
  if not exists (select 1 from profiles where id = v_auth_id and role = 'admin') then
    raise exception 'Non autorisé.';
  end if;

  update chat_messages set is_deleted = true where id = p_message_id;
  if not found then
    raise exception 'Message introuvable.';
  end if;
end;
$$;

grant execute on function public.admin_delete_message(uuid) to authenticated;

-- ── 14. Modifier submit_account_request pour accepter class_id ───────────────
-- Re-déclarer la fonction avec le nouveau paramètre optionnel

drop function if exists public.submit_account_request(text, text, text, text, text, text);

create or replace function public.submit_account_request(
  p_first_name text,
  p_last_name  text,
  p_username   text,
  p_password   text,
  p_avatar_url text,
  p_device_id  text,
  p_class_id   uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request account_requests%rowtype;
begin
  -- Vérifier si le username est disponible
  if exists (
    select 1 from profiles where username = p_username
    union
    select 1 from account_requests
    where username = p_username and status = 'pending'
  ) then
    raise exception 'Ce nom d''utilisateur est déjà pris ou en attente.';
  end if;

  insert into account_requests (
    first_name, last_name, username, hashed_password,
    avatar_url, device_id, class_id
  ) values (
    p_first_name, p_last_name, p_username,
    crypt(p_password, gen_salt('bf')),
    p_avatar_url, p_device_id, p_class_id
  ) returning * into v_request;

  return to_jsonb(v_request);
end;
$$;

grant execute on function public.submit_account_request(text,text,text,text,text,text,uuid) to anon;
grant execute on function public.submit_account_request(text,text,text,text,text,text,uuid) to authenticated;

commit;

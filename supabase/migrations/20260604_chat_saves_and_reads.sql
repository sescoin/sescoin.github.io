begin;

-- ── Colonnes pour les messages éphémères ─────────────────────────────────────
alter table public.chat_messages
  add column if not exists saved_by   uuid[]      not null default '{}',
  add column if not exists expires_at timestamptz not null default (now() + interval '24 hours');

-- ── Fonction : enregistrer / désénregistrer un message ───────────────────────
create or replace function public.toggle_save_message(p_message_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_saved_by     uuid[];
  v_is_now_saved boolean;
begin
  select saved_by into v_saved_by
  from public.chat_messages
  where id = p_message_id;

  if not found then
    raise exception 'Message introuvable.';
  end if;

  if auth.uid() = any(v_saved_by) then
    -- Désénregistrer
    update public.chat_messages
    set saved_by = array_remove(saved_by, auth.uid())
    where id = p_message_id
    returning saved_by into v_saved_by;
    v_is_now_saved := false;
  else
    -- Enregistrer
    update public.chat_messages
    set saved_by = array_append(saved_by, auth.uid())
    where id = p_message_id
    returning saved_by into v_saved_by;
    v_is_now_saved := true;
  end if;

  return jsonb_build_object('saved', v_is_now_saved);
end;
$$;

grant execute on function public.toggle_save_message(uuid) to authenticated;

-- ── Table des accusés de lecture ─────────────────────────────────────────────
-- Un seul enregistrement par utilisateur : sa dernière position de lecture
create table if not exists public.chat_reads (
  user_id              uuid primary key references public.profiles(id) on delete cascade,
  username             text        not null,
  display_name         text        not null,
  avatar_url           text,
  last_read_message_id uuid        references public.chat_messages(id) on delete set null,
  updated_at           timestamptz not null default now()
);

alter table public.chat_reads enable row level security;

create policy "reads_select_all" on public.chat_reads
  for select using (true);

create policy "reads_upsert_own" on public.chat_reads
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Activer le temps réel pour les lectures
alter publication supabase_realtime add table public.chat_reads;

-- ── Fonction : marquer les messages jusqu'ici comme lus ──────────────────────
create or replace function public.mark_chat_read(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user public.profiles%rowtype;
begin
  select * into v_user from public.profiles where id = auth.uid();
  if v_user.id is null then return; end if;

  insert into public.chat_reads
    (user_id, username, display_name, avatar_url, last_read_message_id, updated_at)
  values
    (auth.uid(), v_user.username, v_user.display_name, v_user.avatar_url, p_message_id, now())
  on conflict (user_id) do update
    set last_read_message_id = p_message_id,
        username             = v_user.username,
        display_name         = v_user.display_name,
        avatar_url           = v_user.avatar_url,
        updated_at           = now();
end;
$$;

grant execute on function public.mark_chat_read(uuid) to authenticated;

commit;

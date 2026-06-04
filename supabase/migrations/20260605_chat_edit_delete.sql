begin;

-- ── Supprimer le système d'enregistrement ────────────────────────────────────
alter table public.chat_messages drop column if exists saved_by;
drop function if exists public.toggle_save_message(uuid);

-- ── Passer l'expiration à 48h ─────────────────────────────────────────────────
alter table public.chat_messages
  alter column expires_at set default (now() + interval '48 hours');

-- Mettre à jour les messages existants qui ont encore l'ancienne valeur 24h
-- (ceux créés avant ce changement dont expires_at < now() + 48h seront ignorés)

-- ── Colonnes modification / suppression ──────────────────────────────────────
alter table public.chat_messages
  add column if not exists is_deleted boolean     not null default false,
  add column if not exists edited_at  timestamptz;

-- ── Fonction : modifier un message ───────────────────────────────────────────
create or replace function public.edit_chat_message(
  p_message_id uuid,
  p_content    text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if length(trim(p_content)) = 0 then
    raise exception 'Message vide.';
  end if;

  if length(p_content) > 500 then
    raise exception 'Message trop long (500 caractères max).';
  end if;

  update public.chat_messages
  set content   = trim(p_content),
      edited_at = now()
  where id       = p_message_id
    and user_id  = auth.uid()
    and not is_deleted;

  if not found then
    raise exception 'Message introuvable ou modification non autorisée.';
  end if;
end;
$$;

grant execute on function public.edit_chat_message(uuid, text) to authenticated;

-- ── Fonction : supprimer un message ──────────────────────────────────────────
create or replace function public.delete_chat_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.chat_messages
  set is_deleted = true
  where id      = p_message_id
    and user_id = auth.uid();

  if not found then
    raise exception 'Message introuvable ou suppression non autorisée.';
  end if;
end;
$$;

grant execute on function public.delete_chat_message(uuid) to authenticated;

commit;

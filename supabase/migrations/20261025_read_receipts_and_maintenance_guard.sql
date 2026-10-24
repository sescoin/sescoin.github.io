-- ============================================================
-- Accusés de lecture par conversation, et maintenance appliquée côté
-- serveur (anciennes versions de l'application)
--
-- 1. chat_reads ne gardait qu'une position de lecture par compte, toutes
--    conversations confondues : lire une classe effaçait la lecture des
--    annonces. Une position par conversation désormais (annonces, ou
--    chaque classe), qui n'avance que vers des messages plus récents.
--
-- 2. Les anciennes versions installées (APK) n'ont pas l'écran de
--    maintenance. Une fonction exécutée avant chaque requête de l'API
--    applique la maintenance côté serveur :
--      * la session de maintenance garde tous les droits ;
--      * maintenance de l'administration : seules les autres sessions
--        administrateur sont concernées ;
--      * application à jour (reconnue à son en-tête X-Client-Info) :
--        lectures permises, son écran de maintenance s'affiche ; toute
--        modification est refusée ;
--      * ancienne version : tout est refusé, y compris la lecture du
--        profil à la connexion, qui échoue avec « Maintenance en cours. ».
--    L'état et les fonctions de maintenance restent toujours accessibles.
--
-- En cas de besoin, pour retirer la vérification :
--   alter role authenticator reset pgrst.db_pre_request;
--   notify pgrst, 'reload config';
--
-- Peut être exécutée plusieurs fois.
-- ============================================================

begin;

-- ─────────────────────────────────────────────────────────────
-- 1. Accusés de lecture
-- ─────────────────────────────────────────────────────────────

-- « global » pour les annonces, sinon l'identifiant de la classe.
alter table public.chat_reads
  add column if not exists chat_key text not null default 'global';

update public.chat_reads r
set chat_key = coalesce(m.class_id::text, 'global')
from public.chat_messages m
where m.id = r.last_read_message_id
  and r.chat_key is distinct from coalesce(m.class_id::text, 'global');

alter table public.chat_reads drop constraint if exists chat_reads_pkey;
alter table public.chat_reads add constraint chat_reads_pkey
  primary key (user_id, chat_key);

create or replace function public.mark_chat_read(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user public.profiles%rowtype;
  v_message public.chat_messages%rowtype;
begin
  select * into v_user from public.profiles where id = auth.uid();
  if v_user.id is null then return; end if;

  select * into v_message from public.chat_messages where id = p_message_id;
  if v_message.id is null then return; end if;

  insert into public.chat_reads (
    user_id, chat_key, username, display_name, avatar_url,
    last_read_message_id, updated_at
  ) values (
    v_user.id, coalesce(v_message.class_id::text, 'global'),
    v_user.username, v_user.display_name, v_user.avatar_url,
    p_message_id, now()
  )
  on conflict (user_id, chat_key) do update
    set last_read_message_id = excluded.last_read_message_id,
        username = excluded.username,
        display_name = excluded.display_name,
        avatar_url = excluded.avatar_url,
        updated_at = now()
  -- La position ne recule jamais vers un message plus ancien.
  where not exists (
    select 1 from public.chat_messages previous
    where previous.id = public.chat_reads.last_read_message_id
      and previous.created_at > v_message.created_at
  );
end;
$$;

grant execute on function public.mark_chat_read(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- 2. Maintenance appliquée avant chaque requête
-- ─────────────────────────────────────────────────────────────
create or replace function public.maintenance_pre_request()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_block boolean := false;
  v_mode text;
  v_path text;
  v_method text;
  v_client text;
  v_session uuid;
begin
  begin
    select mode into v_mode from public.maintenance_state where id = 1;

    if coalesce(v_mode, 'off') <> 'off' then
      v_path := coalesce(current_setting('request.path', true), '');
      v_method := upper(coalesce(current_setting('request.method', true), ''));
      v_client := lower(coalesce(
        current_setting('request.headers', true)::json ->> 'x-client-info',
        ''
      ));
      v_session := nullif(auth.jwt() ->> 'session_id', '')::uuid;

      v_block := not (
        -- État et fonctions de maintenance : toujours accessibles.
        v_path = '/maintenance_state'
        or v_path like '/rpc/maintenance\_%'
        -- La session de maintenance garde tous les droits.
        or (
          v_session is not null
          and exists (
            select 1 from public.maintenance_control
            where id = 1 and session_id = v_session
          )
        )
        -- Maintenance de l'administration : les autres comptes continuent.
        or (
          v_mode = 'admin'
          and not exists (
            select 1 from public.profiles
            where id = auth.uid() and role = 'admin'
          )
        )
        -- Application à jour : lecture seule, son écran de maintenance
        -- s'affiche par-dessus.
        or (v_client like '%sescoin-app/%' and v_method in ('GET', 'HEAD'))
      );
    end if;
  exception when others then
    -- Un imprévu ne doit jamais bloquer toute l'API.
    return;
  end;

  if v_block then
    raise exception 'Maintenance en cours.';
  end if;
end;
$$;

grant execute on function public.maintenance_pre_request() to anon, authenticated;

alter role authenticator set pgrst.db_pre_request = 'public.maintenance_pre_request';

commit;

notify pgrst, 'reload config';

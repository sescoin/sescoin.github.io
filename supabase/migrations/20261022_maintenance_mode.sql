-- ============================================================
-- Maintenance du compte administrateur
--
-- Deux mots de passe de maintenance ouvrent le compte administrateur sans
-- connaitre son vrai mot de passe :
--   * maintenance « admin »   : les autres sessions administrateur tombent
--     sur l'ecran de maintenance ; les eleves utilisent l'app normalement ;
--   * maintenance « globale » : tous les comptes, deja connectes ou non,
--     tombent sur l'ecran de maintenance.
-- La maintenance dure tant que la session qui l'a ouverte existe : se
-- deconnecter la termine pour tout le monde.
--
-- SECURITE
-- Le depot est public : aucun mot de passe de maintenance n'est ecrit ici.
-- Ils se definissent une seule fois dans l'editeur SQL de Supabase, sans
-- enregistrer la requete :
--   select public.maintenance_set_passwords('<mdp admin>', '<mdp global>');
-- Seuls leurs hachages bcrypt sont conserves, dans une table illisible
-- depuis l'application.
--
-- CONNEXION
-- Supabase n'accepte qu'un mot de passe par compte. Pour ouvrir une session
-- administrateur sans le vrai :
--   1. maintenance_request_access verifie le mot de passe de maintenance,
--      met de cote le hachage du vrai mot de passe et pose a sa place un
--      secret aleatoire a usage unique, renvoye a l'application ;
--   2. l'application se connecte avec ce secret ;
--   3. maintenance_activate remet aussitot le vrai mot de passe et
--      enregistre la session de maintenance.
-- Si l'application s'interrompt entre 1 et 3, le vrai mot de passe revient
-- de lui-meme au bout de deux minutes au plus (appel suivant, ou tache
-- planifiee a la minute).
--
-- SECOURS
--   select public.maintenance_force_end();
-- ferme toute maintenance et remet le vrai mot de passe.
-- ============================================================

begin;

-- ─────────────────────────────────────────────────────────────
-- 1. Etat public : lu par toutes les applications, en temps reel
-- ─────────────────────────────────────────────────────────────
create table if not exists public.maintenance_state (
  id smallint primary key default 1 check (id = 1),
  mode text not null default 'off' check (mode in ('off', 'admin', 'global')),
  started_at timestamptz,
  updated_at timestamptz not null default now()
);

insert into public.maintenance_state (id) values (1) on conflict (id) do nothing;

alter table public.maintenance_state enable row level security;

drop policy if exists "maintenance_state_select_all" on public.maintenance_state;
create policy "maintenance_state_select_all" on public.maintenance_state
  for select to anon, authenticated using (true);

revoke insert, update, delete, truncate on public.maintenance_state
  from anon, authenticated;

-- ─────────────────────────────────────────────────────────────
-- 2. Donnees privees : aucun acces depuis l'application
-- ─────────────────────────────────────────────────────────────
create table if not exists public.maintenance_control (
  id smallint primary key default 1 check (id = 1),
  admin_password_hash text,
  global_password_hash text,
  -- Session ouverte en maintenance (auth.sessions.id).
  session_id uuid,
  user_id uuid,
  updated_at timestamptz not null default now()
);

insert into public.maintenance_control (id) values (1) on conflict (id) do nothing;

-- Secret a usage unique en attente : garde le hachage du vrai mot de passe.
-- Un seul par compte, sans quoi un second secret sauvegarderait le premier
-- au lieu du vrai mot de passe.
create table if not exists public.maintenance_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique,
  mode text not null check (mode in ('admin', 'global')),
  password_backup text not null,
  created_at timestamptz not null default now()
);

-- Echecs recents, pour freiner les essais au hasard.
create table if not exists public.maintenance_attempts (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now()
);

alter table public.maintenance_control enable row level security;
alter table public.maintenance_tickets enable row level security;
alter table public.maintenance_attempts enable row level security;

revoke all on public.maintenance_control from anon, authenticated;
revoke all on public.maintenance_tickets from anon, authenticated;
revoke all on public.maintenance_attempts from anon, authenticated;

-- ─────────────────────────────────────────────────────────────
-- 3. Outils internes
-- ─────────────────────────────────────────────────────────────

-- Ferme la maintenance. L'etat public n'est ecrit que s'il change : chaque
-- ecriture reveille toutes les applications connectees.
create or replace function public.maintenance_close()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.maintenance_control
  set session_id = null, user_id = null, updated_at = now()
  where id = 1 and session_id is not null;

  update public.maintenance_state
  set mode = 'off', started_at = null, updated_at = now()
  where id = 1 and mode <> 'off';
end;
$$;

-- Vrai si une reparation s'impose : secret oublie depuis plus de deux
-- minutes, ou session de maintenance disparue (deconnexion sans passer par
-- l'application, session revoquee).
create or replace function public.maintenance_needs_heal()
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_session uuid;
  v_mode text;
begin
  if exists (
    select 1 from public.maintenance_tickets
    where created_at < now() - interval '2 minutes'
  ) then
    return true;
  end if;

  select c.session_id, s.mode into v_session, v_mode
  from public.maintenance_control c, public.maintenance_state s
  where c.id = 1 and s.id = 1;

  if v_session is null then
    return coalesce(v_mode, 'off') <> 'off';
  end if;

  begin
    return not exists (select 1 from auth.sessions where id = v_session);
  exception when others then
    -- Lecture d'auth.sessions refusee : rien a conclure.
    return false;
  end;
end;
$$;

-- A appeler en tenant le verrou de maintenance_control.
create or replace function public.maintenance_heal()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_ticket record;
  v_session uuid;
  v_alive boolean := false;
begin
  for v_ticket in
    delete from public.maintenance_tickets
    where created_at < now() - interval '2 minutes'
    returning user_id, password_backup
  loop
    update auth.users
    set encrypted_password = v_ticket.password_backup
    where id = v_ticket.user_id;
  end loop;

  select session_id into v_session
  from public.maintenance_control where id = 1;

  if v_session is not null then
    begin
      select exists (select 1 from auth.sessions where id = v_session)
      into v_alive;
    exception when others then
      v_alive := true;
    end;
  end if;

  if not v_alive then
    perform public.maintenance_close();
  end if;
end;
$$;

-- Point d'entree de la tache planifiee.
create or replace function public.maintenance_heal_now()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.maintenance_needs_heal() then
    perform 1 from public.maintenance_control where id = 1 for update;
    perform public.maintenance_heal();
  end if;
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- 4. Mots de passe de maintenance (editeur SQL uniquement)
-- ─────────────────────────────────────────────────────────────
create or replace function public.maintenance_set_passwords(
  p_admin_password text,
  p_global_password text
)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if coalesce(length(p_admin_password), 0) < 8
     or coalesce(length(p_global_password), 0) < 8 then
    raise exception 'Chaque mot de passe de maintenance doit contenir au moins 8 caractères.';
  end if;

  if p_admin_password = p_global_password then
    raise exception 'Les deux mots de passe de maintenance doivent être différents.';
  end if;

  update public.maintenance_control
  set admin_password_hash = crypt(p_admin_password, gen_salt('bf', 10)),
      global_password_hash = crypt(p_global_password, gen_salt('bf', 10)),
      updated_at = now()
  where id = 1;

  return 'Mots de passe de maintenance enregistrés.';
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- 5. Connexion de maintenance
-- ─────────────────────────────────────────────────────────────

-- Appelee apres un echec de connexion : renvoie null si le mot de passe
-- n'est pas un mot de passe de maintenance de ce compte administrateur.
create or replace function public.maintenance_request_access(
  p_username text,
  p_password text
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth, extensions
as $$
declare
  v_control public.maintenance_control%rowtype;
  v_admin_id uuid;
  v_email text;
  v_hash text;
  v_mode text;
  v_secret text;
  v_ticket uuid;
  v_previous record;
begin
  if coalesce(p_password, '') = '' or coalesce(trim(p_username), '') = '' then
    return null;
  end if;

  select id into v_admin_id
  from public.profiles
  where lower(username) = lower(trim(p_username)) and role = 'admin';

  if v_admin_id is null then
    return null;
  end if;

  -- Toutes les operations de maintenance passent l'une apres l'autre.
  select * into v_control
  from public.maintenance_control where id = 1 for update;

  if v_control.admin_password_hash is null
     or v_control.global_password_hash is null then
    return null;
  end if;

  if (
    select count(*) from public.maintenance_attempts
    where created_at > now() - interval '15 minutes'
  ) >= 10 then
    raise exception 'Trop de tentatives. Réessayer dans quelques minutes.';
  end if;

  perform public.maintenance_heal();

  if crypt(p_password, v_control.admin_password_hash) = v_control.admin_password_hash then
    v_mode := 'admin';
  elsif crypt(p_password, v_control.global_password_hash) = v_control.global_password_hash then
    v_mode := 'global';
  else
    insert into public.maintenance_attempts default values;
    delete from public.maintenance_attempts
    where created_at < now() - interval '1 day';
    return null;
  end if;

  -- Un secret precedent jamais consomme detient le vrai hachage : il est
  -- remis en place avant d'en poser un nouveau.
  for v_previous in
    delete from public.maintenance_tickets where user_id = v_admin_id
    returning password_backup
  loop
    update auth.users
    set encrypted_password = v_previous.password_backup
    where id = v_admin_id;
  end loop;

  select encrypted_password, email into v_hash, v_email
  from auth.users where id = v_admin_id for update;

  if v_hash is null or v_email is null then
    return null;
  end if;

  v_secret := encode(gen_random_bytes(24), 'hex');

  insert into public.maintenance_tickets (user_id, mode, password_backup)
  values (v_admin_id, v_mode, v_hash)
  returning id into v_ticket;

  update auth.users
  set encrypted_password = crypt(v_secret, gen_salt('bf'))
  where id = v_admin_id;

  return jsonb_build_object(
    'ticket', v_ticket,
    'secret', v_secret,
    'email', v_email,
    'mode', v_mode
  );
end;
$$;

-- Abandon d'une connexion de maintenance : le vrai mot de passe revient.
create or replace function public.maintenance_cancel(p_ticket uuid)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_ticket public.maintenance_tickets%rowtype;
begin
  perform 1 from public.maintenance_control where id = 1 for update;

  delete from public.maintenance_tickets where id = p_ticket
  returning * into v_ticket;

  if v_ticket.id is not null then
    update auth.users
    set encrypted_password = v_ticket.password_backup
    where id = v_ticket.user_id;
  end if;
end;
$$;

-- Appelee juste apres la connexion avec le secret : remet le vrai mot de
-- passe, puis enregistre la session de maintenance.
create or replace function public.maintenance_activate(p_ticket uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_ticket public.maintenance_tickets%rowtype;
  v_session uuid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
begin
  perform 1 from public.maintenance_control where id = 1 for update;

  delete from public.maintenance_tickets where id = p_ticket
  returning * into v_ticket;

  if v_ticket.id is null then
    return jsonb_build_object('ok', false);
  end if;

  -- Le vrai mot de passe revient avant tout le reste. Aucune erreur n'est
  -- levee plus bas : elle annulerait aussi cette restauration.
  update auth.users
  set encrypted_password = v_ticket.password_backup
  where id = v_ticket.user_id;

  if auth.uid() is distinct from v_ticket.user_id or v_session is null then
    return jsonb_build_object('ok', false);
  end if;

  update public.maintenance_control
  set session_id = v_session, user_id = v_ticket.user_id, updated_at = now()
  where id = 1;

  update public.maintenance_state
  set mode = v_ticket.mode, started_at = now(), updated_at = now()
  where id = 1;

  return jsonb_build_object('ok', true, 'mode', v_ticket.mode);
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- 6. Etat vu par l'application qui appelle
-- ─────────────────────────────────────────────────────────────
create or replace function public.maintenance_status()
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_mode text;
  v_started timestamptz;
  v_control_session uuid;
  v_uid uuid := auth.uid();
  v_session uuid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
  v_is_maintenance boolean := false;
  v_blocked boolean := false;
begin
  if public.maintenance_needs_heal() then
    perform 1 from public.maintenance_control where id = 1 for update;
    perform public.maintenance_heal();
  end if;

  select mode, started_at into v_mode, v_started
  from public.maintenance_state where id = 1;

  if coalesce(v_mode, 'off') = 'off' then
    return jsonb_build_object(
      'mode', 'off',
      'blocked', false,
      'is_maintenance_session', false,
      'started_at', null
    );
  end if;

  -- Sans compte connecte, rien n'est bloque : l'ecran de connexion doit
  -- rester accessible, ne serait-ce que pour reprendre la maintenance.
  if v_uid is not null then
    select session_id into v_control_session
    from public.maintenance_control where id = 1;

    v_is_maintenance := v_session is not null
      and v_session = v_control_session;

    v_blocked := not v_is_maintenance and (
      v_mode = 'global'
      or exists (
        select 1 from public.profiles where id = v_uid and role = 'admin'
      )
    );
  end if;

  return jsonb_build_object(
    'mode', v_mode,
    'blocked', v_blocked,
    'is_maintenance_session', v_is_maintenance,
    'started_at', v_started
  );
end;
$$;

-- Deconnexion de la session de maintenance : la maintenance se termine.
-- Sans effet pour toute autre session.
create or replace function public.maintenance_end()
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_session uuid := nullif(auth.jwt() ->> 'session_id', '')::uuid;
begin
  if v_session is null then
    return;
  end if;

  perform 1 from public.maintenance_control where id = 1 for update;

  if exists (
    select 1 from public.maintenance_control
    where id = 1 and session_id = v_session
  ) then
    perform public.maintenance_close();
  end if;
end;
$$;

-- Secours (editeur SQL) : ferme la maintenance et remet le vrai mot de passe
-- si un secret est reste en attente.
create or replace function public.maintenance_force_end()
returns text
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_ticket record;
begin
  perform 1 from public.maintenance_control where id = 1 for update;

  for v_ticket in
    delete from public.maintenance_tickets where true
    returning user_id, password_backup
  loop
    update auth.users
    set encrypted_password = v_ticket.password_backup
    where id = v_ticket.user_id;
  end loop;

  perform public.maintenance_close();
  delete from public.maintenance_attempts where true;

  return 'Maintenance terminée.';
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- 7. Droits
--
-- Les fonctions SECURITY DEFINER s'executent avec les droits de leur
-- proprietaire : les outils internes restent appelables entre elles tout en
-- etant fermes aux comptes de l'application.
-- ─────────────────────────────────────────────────────────────
revoke all on function public.maintenance_close() from public, anon, authenticated;
revoke all on function public.maintenance_needs_heal() from public, anon, authenticated;
revoke all on function public.maintenance_heal() from public, anon, authenticated;
revoke all on function public.maintenance_heal_now() from public, anon, authenticated;
revoke all on function public.maintenance_set_passwords(text, text) from public, anon, authenticated;
revoke all on function public.maintenance_force_end() from public, anon, authenticated;

revoke all on function public.maintenance_request_access(text, text) from public;
revoke all on function public.maintenance_cancel(uuid) from public;
revoke all on function public.maintenance_activate(uuid) from public, anon;
revoke all on function public.maintenance_status() from public;
revoke all on function public.maintenance_end() from public, anon;

grant execute on function public.maintenance_request_access(text, text) to anon, authenticated;
grant execute on function public.maintenance_cancel(uuid) to anon, authenticated;
grant execute on function public.maintenance_activate(uuid) to authenticated;
grant execute on function public.maintenance_status() to anon, authenticated;
grant execute on function public.maintenance_end() to authenticated;

-- ─────────────────────────────────────────────────────────────
-- 8. Temps reel
-- ─────────────────────────────────────────────────────────────
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public' and tablename = 'maintenance_state'
  ) then
    alter publication supabase_realtime add table public.maintenance_state;
  end if;
end
$$;

commit;

-- ─────────────────────────────────────────────────────────────
-- 9. Planification (a EXECUTER HORS TRANSACTION)
--
-- Filet de securite : remet le vrai mot de passe si une connexion de
-- maintenance a ete interrompue, et ferme une maintenance dont la session a
-- disparu, meme si aucune application n'est ouverte.
-- ─────────────────────────────────────────────────────────────
select cron.unschedule('maintenance-heal')
where exists (
  select 1 from cron.job where jobname = 'maintenance-heal'
);

select cron.schedule(
  'maintenance-heal',
  '* * * * *',
  $$select public.maintenance_heal_now()$$
);

-- ============================================================
-- Lever une suspension modifie la sanction, au lieu d'en creer une seconde
--
-- Le journal accumulait deux entrees pour un meme episode : la suspension,
-- puis sa levee. Une sanction porte desormais sa propre date de fin.
-- ============================================================

alter table public.sanctions
  add column if not exists lifted_at timestamptz;

-- ─────────────────────────────────────────────────────────────
-- Marquage automatique
--
-- Un declencheur sur profiles plutot qu'un ajout dans chaque fonction : la
-- levee peut venir de l'expiration planifiee comme d'une decision manuelle,
-- et les deux passent forcement par ce champ.
-- ─────────────────────────────────────────────────────────────
create or replace function public.mark_ban_lifted()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.is_banned and not new.is_banned then
    update public.sanctions
    set lifted_at = now()
    where user_id = new.id
      and kind = 'ban'
      and lifted_at is null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_mark_ban_lifted on public.profiles;
create trigger trg_mark_ban_lifted
  after update of is_banned on public.profiles
  for each row execute function public.mark_ban_lifted();

-- ─────────────────────────────────────────────────────────────
-- La levee planifiee n'ajoute plus d'entree
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
    -- Le declencheur trg_mark_ban_lifted date la sanction correspondante.
    update public.profiles
    set is_banned = false, ban_reason = null, banned_until = null
    where id = v_row.id;

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
-- La levee manuelle laissait banned_until en place
--
-- Sans ce nettoyage, un compte reactive garde une echeance de suspension
-- perimee, que l'interface affiche encore.
-- ─────────────────────────────────────────────────────────────
create or replace function public.admin_unban_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin public.profiles%rowtype;
begin
  select * into v_admin from public.profiles where id = auth.uid();
  if v_admin.id is null or v_admin.role <> 'admin' then
    raise exception 'Action réservée à l''administrateur.';
  end if;

  update public.profiles
  set is_banned = false,
      ban_reason = null,
      banned_until = null,
      updated_at = now()
  where id = p_user_id;

  if not found then
    raise exception 'Compte introuvable.';
  end if;

  insert into public.notifications (user_id, type, title, body, data, is_read)
  values (
    p_user_id, 'system',
    'Compte réactivé',
    'Ce compte a été réactivé par l''administrateur.',
    null,
    false
  );
end;
$$;

grant execute on function public.admin_unban_user(uuid) to authenticated;

update public.profiles
set banned_until = null
where not is_banned and banned_until is not null;

-- ─────────────────────────────────────────────────────────────
-- Reprise de l'historique : les levees deja enregistrees comme entrees
-- distinctes sont reportees sur la suspension qu'elles closent, puis
-- supprimees.
--
-- La levee retenue est la premiere qui suit la suspension : un compte
-- sanctionne plusieurs fois a autant de paires a reconstituer.
-- ─────────────────────────────────────────────────────────────
update public.sanctions b
set lifted_at = (
  select min(u.created_at)
  from public.sanctions u
  where u.kind = 'unban'
    and u.user_id = b.user_id
    and u.created_at > b.created_at
)
where b.kind = 'ban' and b.lifted_at is null;

delete from public.sanctions where kind = 'unban';

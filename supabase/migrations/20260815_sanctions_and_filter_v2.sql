-- ============================================================
-- Sanctions graduees, protection des preuves et filtre affine
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. Filtre : normalisation plus stricte
--
-- Ajouts par rapport a la version precedente :
--   * separateurs Unicode (espaces fins, insecables) ramenes a l'espace ;
--   * chiffres isoles au milieu d'un mot supprimes (« c4o5n6n7a8r9d ») ;
--   * substitutions leet elargies (vv -> w, ph -> f, cks/x -> ks).
-- ─────────────────────────────────────────────────────────────
create or replace function public.normalize_for_filter(p_text text)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  v text;
begin
  if p_text is null then
    return '';
  end if;

  v := lower(p_text);

  -- Espaces exotiques ramenes a l'espace ordinaire avant tout traitement.
  v := regexp_replace(v, E'[\u00A0\u2000-\u200A\u202F\u205F\u3000]', ' ', 'g');
  -- Caracteres invisibles purement decoratifs : supprimes, et non remplaces
  -- par un espace, pour que le mot se recolle.
  v := regexp_replace(v, E'[\u00AD\u200B-\u200F\u2060\uFEFF]', '', 'g');
  v := translate(
    v,
    'àáâãäåāçćèéêëēìíîïīñńòóôõöøōùúûüūýÿ',
    'aaaaaaacceeeeeiiiiinnooooooouuuuuyy'
  );
  v := replace(v, 'œ', 'oe');
  v := replace(v, 'æ', 'ae');

  -- Digrammes maquilles.
  v := replace(v, 'vv', 'w');
  v := replace(v, 'ph', 'f');

  -- Substitutions « leet ».
  v := translate(v, '0134578@$!|+', 'oieastbasilt');

  -- Chiffres restants (2, 6, 9 : les autres viennent d'etre convertis en
  -- lettres) encadres de lettres : on les retire plutot que d'en faire un
  -- separateur, sinon « c2o6n9n2a6r9d » resterait decoupe.
  --
  -- Deux passes : les correspondances se chevauchent, la premiere consomme
  -- la lettre qui amorcerait la suivante.
  v := regexp_replace(v, '([a-z])[0-9]+([a-z])', '\1\2', 'g');
  v := regexp_replace(v, '([a-z])[0-9]+([a-z])', '\1\2', 'g');

  v := regexp_replace(v, '[^a-z]+', ' ', 'g');
  v := regexp_replace(v, '(.)\1{2,}', '\1\1', 'g');

  return trim(regexp_replace(v, '\s+', ' ', 'g'));
end;
$$;

grant execute on function public.normalize_for_filter(text) to authenticated;

-- Motifs elargis : le corps de la fonction est reecrit en entier pour rester
-- lisible, plutot que d'empiler les listes.
create or replace function public.contains_forbidden_words(p_text text)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  v_tight text[] := array[
    'connard', 'connasse', 'conard', 'conasse', 'ducon',
    'salope', 'salaud', 'salopard', 'pute', 'putain', 'putin', 'putes',
    'fdp', 'filsdepute', 'filledepute', 'ntm', 'nikta', 'niktamere',
    'encule', 'enculer', 'enculee', 'encules', 'niquetamere', 'niquetamer',
    'batard', 'batarde', 'batards',
    'trouduc', 'trouducul', 'tagueule', 'fermetagueule', 'ftg',
    'vatefaire', 'vtff', 'vaffanculo', 'ferlacon',
    'pedale', 'tapette', 'negro', 'negre', 'bougnoule', 'youpin',
    'salerace', 'salepd', 'saletruc', 'salechien',
    'grossemerde', 'petasse', 'poufiasse', 'pouffiasse',
    'branleur', 'branlette', 'branler', 'chienne', 'chiennasse',
    'niquer', 'niquee', 'enfoire', 'enfoiree', 'foutretagueule',
    'crevure', 'ordure', 'raclure', 'sousmerde', 'grossepute',
    'suceur', 'suceuse', 'gouine', 'travelo', 'mongolien'
  ];

  v_words text[] := array[
    'con', 'cons', 'conne', 'connes', 'pd', 'pede', 'pedes', 'nique',
    'merde', 'merdeux', 'merdique', 'chier', 'chiotte', 'chiottes', 'chiant',
    'abruti', 'abrutie', 'abrutis', 'imbecile', 'imbeciles',
    'cretin', 'cretine', 'cretins', 'debile', 'debiles',
    'attarde', 'attardee', 'attardes', 'mongol', 'mongole',
    'bouffon', 'bouffonne', 'clochard', 'clocharde',
    'porc', 'truie', 'thon', 'boloss', 'bolos', 'noob', 'cassos',
    'raciste', 'nazi', 'hitler', 'facho',
    'moche', 'laid', 'laide', 'gras', 'grosse', 'obese',
    'nul', 'nulle', 'nuls', 'inutile', 'parasite'
  ];

  v_phrases text[] := array[
    -- Menaces physiques
    'je vais te (tuer|frapper|casser|defoncer|exploser|massacrer|eclater|demonter|peter|buter|refaire|cogner|etrangler|saigner)',
    'je vais vous (tuer|frapper|casser|defoncer|massacrer)',
    'on va te (tuer|frapper|casser|defoncer|exploser|retrouver|attendre|coincer)',
    'on va lui (casser|defoncer|refaire|peter)',
    'tu vas (mourir|crever|morfler|douiller|souffrir|le regretter|te faire|deguster|prendre cher)',
    'je te (defonce|demonte|casse|explose|bute|tue|frappe|cogne|saigne)',
    'tu es (mort|morte|fini|finie|foutu|foutue)',
    'ta (derniere heure|gueule|mere|race)',
    'je vais te retrouver', 'je te retrouve', 'tu vas voir ta gueule',
    'je vais m occuper de ton cas',
    -- Intimidation, y compris sans insulte
    'je sais ou (tu |t )?(h)?abite',
    'je connais ton adresse', 'je connais ton quartier',
    'je sais ou tu (vis|dors|traines|vas)',
    'je connais ta (famille|mere|soeur|adresse|maison)',
    'je sais dans quelle (classe|ecole|rue)',
    'fais (bien )?(gaffe|attention) a toi',
    'tu (vas |va )?(voir|verras) (ce qui|ce que|demain)',
    'attends (moi|toi) (dehors|a la sortie|dans la rue|au portail)',
    'on se (voit|retrouve) (dehors|a la sortie|apres)',
    'rendez vous (dehors|a la sortie|au portail)',
    'tu sortiras pas', 'tu vas pas sortir', 'tu vas payer',
    'tu ne perds rien pour attendre', 'ca va mal se passer',
    'tu vas comprendre ta douleur', 'prepare toi',
    'je vais m occuper de toi', 'tu regretteras',
    -- Incitation au suicide et a l'automutilation
    'tue toi', 'tuez vous', 'suicide toi', 'suicidez vous',
    'va (te )?(pendre|mourir|crever|noyer)', 'allez (mourir|crever)',
    'pends toi', 'jette toi', 'saute du', 'coupe toi les veines',
    'personne (ne )?t aime', 'tout le monde te deteste',
    'le monde (serait|irait) mieux sans toi', 'tu sers a rien',
    'disparais de (ma vie|la terre|ce monde)', 'creve',
    'tu devrais mourir', 'tu ferais mieux de mourir',
    -- Haine et discrimination
    'mort aux', 'a mort les',
    'sale (juif|arabe|noir|blanc|chinois|musulman|chretien|gitan|rom)',
    'retourne (dans|chez|a) (ton|ta|ton pays)',
    'rentre dans ton pays', 'on veut pas de (toi|vous) ici',
    'tous les (juifs|arabes|noirs|musulmans)',
    -- Harcelement sexuel
    'envoie (moi )?(des |une )?(nude|photo de toi)',
    'je vais te violer', 'je vais t agresser',
    'suce', 'sucer ma', 'montre tes'
  ];

  v_norm text;
  v_tightened text;
  v_pat text;
begin
  v_norm := public.normalize_for_filter(p_text);
  if v_norm = '' then
    return false;
  end if;

  v_tightened := replace(v_norm, ' ', '');

  foreach v_pat in array v_tight loop
    if position(replace(v_pat, ' ', '') in v_tightened) > 0 then
      return true;
    end if;
  end loop;

  foreach v_pat in array v_words loop
    if position(' ' || v_pat || ' ' in ' ' || v_norm || ' ') > 0 then
      return true;
    end if;
  end loop;

  foreach v_pat in array v_phrases loop
    if v_norm ~ v_pat then
      return true;
    end if;
  end loop;

  return false;
end;
$$;

grant execute on function public.contains_forbidden_words(text) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- 2. Journal des sanctions
--
-- Trace unique de toutes les mesures, automatiques comme manuelles. Sert
-- l'historique consultable et le calcul de recidive.
-- ─────────────────────────────────────────────────────────────
create table if not exists public.sanctions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  username text not null,
  kind text not null check (kind in ('mute', 'ban', 'unban', 'warning')),
  reason text,
  -- Nul pour une mesure definitive ou instantanee.
  until timestamptz,
  -- Nul lorsque la sanction est automatique.
  issued_by uuid references public.profiles(id) on delete set null,
  issued_by_username text,
  automatic boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_sanctions_user on public.sanctions(user_id);
create index if not exists idx_sanctions_created on public.sanctions(created_at desc);

alter table public.sanctions enable row level security;

drop policy if exists "sanctions_select_admin" on public.sanctions;
create policy "sanctions_select_admin" on public.sanctions
  for select to authenticated
  using (public.current_profile_is_admin());

-- ─────────────────────────────────────────────────────────────
-- 3. Bannissement temporaire
--
-- is_banned reste la source de verite consultee partout ; banned_until
-- indique seulement quand la mesure doit etre levee.
-- ─────────────────────────────────────────────────────────────
alter table public.profiles
  add column if not exists banned_until timestamptz;

create or replace function public.admin_ban_user_temp(
  p_user_id uuid,
  p_reason text,
  p_minutes integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin public.profiles%rowtype;
  v_target public.profiles%rowtype;
  v_until timestamptz;
begin
  select * into v_admin from public.profiles where id = auth.uid();
  if v_admin.id is null or v_admin.role <> 'admin' then
    raise exception 'Action réservée à l''administrateur.';
  end if;

  select * into v_target from public.profiles where id = p_user_id;
  if v_target.id is null then
    raise exception 'Compte introuvable.';
  end if;
  if v_target.role = 'admin' then
    raise exception 'Un administrateur ne peut pas être banni.';
  end if;

  -- p_minutes nul ou negatif : bannissement sans terme.
  v_until := case
    when p_minutes is null or p_minutes <= 0 then null
    else now() + make_interval(mins => p_minutes)
  end;

  update public.profiles
  set is_banned = true,
      ban_reason = nullif(trim(coalesce(p_reason, '')), ''),
      banned_until = v_until
  where id = p_user_id;

  insert into public.sanctions (
    user_id, username, kind, reason, until,
    issued_by, issued_by_username, automatic
  ) values (
    p_user_id, v_target.username, 'ban',
    nullif(trim(coalesce(p_reason, '')), ''), v_until,
    v_admin.id, v_admin.username, false
  );

  insert into public.notifications (user_id, type, title, body)
  values (
    p_user_id, 'admin', 'Compte suspendu',
    case
      when v_until is null then 'Votre compte a été suspendu.'
      else 'Votre compte est suspendu jusqu''au ' ||
           to_char(v_until at time zone 'Europe/Paris', 'DD/MM/YYYY à HH24:MI') || '.'
    end
  );
end;
$$;

revoke all on function public.admin_ban_user_temp(uuid, text, integer) from public, anon;
grant execute on function public.admin_ban_user_temp(uuid, text, integer) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- 4. Levee automatique des mesures arrivees a terme
--
-- Planifiee a la minute : une sanction qui s'eternise au-dela de son terme
-- serait percue comme arbitraire.
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
    update public.profiles
    set is_banned = false, ban_reason = null, banned_until = null
    where id = v_row.id;

    insert into public.sanctions (
      user_id, username, kind, reason, automatic
    ) values (
      v_row.id, v_row.username, 'unban', 'Fin de la suspension', true
    );

    insert into public.notifications (user_id, type, title, body)
    values (
      v_row.id, 'admin', 'Suspension levée',
      'Votre compte est de nouveau actif.'
    );

    v_released := v_released + 1;
  end loop;

  -- Mises en sourdine echues : le compteur d'avertissements repart a zero.
  update public.profiles
  set chat_muted_until = null, chat_warning_count = 0
  where chat_muted_until is not null and chat_muted_until <= now();

  return v_released;
end;
$$;

revoke all on function public.release_expired_sanctions() from public, anon;

-- ─────────────────────────────────────────────────────────────
-- 5. Sourdine automatique : neuf censures en vingt-quatre heures
--
-- Le compteur d'avertissements existant declenche une sourdine de dix
-- minutes tous les trois messages. On ajoute un palier au-dessus : neuf
-- messages censures sur une journee valent vingt-quatre heures de silence.
-- ─────────────────────────────────────────────────────────────
create or replace function public.enforce_chat_filter()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_count integer;
  v_censored_24h integer;
  v_username text;
begin
  if coalesce(new.is_censored, false) then
    return new;
  end if;

  if new.content is null or not public.contains_forbidden_words(new.content) then
    return new;
  end if;

  new.content := 'Message censuré';
  new.is_censored := true;

  if new.user_id is null then
    return new;
  end if;

  update public.profiles
  set chat_warning_count = coalesce(chat_warning_count, 0) + 1
  where id = new.user_id
  returning chat_warning_count, username into v_count, v_username;

  -- Messages deja censures sur les dernieres vingt-quatre heures, celui-ci
  -- compris (il n'est pas encore insere, d'où le + 1).
  select count(*) + 1 into v_censored_24h
  from public.chat_messages
  where user_id = new.user_id
    and is_censored
    and created_at > now() - interval '24 hours';

  if v_censored_24h >= 9 then
    update public.profiles
    set chat_muted_until = now() + interval '24 hours'
    where id = new.user_id;

    insert into public.sanctions (
      user_id, username, kind, reason, until, automatic
    ) values (
      new.user_id, v_username, 'mute',
      v_censored_24h || ' messages censurés en 24 h',
      now() + interval '24 hours', true
    );

    insert into public.notifications (user_id, type, title, body)
    values (
      new.user_id, 'admin', 'Chat suspendu 24 h',
      'Trop de messages inappropriés : le chat vous est fermé pour 24 heures.'
    );
  elsif coalesce(v_count, 0) >= 3 then
    update public.profiles
    set chat_muted_until = now() + interval '10 minutes'
    where id = new.user_id;
  end if;

  return new;
end;
$$;

-- ─────────────────────────────────────────────────────────────
-- 6. Anti-rafale
--
-- Cinq messages en dix secondes relevent du noyage de conversation, pas de
-- l'echange. Le compte est mis en sourdine cinq minutes.
-- ─────────────────────────────────────────────────────────────
create or replace function public.enforce_chat_flood()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_recent integer;
begin
  if new.user_id is null then
    return new;
  end if;

  select count(*) into v_recent
  from public.chat_messages
  where user_id = new.user_id
    and created_at > now() - interval '10 seconds';

  if v_recent >= 5 then
    update public.profiles
    set chat_muted_until = greatest(
      coalesce(chat_muted_until, now()),
      now() + interval '5 minutes'
    )
    where id = new.user_id;

    raise exception 'Trop de messages d''affilée. Patientez quelques minutes.';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_chat_flood on public.chat_messages;
create trigger trg_enforce_chat_flood
  before insert on public.chat_messages
  for each row execute function public.enforce_chat_flood();

-- ─────────────────────────────────────────────────────────────
-- 7. Signalements : recidive, sanction automatique, notification
-- ─────────────────────────────────────────────────────────────

-- Nombre de signalements deja retenus contre un compte : un premier ecart et
-- un cinquieme ne se traitent pas de la meme facon.
create or replace function public.confirmed_reports_count(p_user_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(distinct message_id)::int
  from public.reports
  where reported_id = p_user_id and status = 'reviewed';
$$;

grant execute on function public.confirmed_reports_count(uuid) to authenticated;

-- A la cloture d'un signalement : on previent celui qui l'a remonte, et on
-- met le compte en sourdine s'il recidive.
create or replace function public.on_report_reviewed()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_confirmed integer;
  v_username text;
begin
  if old.status = new.status then
    return new;
  end if;

  insert into public.notifications (user_id, type, title, body)
  values (
    new.reporter_id, 'admin', 'Signalement traité',
    case
      when new.status = 'reviewed'
        then 'Votre signalement a été retenu. Merci de votre vigilance.'
      else 'Votre signalement a été examiné, aucune suite n''a été donnée.'
    end
  );

  if new.status = 'reviewed' then
    v_confirmed := public.confirmed_reports_count(new.reported_id);

    -- Troisieme signalement retenu : sanction intermediaire, moins brutale
    -- qu'un bannissement.
    if v_confirmed >= 3 then
      select username into v_username
      from public.profiles where id = new.reported_id;

      update public.profiles
      set chat_muted_until = greatest(
        coalesce(chat_muted_until, now()),
        now() + interval '24 hours'
      )
      where id = new.reported_id;

      insert into public.sanctions (
        user_id, username, kind, reason, until, automatic
      ) values (
        new.reported_id, v_username, 'mute',
        v_confirmed || ' signalements retenus',
        now() + interval '24 hours', true
      );
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_on_report_reviewed on public.reports;
create trigger trg_on_report_reviewed
  after update of status on public.reports
  for each row execute function public.on_report_reviewed();

-- ─────────────────────────────────────────────────────────────
-- 8. Preuves : ne pas purger les messages signales
--
-- La retention efface les messages de classe au bout de 24 h. Un message
-- signale doit survivre a la purge, sans quoi la transcription exportee
-- depuis un signalement arrive vide.
-- ─────────────────────────────────────────────────────────────
create or replace function public.purge_expired_chat_messages()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deleted integer;
begin
  with removed as (
    delete from public.chat_messages m
    where (
        (m.class_id is not null and m.created_at < now() - interval '24 hours')
        or (m.class_id is null and m.created_at < public.current_school_year_start())
      )
      and not exists (
        select 1 from public.reports r where r.message_id = m.id
      )
    returning 1
  )
  select count(*) into v_deleted from removed;

  return v_deleted;
end;
$$;

revoke all on function public.purge_expired_chat_messages() from public, anon;

-- ─────────────────────────────────────────────────────────────
-- 9. Planification (a EXECUTER HORS TRANSACTION)
-- ─────────────────────────────────────────────────────────────

select cron.unschedule('release-expired-sanctions')
where exists (
  select 1 from cron.job where jobname = 'release-expired-sanctions'
);

select cron.schedule(
  'release-expired-sanctions',
  '* * * * *',
  $$select public.release_expired_sanctions()$$
);

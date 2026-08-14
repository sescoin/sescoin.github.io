-- ============================================================
-- Filtre partage, citations de profil et signalements
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- 1. Filtre de langage, centralise
--
-- La liste vivait jusqu'ici en variable locale dans send_chat_message, donc
-- inutilisable ailleurs. Elle devient une fonction : citations, descriptions
-- de transfert et motifs de pret passent desormais par le meme controle, et
-- une seule liste reste a maintenir.
-- ─────────────────────────────────────────────────────────────

create or replace function public.contains_forbidden_words(p_text text)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  v_patterns text[] := array[
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
  v_lower text;
  v_pat text;
begin
  if p_text is null then
    return false;
  end if;
  -- Les espaces encadrants aident les motifs delimites comme ' pd '.
  v_lower := ' ' || lower(p_text) || ' ';
  foreach v_pat in array v_patterns loop
    if v_lower like '%' || v_pat || '%' then
      return true;
    end if;
  end loop;
  return false;
end;
$$;

grant execute on function public.contains_forbidden_words(text) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- 2. Citation de profil
-- ─────────────────────────────────────────────────────────────

alter table public.profiles
  add column if not exists quote text;

-- Redefinit sa propre citation. Passe par une RPC plutot que par un update
-- direct : la longueur, les caracteres invisibles et le langage doivent etre
-- verifies cote serveur, un client pouvant toujours ecrire en base.
create or replace function public.set_profile_quote(p_quote text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_clean text;
begin
  if auth.uid() is null then
    raise exception 'Non authentifie.';
  end if;

  if exists (select 1 from public.profiles
             where id = auth.uid() and is_banned) then
    raise exception 'Compte suspendu.';
  end if;

  -- Citation vide = suppression.
  if p_quote is null or length(trim(p_quote)) = 0 then
    update public.profiles set quote = null where id = auth.uid();
    return;
  end if;

  v_clean := trim(p_quote);

  -- Caracteres de controle, espaces de largeur nulle et marques
  -- directionnelles : ils permettraient de simuler une citation vide ou
  -- de casser la mise en page. Ecrits en echappement Unicode et jamais
  -- en clair : un U+0000 ou un U+2028 pose litteralement dans le source
  -- termine la chaine et casse le script.
  v_clean := regexp_replace(v_clean, '[[:cntrl:]]', '', 'g');
  v_clean := regexp_replace(
    v_clean,
    E'[\u00AD\u200B-\u200F\u2028\u2029\u202A-\u202E\u2060\uFEFF]',
    '',
    'g'
  );
  -- Espaces multiples ramenes a un seul.
  v_clean := regexp_replace(v_clean, '\s+', ' ', 'g');
  v_clean := trim(v_clean);

  if length(v_clean) = 0 then
    raise exception 'La citation ne peut pas etre vide.';
  end if;

  if length(v_clean) > 100 then
    raise exception 'La citation ne doit pas depasser 100 caracteres.';
  end if;

  if public.contains_forbidden_words(v_clean) then
    raise exception 'Cette citation contient des termes inapproprie.';
  end if;

  update public.profiles set quote = v_clean where id = auth.uid();
end;
$$;

revoke all on function public.set_profile_quote(text) from public, anon;
grant execute on function public.set_profile_quote(text) to authenticated;

-- Suppression par l'administrateur.
create or replace function public.admin_clear_quote(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.current_profile_is_admin() then
    raise exception 'Action reservee a l''administrateur.';
  end if;
  update public.profiles set quote = null where id = p_user_id;
end;
$$;

revoke all on function public.admin_clear_quote(uuid) from public, anon;
grant execute on function public.admin_clear_quote(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- 3. Signalements
-- ─────────────────────────────────────────────────────────────

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  message_id uuid references public.chat_messages(id) on delete set null,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reporter_username text not null,
  reported_id uuid not null references public.profiles(id) on delete cascade,
  reported_username text not null,
  -- Copie du message : il peut etre supprime ou modifie avant que
  -- l'administrateur ne traite le signalement.
  message_content text not null,
  class_id uuid references public.classes(id) on delete set null,
  status text not null default 'pending'
    check (status in ('pending', 'reviewed', 'dismissed')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

create index if not exists idx_reports_status on public.reports(status);
create index if not exists idx_reports_reported on public.reports(reported_id);

-- Un meme utilisateur ne signale qu'une fois le meme message.
create unique index if not exists idx_reports_unique_reporter_message
  on public.reports(reporter_id, message_id)
  where message_id is not null;

alter table public.reports enable row level security;

-- Seul l'administrateur consulte les signalements : un eleve ne doit pas
-- savoir qui a signale qui.
--
-- PostgreSQL n'accepte pas « create policy if not exists » : sans le drop
-- prealable, rejouer ce script echoue avec « policy already exists ».
drop policy if exists "reports_select_admin" on public.reports;
create policy "reports_select_admin" on public.reports
  for select to authenticated
  using (public.current_profile_is_admin());

drop policy if exists "reports_update_admin" on public.reports;
create policy "reports_update_admin" on public.reports
  for update to authenticated
  using (public.current_profile_is_admin());

drop policy if exists "reports_delete_admin" on public.reports;
create policy "reports_delete_admin" on public.reports
  for delete to authenticated
  using (public.current_profile_is_admin());

create or replace function public.report_chat_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_msg public.chat_messages%rowtype;
  v_me public.profiles%rowtype;
begin
  select * into v_me from public.profiles where id = auth.uid();
  if v_me.id is null then
    raise exception 'Non authentifie.';
  end if;

  select * into v_msg from public.chat_messages where id = p_message_id;
  if v_msg.id is null then
    raise exception 'Message introuvable.';
  end if;

  if v_msg.user_id = auth.uid() then
    raise exception 'Impossible de signaler son propre message.';
  end if;

  if exists (
    select 1 from public.reports
    where reporter_id = auth.uid() and message_id = p_message_id
  ) then
    raise exception 'Ce message a deja ete signale.';
  end if;

  insert into public.reports (
    message_id, reporter_id, reporter_username,
    reported_id, reported_username, message_content, class_id
  ) values (
    p_message_id, auth.uid(), v_me.username,
    v_msg.user_id, v_msg.username, v_msg.content, v_msg.class_id
  );

  -- L'administrateur est prevenu immediatement.
  insert into public.notifications (user_id, type, title, body)
  select p.id, 'admin', 'Nouveau signalement',
         'Message de @' || v_msg.username || ' signale par @' || v_me.username
  from public.profiles p
  where p.role = 'admin';
end;
$$;

revoke all on function public.report_chat_message(uuid) from public, anon;
grant execute on function public.report_chat_message(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- 4. Filtrage des descriptions de transfert et des motifs de pret
--
-- Passer par des declencheurs plutot que par chaque RPC : toutes les voies
-- d'ecriture sont couvertes d'un coup, y compris celles ajoutees plus tard.
-- ─────────────────────────────────────────────────────────────

create or replace function public.censor_transaction_description()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.description is not null
     and public.contains_forbidden_words(new.description) then
    new.description := 'Description censuree';
  end if;
  return new;
end;
$$;

create or replace function public.censor_loan_note()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.note is not null
     and public.contains_forbidden_words(new.note) then
    new.note := 'Motif censure';
  end if;
  return new;
end;
$$;

create or replace function public.censor_chat_loan_note()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.loan_note is not null
     and public.contains_forbidden_words(new.loan_note) then
    new.loan_note := 'Motif censure';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_censor_transaction_description on public.transactions;
create trigger trg_censor_transaction_description
  before insert or update of description on public.transactions
  for each row execute function public.censor_transaction_description();

drop trigger if exists trg_censor_loan_note on public.loans;
create trigger trg_censor_loan_note
  before insert or update of note on public.loans
  for each row execute function public.censor_loan_note();

drop trigger if exists trg_censor_chat_loan_note on public.chat_messages;
create trigger trg_censor_chat_loan_note
  before insert or update of loan_note on public.chat_messages
  for each row execute function public.censor_chat_loan_note();

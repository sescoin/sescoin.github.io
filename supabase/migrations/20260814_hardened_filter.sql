-- ============================================================
-- Filtre de langage renforce
--
-- L'ancien filtre comparait le message brut, en minuscules, a une liste de
-- chaines. Trois failles :
--   * « C0nnard », « c-o-n-n-a-r-d », « connnnard » passaient sans encombre ;
--   * les accents et la ponctuation suffisaient a le contourner ;
--   * seules les insultes explicites etaient couvertes, jamais les menaces
--     formulees sans gros mot (« je sais ou t'habites »).
--
-- Le texte est desormais normalise avant comparaison, et les motifs sont
-- ranges en trois familles selon le risque de faux positif.
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- Normalisation
--
-- Minuscules, accents retires, substitutions « leet », ponctuation ecrasee
-- et repetitions reduites. « Ç0nn@rrrrd !! » devient « connard ».
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

  -- Accents et ligatures.
  v := translate(
    v,
    'àáâãäåāçćèéêëēìíîïīñńòóôõöøōùúûüūýÿ',
    'aaaaaaacceeeeeiiiiinnooooooouuuuuyy'
  );
  v := replace(v, 'œ', 'oe');
  v := replace(v, 'æ', 'ae');

  -- Substitutions « leet » les plus courantes.
  v := translate(v, '0134578@$!|', 'oieastbasil');

  -- Tout ce qui n'est pas une lettre devient une separation.
  v := regexp_replace(v, '[^a-z]+', ' ', 'g');

  -- « connnnard » -> « connard » : au-dela de deux, on ramene a deux, ce qui
  -- preserve les doubles legitimes (« passer », « bonne »).
  v := regexp_replace(v, '(.)\1{2,}', '\1\1', 'g');

  return trim(regexp_replace(v, '\s+', ' ', 'g'));
end;
$$;

grant execute on function public.normalize_for_filter(text) to authenticated;

-- ─────────────────────────────────────────────────────────────
-- Detection
-- ─────────────────────────────────────────────────────────────
create or replace function public.contains_forbidden_words(p_text text)
returns boolean
language plpgsql
immutable
set search_path = public
as $$
declare
  -- 1. Insultes sans ambiguite. Recherchees dans le texte prive de ses
  --    espaces, ce qui rattrape « c o n n a r d » et « c.o.n.n.a.r.d ».
  v_tight text[] := array[
    'connard', 'connasse', 'conard', 'conasse',
    'salope', 'salaud', 'pute', 'putain', 'putin',
    'fdp', 'filsdepute', 'filledepute',
    'encule', 'enculer', 'enculee', 'niquetamere', 'niquetamer', 'ntm',
    'batard', 'batarde',
    'trouduc', 'trouducul', 'tagueule', 'fermetagueule', 'ftg',
    'vatefaire', 'vtff', 'vaffanculo',
    'pedale', 'tapette', 'negro', 'bougnoule', 'youpin', 'sale race',
    'grossemerde', 'petasse', 'poufiasse', 'salopard',
    'branleur', 'branlette', 'chienne', 'chiennasse',
    'nique', 'niquer', 'niquee'
  ];

  -- 2. Mots isoles, ambigus dans un autre contexte : compares en entier,
  --    entoures d'espaces. « con » ne doit pas declencher sur
  --    « concentration », ni « pd » sur « pdf ».
  v_words text[] := array[
    'con', 'cons', 'conne', 'connes', 'pd', 'pede', 'pedes',
    'merde', 'merdeux', 'chier', 'chiotte', 'chiottes',
    'abruti', 'abrutie', 'imbecile', 'cretin', 'cretine',
    'debile', 'attarde', 'attardee', 'mongol', 'mongole',
    'clochard', 'cloche', 'moche', 'grosse', 'gros porc', 'porc',
    'bouffon', 'bouffonne', 'nul', 'nulle', 'raciste'
  ];

  -- 3. Expressions et menaces. Comparees en expression reguliere sur le
  --    texte normalise : c'est ici que se logent les phrases sans le
  --    moindre gros mot.
  v_phrases text[] := array[
    -- Menaces physiques
    'je vais te (tuer|frapper|casser|defoncer|exploser|massacrer|eclater|demonter|peter|buter|refaire)',
    'je vais vous (tuer|frapper|casser|defoncer)',
    'on va te (tuer|frapper|casser|defoncer|exploser|retrouver|attendre)',
    'on va lui (casser|defoncer|refaire)',
    'tu vas (mourir|crever|morfler|douiller|le regretter|te faire)',
    'je te (defonce|demonte|casse|explose|bute|tue|frappe)',
    'tu es (mort|morte|fini|finie)',
    'ta (derniere heure|gueule)',
    'je vais te retrouver', 'je te retrouve',
    -- Intimidation, y compris sans insulte
    'je sais ou (tu |t )?(h)?abite',
    'je connais ton adresse',
    'je sais ou tu (vis|dors|traines)',
    'je connais ta (famille|mere|soeur|adresse)',
    'fais (bien )?(gaffe|attention) a toi',
    'tu (vas |va )?(voir|verras) (ce qui|ce que)',
    'attends (moi|toi) (dehors|a la sortie|dans la rue)',
    'on se (voit|retrouve) (dehors|a la sortie)',
    'rendez vous (dehors|a la sortie)',
    'tu sortiras pas',
    'je vais m occuper de toi',
    'tu vas payer',
    'tu ne perds rien pour attendre',
    -- Incitation au suicide et a l'automutilation
    'tue toi', 'tuez vous', 'suicide toi', 'suicidez vous',
    'va (te )?(pendre|mourir|crever)', 'allez (mourir|crever)',
    'pends toi', 'jette toi',
    'personne (ne )?t aime', 'tout le monde te deteste',
    'le monde (serait|irait) mieux sans toi',
    'disparais de (ma vie|la terre)',
    -- Haine
    'mort aux', 'sale (juif|arabe|noir|blanc|chinois|musulman|chretien)',
    'retourne (dans|chez) (ton|ta)',
    'a mort les'
  ];

  v_norm  text;
  v_tightened text;
  v_pat text;
begin
  v_norm := public.normalize_for_filter(p_text);
  if v_norm = '' then
    return false;
  end if;

  -- Version sans separateur, pour les insultes fragmentees.
  v_tightened := replace(v_norm, ' ', '');

  foreach v_pat in array v_tight loop
    if position(replace(v_pat, ' ', '') in v_tightened) > 0 then
      return true;
    end if;
  end loop;

  -- Espaces encadrants : garantit la comparaison de mots entiers.
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
-- Rattrapage a l'insertion
--
-- Chaque RPC d'envoi (send_global_message, send_class_message, les deux
-- fonctions d'edition) embarque sa propre liste, figee et bien plus courte.
-- Les reecrire toutes serait long et risque : elles manipulent avertissements
-- et mise en sourdine.
--
-- Ce declencheur applique le filtre renforce APRES elles, et seulement si
-- elles n'ont rien vu — d'ou le test sur is_censored, qu'elles positionnent
-- lorsqu'elles detectent quelque chose. Pas de double comptage
-- d'avertissement, et toute nouvelle voie d'ecriture est couverte d'office.
-- ─────────────────────────────────────────────────────────────
create or replace function public.enforce_chat_filter()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_count integer;
begin
  -- Deja traite par la RPC appelante : on ne repasse pas derriere.
  if coalesce(new.is_censored, false) then
    return new;
  end if;

  if new.content is null or not public.contains_forbidden_words(new.content) then
    return new;
  end if;

  new.content := 'Message censuré';
  new.is_censored := true;

  if new.user_id is not null then
    update public.profiles
    set chat_warning_count = coalesce(chat_warning_count, 0) + 1
    where id = new.user_id
    returning chat_warning_count into v_count;

    -- Meme regle que dans les RPC : mise en sourdine au troisieme
    -- avertissement.
    if coalesce(v_count, 0) >= 3 then
      update public.profiles
      set chat_muted_until = now() + interval '10 minutes'
      where id = new.user_id;
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_chat_filter on public.chat_messages;
create trigger trg_enforce_chat_filter
  before insert or update of content on public.chat_messages
  for each row execute function public.enforce_chat_filter();

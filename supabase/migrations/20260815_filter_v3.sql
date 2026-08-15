-- ============================================================
-- Filtre : tolerance orthographique
--
-- « fais attention a toi » etait bloque, « fait attention a toi en rentrant »
-- passait : le motif exigeait la forme correcte du verbe. Les conjugaisons et
-- fautes courantes sont desormais couvertes, et les motifs restent non
-- ancres, donc valables au milieu d'une phrase.
-- ============================================================

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
    'fdp', 'ntr', 'clc', 'casse les couilles', '', 'nique ta race', 'mongole' , 'filsdepute', 'filledepute', 'ntm', 'nikta', 'niktamere',
    'encule', 'enculer', 'enculee', 'encules', 'niquetamere', 'niquetamer',
    'batard', 'batarde', 'batards',
    'trouduc', 'trouducul', 'tagueule', 'fermetagueule', 'ftg',
    'vatefaire', 'vtff', 'vaffanculo', 'ferlacon',
    'pedale', 'tapette', 'negro', 'negre', 'bougnoule', 'youpin',
    'salerace', 'salepd', 'salechien',
    'grossemerde', 'petasse', 'poufiasse', 'pouffiasse',
    'branleur', 'branlette', 'branler', 'chienne', 'chiennasse',
    'niquer', 'niquee', 'enfoire', 'enfoiree',
    'crevure', 'raclure', 'sousmerde', 'grossepute',
    'suceur', 'suceuse', 'gouine', 'travelo', 'mongolien'
  ];

  v_words text[] := array[
    'con', 'cons', 'conne', 'connes', 'pd', 'pede', 'pedes', 'nique',
    'merde', 'merdeux', 'merdique', 'chier', 'chiotte', 'chiottes', 'chiant',
    'abruti', 'abrutie', 'abrutis', 'imbecile', 'imbeciles',
    'cretin', 'cretine', 'cretins', 'debile', 'debiles',
    'attarde', 'attardee', 'attardes', 'mongol', 'mongole',
    'bouffon', 'bouffonne', 'clochard', 'clocharde',
    'porc', 'truie', 'thon', 'boloss', 'bolos', 'cassos',
    'raciste', 'nazi', 'facho',
    'moche', 'laid', 'laide', 'obese',
    'nul', 'nulle', 'nuls', 'parasite'
  ];

  -- Fragments reutilises : le verbe « faire » et le futur proche sont ecrits
  -- de dix facons par des collegiens. On tolere les formes fautives plutot
  -- que d'esperer l'orthographe juste.
  --   fai[st]e?s?  : fais, fait, faite, faits, faites
  --   (je |j )?(vais|vai|va) : je vais, j vais, vais, va
  v_phrases text[] := array[
    -- Menaces physiques
    '(je |j )?(vais|vai|va)?(te|t) (foudroyer|tuer|frapper|casser|defoncer|exploser|massacrer|eclater|demonter|peter|buter|refaire|cogner|etrangler|saigner|fracasser)',
    '(je |j )?(vais|vai|va) vous (tuer|frapper|casser|defoncer|massacrer)',
    'on (va|vas) te (tuer|frapper|casser|defoncer|exploser|retrouver|attendre|coincer)',
    'on (va|vas) lui (casser|defoncer|refaire|peter)',
    'tu (vas|va|verra|verras) (mourir|crever|morfler|douiller|souffrir|le regretter|te faire|deguster|prendre cher)',
    'je te (defonce|demonte|casse|explose|bute|tue|frappe|cogne|saigne)',
    'tu (es|est|e) (mort|morte|fini|finie|foutu|foutue)',
    'ta (derniere heure|gueule|mere|race)',
    '(je |j )?(vais|vai|va) te retrouver', 'je te retrouve',
    -- Intimidation, y compris sans insulte
    'je (sais|c|sai) (ou|o) (tu |t )?(h)?abite',
    'je (connais|conais) (ton|ta) (adresse|quartier|maison|famille|mere|soeur)',
    'je (sais|sai) (ou|o) tu (vis|dors|traines|vas|va)',
    'je (sais|sai) dans quelle (classe|ecole|rue)',
    -- « fais attention a toi », toutes graphies, avec ou sans complement
    'fai[st]e?s? (bien )?(gaffe|attention|attenssion)( a toi| a ta gueule)?',
    '(gaffe|attention) a toi',
    'fai[st]e?s? (bien )?attention (a toi )?(en |quand tu )(rentr|sort|part|reviens)',
    'tu (vas|va) (voir|comprendre)( ce qui| ce que| demain)?',
    'attends (moi|toi) (dehors|a la sortie|dans la rue|au portail)',
    'on se (voit|retrouve|vera|verra) (dehors|a la sortie|apres)',
    'rendez vous (dehors|a la sortie|au portail)',
    'tu (sortiras|sort|sors) pas', 'tu (vas|va) payer',
    'tu ne perds rien pour attendre', 'ca (va|vas) mal se passer',
    'tu (vas|va) comprendre ta douleur', 'prepare toi',
    '(je |j )?(vais|vai|va) m occuper de (toi|ton cas)', 'tu regretteras',
    'surveille tes arrieres', 'dors bien ce soir',
    -- Incitation au suicide et a l'automutilation
    'tue toi', 'tuez vous', 'suicide toi', 'suicidez vous',
    '(va|vas) (te )?(pendre|mourir|crever|noyer)', 'allez (mourir|crever)',
    'pends toi', 'jette toi', 'saute du', 'coupe toi les veines',
    'personne (ne |t )?(t )?aime', 'tout le monde te deteste',
    'le monde (serait|irait) mieux sans toi',
    'tu (sers|ser) a rien', 'tu (ne )?sers a rien',
    'disparais de (ma vie|la terre|ce monde)', 'creve',
    'tu (devrais|devrai) mourir', 'tu (ferais|ferai) mieux de mourir',
    -- Haine et discrimination
    'mort aux', 'a mort les',
    'sale (juif|arabe|noir|blanc|chinois|musulman|chretien|gitan|rom|feuj|renoi)',
    'retourne (dans|chez|a) (ton|ta)',
    'rentre dans ton pays', 'on (veut|voulait) pas de (toi|vous) ici',
    'tous les (juifs|arabes|noirs|musulmans)',
    -- Harcelement sexuel
    'envoie (moi )?(des |une )?(nude|photo de toi)',
    '(je |j )?(vais|vai|va) te violer', '(je |j )?(vais|vai|va) t agresser',
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

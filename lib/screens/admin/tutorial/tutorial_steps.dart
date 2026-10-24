import 'package:flutter/material.dart';

import 'tutorial_engine.dart';
import 'tutorial_scenes_admin.dart';
import 'tutorial_scenes_app.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Déroulé du tutoriel : une étape par fonction de l'application.
//
// Les textes ne s'adressent jamais directement à la personne (ni « tu », ni
// « vous ») : consignes à l'infinitif, comme dans le reste de l'application.
// ─────────────────────────────────────────────────────────────────────────────

typedef DemoSceneBuilder = Widget Function(
  BuildContext context,
  DemoController c,
);

typedef DemoScript = Future<void> Function(DemoPlayer p);

class TutorialChapter {
  const TutorialChapter(this.title, this.icon);

  final String title;
  final IconData icon;
}

class TutorialStep {
  const TutorialStep({
    required this.chapter,
    required this.title,
    required this.text,
    this.points = const [],
    this.tip,
    required this.scene,
    this.initial = const {},
    this.script,
    this.focus,
  });

  final TutorialChapter chapter;
  final String title;

  /// À quoi sert la fonction, en une ou deux phrases.
  final String text;

  /// Comment s'en servir, geste par geste.
  final List<String> points;

  /// Précision utile (piège à éviter, raccourci…).
  final String? tip;

  final DemoSceneBuilder scene;

  /// État de départ de la scène, rétabli avant chaque exemple.
  final Map<String, Object?> initial;

  /// Exemple joué par « Jouer l'exemple » ; null : rien à montrer.
  final DemoScript? script;

  /// Élément entouré tant que l'exemple ne joue pas.
  final String? focus;
}

const _welcome = TutorialChapter('Bienvenue', Icons.waving_hand_rounded);
const _home = TutorialChapter('Accueil', Icons.home_rounded);
const _accounts = TutorialChapter('Comptes', Icons.people_rounded);
const _moderation = TutorialChapter('Modération', Icons.shield_rounded);
const _chat = TutorialChapter('Chat', Icons.forum_rounded);
const _market = TutorialChapter('Marché', Icons.storefront_rounded);
const _classes = TutorialChapter('Classes', Icons.school_rounded);
const _loans = TutorialChapter('Prêts', Icons.account_balance_rounded);
const _economy = TutorialChapter('Économie', Icons.query_stats_rounded);
const _money = TutorialChapter('Argent', Icons.account_balance_wallet_rounded);
const _users = TutorialChapter('Côté utilisateurs', Icons.backpack_rounded);
const _profile = TutorialChapter('Profil et réglages', Icons.person_rounded);
const _maintenance = TutorialChapter('Maintenance', Icons.construction_rounded);
const _end = TutorialChapter('Fin', Icons.flag_rounded);

const tutorialSteps = <TutorialStep>[
  // ── Bienvenue ─────────────────────────────────────────────────────────────
  TutorialStep(
    chapter: _welcome,
    title: 'Bienvenue dans le tutoriel',
    text: 'Ce tutoriel présente toutes les fonctions de SES Coin, une par '
        'une. Chaque étape montre un écran de l\'application et explique à '
        'quoi il sert.',
    points: [
      '« Jouer l\'exemple » : un point animé montre la manipulation, pas à '
          'pas.',
      'Pendant l\'exemple : « Pause » pour figer, « Arrêter » pour revenir à '
          'l\'explication.',
      '« Suivant » et « Retour » : passer d\'une fonction à l\'autre.',
      '« Sommaire », en haut : aller directement à une fonction.',
      'Tout est factice : les exemples ne modifient aucun compte.',
    ],
    tip: 'Le tutoriel reste disponible à tout moment : Administration, tout '
        'en bas, « Tutoriel ».',
    scene: navScene,
    script: playWelcome,
    focus: 'adminButton',
  ),

  // ── Accueil ───────────────────────────────────────────────────────────────
  TutorialStep(
    chapter: _home,
    title: 'L\'écran d\'accueil',
    text: 'Premier écran après la connexion : le résumé du compte et du '
        'marché.',
    points: [
      '« Solde » : l\'argent disponible, en SC (SES Coin).',
      'La pastille de couleur : le cours monte (vert) ou baisse (rouge).',
      'Le graphique : toucher une colonne affiche son prix exact.',
      'Les actions rapides : Payer, Transférer, Prêts, Comptes, Classement, '
          'Blockchain.',
      'La cloche : les notifications (en rouge : non lues). La barre du '
          'bas : les grandes '
          'rubriques de l\'application.',
    ],
    scene: navScene,
    script: playHomeTour,
    focus: 'balance',
  ),
  TutorialStep(
    chapter: _home,
    title: 'Le panneau d\'administration',
    text: 'Le bouclier en haut à droite de l\'accueil n\'apparaît que sur le '
        'compte administrateur : accès à toutes les fonctions de gestion.',
    points: [
      'Notifications en orange : le nombre de décisions en attente '
          '(demandes de compte, signalements et photos à valider).',
      'Fonctions rangées par thème : Comptes, Marché, Classes, Prêts, '
          'Économie et Aide.',
      'Les étapes suivantes les présentent toutes, dans cet ordre.',
    ],
    scene: navScene,
    script: playAdminPanel,
    focus: 'adminButton',
  ),

  // ── Comptes ───────────────────────────────────────────────────────────────
  TutorialStep(
    chapter: _accounts,
    title: 'Trouver un compte',
    text: 'Administration → « Tous les comptes » : chaque utilisateur avec '
        'son solde.',
    points: [
      'La barre de recherche filtre par nom ou par identifiant.',
      'Toucher un compte ouvre sa fiche : solde et transactions récentes.',
      'Le bouton ⋮ à droite d\'un compte réunit toutes les actions : '
          'créditer, débiter, bannir, mot de passe, supprimer.',
    ],
    scene: accountsScene,
    script: playSearchAccounts,
    focus: 'search',
  ),
  TutorialStep(
    chapter: _accounts,
    title: 'Créditer ou débiter un compte',
    text: 'Ajouter ou retirer de l\'argent sur un compte précis, par exemple '
        'pour récompenser un travail.',
    points: [
      '⋮ à droite du compte → « Créditer » pour ajouter, « Débiter » pour '
          'retirer.',
      'Saisir le montant, puis la raison, visible dans l\'historique du '
          'compte.',
      '« Appliquer » : solde modifié immédiatement.',
    ],
    scene: accountsScene,
    script: playCredit,
    focus: 'dots_utilisateur.y',
  ),
  TutorialStep(
    chapter: _accounts,
    title: 'Bannir un compte',
    text: 'Suspendre un compte qui ne respecte pas les règles : motif '
        'affiché sur l\'accueil du compte, actions bloquées.',
    points: [
      '⋮ → « Bannir », puis écrire le motif.',
      'Choisir la durée : 1 heure, 24 heures, 7 jours, sans terme, ou une '
          'durée personnalisée.',
      '« Suspendre » : application immédiate, levée automatique à la fin de '
          'la durée.',
      'Pour lever plus tôt : ⋮ → « Débannir ».',
    ],
    tip: 'Chaque bannissement est noté dans le journal des sanctions.',
    scene: accountsScene,
    script: playBan,
    focus: 'dots_utilisateur.z',
  ),
  TutorialStep(
    chapter: _accounts,
    title: 'Réinitialiser un mot de passe',
    text: 'Mot de passe oublié : choix d\'un nouveau mot de passe par '
        'l\'administration.',
    points: [
      '⋮ → « Réinitialiser le mot de passe ».',
      'Taper le nouveau mot de passe : 8 caractères minimum.',
      'Communiquer ce mot de passe à l\'utilisateur, avec possibilité de '
          'changement ensuite depuis le profil.',
    ],
    scene: accountsScene,
    script: playResetPassword,
    focus: 'dots_utilisateur.x',
  ),
  TutorialStep(
    chapter: _accounts,
    title: 'Supprimer un compte',
    text: 'Retirer définitivement un compte de l\'application.',
    points: [
      '⋮ → « Supprimer », puis confirmer.',
      'Compte retiré de la liste, connexion impossible.',
    ],
    scene: accountsScene,
    script: playDeleteAccount,
    focus: 'dots_utilisateur.u',
  ),
  TutorialStep(
    chapter: _accounts,
    title: 'Valider une photo de profil',
    text: 'Une nouvelle photo de profil n\'est visible qu\'après validation '
        'par l\'administration.',
    points: [
      'Deux accès : la pastille « Photo » dans « Tous les comptes », ou la '
          'notification « Changement de photo demandé » dans le centre de '
          'notifications.',
      'L\'écran compare l\'ancienne photo et la nouvelle ; la flèche agrandit.',
      '« Approuver » : photo publiée. « Refuser » : photo rejetée.',
    ],
    tip: 'Photo du compte administrateur : changement immédiat, sans '
        'validation.',
    scene: accountsScene,
    initial: {'photoPending': true},
    script: playPhotoReview,
    focus: 'photoBadge',
  ),
  TutorialStep(
    chapter: _accounts,
    title: 'Les demandes de compte',
    text: 'Pas de création de compte libre : chaque demande part de '
        'l\'écran de connexion et attend une décision.',
    points: [
      'Chaque demande montre la photo, le nom, l\'identifiant et la classe '
          'choisie.',
      '« Approuver » : fixer le solde de départ (100 SC proposés) et la '
          'classe, puis valider.',
      '« Refuser » : demande rejetée.',
    ],
    tip: 'Chaque nouvelle demande arrive aussi en notification et sur la '
        'pastille du bouclier.',
    scene: requestsScene,
    initial: {'balance': '100'},
    script: playApproveRequest,
    focus: 'req_lea',
  ),

  // ── Modération ────────────────────────────────────────────────────────────
  TutorialStep(
    chapter: _moderation,
    title: 'Les signalements',
    text: 'Un message du chat signalé par des utilisateurs arrive ici, en '
        'attente de décision.',
    points: [
      'Le chiffre en couleur : le nombre d\'utilisateurs qui ont signalé ce '
          'message.',
      'Le message, son auteur et les auteurs des signalements.',
      '« Discussion » : toute la conversation enregistrée dans un fichier.',
      '« Bannir » : suspension de l\'auteur, motif déjà rempli.',
      '« Traité » : signalement retiré de la liste d\'attente.',
    ],
    tip: '« En attente » ↔ « Tous » : revoir les signalements déjà traités.',
    scene: reportsScene,
    script: playReports,
    focus: 'severity',
  ),
  TutorialStep(
    chapter: _moderation,
    title: 'Le journal des sanctions',
    text: 'L\'historique de toutes les mesures prises : bannissements et '
        'suspensions du chat.',
    points: [
      'L\'état : « en cours » ou « levée ».',
      'Le motif, la date et la fin prévue de chaque mesure.',
      'Le robot 🤖 : mesure prise automatiquement par l\'application, par '
          'exemple après plusieurs signalements retenus.',
    ],
    scene: sanctionsScene,
    script: playSanctions,
    focus: 'sanc_ban',
  ),

  // ── Chat ──────────────────────────────────────────────────────────────────
  TutorialStep(
    chapter: _chat,
    title: 'Publier une annonce',
    text: 'Le chat « Annonces » est lu par tous les utilisateurs. Écriture '
        'réservée à l\'administration.',
    points: [
      'Écrire dans le champ du bas, puis toucher la flèche pour publier.',
      'Appui long sur une annonce : « Modifier » ou « Supprimer ».',
      'Exemple : annoncer la mise aux enchères de la copie du contrôle de '
          'demain des Terminale, puis préciser l\'heure de fin.',
    ],
    scene: chatScene,
    script: playAnnouncement,
    focus: 'input',
  ),
  TutorialStep(
    chapter: _chat,
    title: 'Envoyer un cadeau',
    text: 'Un cadeau est une somme posée dans le chat, pour le premier '
        'utilisateur à toucher « Récupérer ».',
    points: [
      '🎁 à gauche du champ : choisir le montant et, si besoin, un motif.',
      '« Envoyer » : cadeau publié dans le chat.',
      'Le premier utilisateur qui touche « Récupérer » reçoit la somme.',
    ],
    scene: chatScene,
    initial: chatAfterAnnouncement,
    script: playGift,
    focus: 'giftBtn',
  ),
  TutorialStep(
    chapter: _chat,
    title: 'Les demandes de prêt du chat',
    text: 'Un utilisateur peut publier une demande de prêt dans les annonces '
        'ou dans le chat de sa classe. Un autre utilisateur accepte la '
        'demande et prête la somme.',
    points: [
      'La carte indique le montant, le taux, la durée et le motif.',
      'L\'administrateur ne prête pas d\'argent : aucun bouton « Accepter » '
          'de ce côté.',
      'Une demande que personne n\'accepte expire au bout de 24 heures.',
    ],
    scene: chatScene,
    initial: chatAfterAnnouncement,
    script: playChatLoan,
    focus: 'loanBubble',
  ),
  TutorialStep(
    chapter: _chat,
    title: 'Modérer le chat d\'une classe',
    text: 'Chaque classe a son propre chat. L\'administration peut lire et '
        'modérer tous les chats de classe.',
    points: [
      'Le drapeau à côté d\'un message : censure immédiate.',
      'Appui long sur un message → « Supprimer » : suppression pour tout le '
          'monde.',
      'Sous les messages : la liste des lecteurs, visible par tous les '
          'membres (toucher pour voir les noms).',
      'Le bouton + : envoyer un cadeau à la classe.',
    ],
    scene: chatScene,
    initial: {'page': 'class'},
    script: playModerateClass,
    focus: 'msg_hugo',
  ),

  // ── Marché ────────────────────────────────────────────────────────────────
  TutorialStep(
    chapter: _market,
    title: 'Créer une offre en boutique',
    text: 'La boutique vend des avantages contre des SC. Les offres sont '
        'créées par l\'administration.',
    points: [
      'Administration → « Gérer le marché » → « Ajouter une offre boutique ».',
      'Le nom, la catégorie, le prix et une description.',
      'Le stock : nombre d\'exemplaires en vente (-1 = illimité).',
      'La limite par utilisateur (-1 = sans limite).',
    ],
    scene: marketAdminScene,
    initial: {'f_stock': '-1', 'f_limit': '-1'},
    script: playCreateItem,
    focus: 'addItem',
  ),
  TutorialStep(
    chapter: _market,
    title: 'Gérer une offre',
    text: 'Suivi des ventes d\'une offre, modification ou retrait.',
    points: [
      'Les pastilles : catégorie, stock restant (rouge à 3 ou moins), '
          'limite par utilisateur.',
      '🕘 « Historique » : qui a acheté, quand et à quel prix.',
      '✏️ : modifier l\'offre (prix, stock, texte…).',
      '« Supprimer » : retire l\'offre tout de suite, sans confirmation.',
    ],
    scene: marketAdminScene,
    script: playManageItem,
    focus: 'i0_badges',
  ),
  TutorialStep(
    chapter: _market,
    title: 'Créer une enchère',
    text: 'Mettre un objet aux enchères : les utilisateurs font des offres, '
        'victoire du plus offrant à la fin.',
    points: [
      'Onglet « Enchères » → « Créer une enchère ».',
      'Le nom de l\'objet, le prix de départ et la durée.',
      '« Créer l\'enchère » : visible tout de suite.',
    ],
    scene: marketAdminScene,
    initial: {'a_hours': '24', 'a_minutes': '0'},
    script: playCreateAuction,
    focus: 'tabs',
  ),
  TutorialStep(
    chapter: _market,
    title: 'Gérer une enchère',
    text: 'Suivi d\'une enchère en cours, avec arrêt possible. Exemple : '
        '« +1 point sur la dernière évaluation ».',
    points: [
      'Le statut, la date de fin et le compte à rebours.',
      'Le meilleur enchérisseur, avec son émoji.',
      '🕘 « Historique » : toutes les offres placées.',
      '« Annuler » : arrêt sans gagnant, le meilleur enchérisseur est '
          'remboursé.',
      '« Clôturer » : fin immédiate, victoire du meilleur enchérisseur.',
    ],
    tip: 'L\'administrateur ne peut pas enchérir.',
    scene: marketAdminScene,
    initial: {'page': 'auctions'},
    script: playManageAuction,
    focus: 'a0_badges',
  ),

  // ── Classes ───────────────────────────────────────────────────────────────
  TutorialStep(
    chapter: _classes,
    title: 'Créer et organiser les classes',
    text: 'Les classes regroupent les utilisateurs (TG1, 1G1…). '
        'Chaque classe a son chat.',
    points: [
      'Administration → « Gérer les classes ».',
      '« Nouvelle classe », en bas à droite, puis le nom.',
      '⋮ sur une classe : « Renommer » ou « Supprimer ».',
    ],
    scene: classesScene,
    script: playClasses,
    focus: 'fab',
  ),
  TutorialStep(
    chapter: _classes,
    title: 'Les membres d\'une classe',
    text: 'Ajouter ou retirer des utilisateurs d\'une classe.',
    points: [
      'Toucher une classe ouvre sa fiche et la liste de ses membres.',
      '« Ajouter » : choisir parmi les utilisateurs sans classe.',
      'L\'icône rouge retire un membre de la classe.',
      'La bulle, en haut : le chat de la classe.',
    ],
    scene: classesScene,
    script: playClassMembers,
    focus: 'class_TG1',
  ),

  // ── Prêts ─────────────────────────────────────────────────────────────────
  TutorialStep(
    chapter: _loans,
    title: 'Tous les prêts',
    text: 'Administration → « Prêts » : tous les prêts entre utilisateurs.',
    points: [
      'Chaque ligne : statut, montant, prêteur (vert) et emprunteur (rouge).',
      'Toucher un prêt : total dû, déjà remboursé, reste à payer, '
          'progression et échéance.',
      'Un prêt non remboursé à l\'échéance est prélevé automatiquement sur '
          'le compte de l\'emprunteur.',
    ],
    tip: 'Les utilisateurs ne peuvent pas demander un prêt à '
        'l\'administrateur.',
    scene: loansAdminScene,
    initial: loanSettingsInitial,
    script: playLoansList,
    focus: 'loan0',
  ),
  TutorialStep(
    chapter: _loans,
    title: 'Les règles des prêts',
    text: 'Les limites que toutes les demandes de prêt doivent respecter.',
    points: [
      'Onglet « Paramètres ».',
      'Montant maximal par jour et par semaine, nombre de prêts en cours, '
          'durée maximale, taux maximal, solde minimum pour emprunter.',
      '« Enregistrer » : les règles valent pour toutes les nouvelles '
          'demandes.',
    ],
    scene: loansAdminScene,
    initial: loanSettingsInitial,
    script: playLoanSettings,
    focus: 'tabs',
  ),

  // ── Économie ──────────────────────────────────────────────────────────────
  TutorialStep(
    chapter: _economy,
    title: 'Taxer tout le monde',
    text: 'Prélever un pourcentage sur le solde de chaque utilisateur, en une '
        'seule fois.',
    points: [
      'Le pourcentage prélevé sur chaque solde.',
      'La raison, facultative, affichée aux utilisateurs.',
      '« Appliquer la taxe », puis confirmer.',
    ],
    tip: 'Une taxe appliquée ne s\'annule pas.',
    scene: taxScene,
    script: playTax,
    focus: 'f_percent',
  ),
  TutorialStep(
    chapter: _economy,
    title: 'Distribuer une récompense',
    text: 'Créditer le même montant sur tous les comptes, en une seule fois.',
    points: [
      'Le montant reçu par chaque utilisateur.',
      'La raison, facultative, affichée aux utilisateurs.',
      '« Distribuer » : tous les comptes crédités, sans confirmation.',
    ],
    scene: rewardScene,
    script: playReward,
    focus: 'f_rewardAmount',
  ),
  TutorialStep(
    chapter: _economy,
    title: 'Modifier le cours',
    text: 'Le cours est la valeur de la monnaie affichée sur l\'accueil. Le '
        'graphique du marché se dessine à la main : demande, offre et prix.',
    points: [
      'Choisir la série à dessiner : « Demande », « Offre » ou « Prix ».',
      'Glisser sur le graphique : les colonnes ou la courbe suivent le '
          'mouvement.',
      'Un simple toucher sur une colonne rectifie aussi sa valeur, sans '
          'glisser.',
      'Appui long sur une colonne : saisir sa valeur exacte.',
      'La flèche ↓ reprend le dernier prix comme cours ; écrire la raison, '
          'puis « Appliquer le nouveau cours ».',
    ],
    scene: rateScene,
    initial: {'rate': '2.0000'},
    script: playRate,
    focus: 'series',
  ),

  // ── Argent ────────────────────────────────────────────────────────────────
  TutorialStep(
    chapter: _money,
    title: 'Le portefeuille',
    text: 'L\'historique complet des opérations du compte, de la plus '
        'récente à la plus ancienne.',
    points: [
      'Chaque ligne : le type d\'opération, l\'autre compte et la date.',
      'En vert ce qui arrive, en rouge ce qui part.',
      '↻ en haut à droite actualise la liste.',
    ],
    scene: walletScene,
    script: playWallet,
    focus: 'tx_0',
  ),
  TutorialStep(
    chapter: _money,
    title: 'Transférer de l\'argent',
    text: 'Envoyer des SC à un ou plusieurs comptes, même à distance.',
    points: [
      'Chercher un destinataire, puis toucher son nom dans la liste.',
      'Plusieurs destinataires possibles : le même montant part vers chacun.',
      'Le montant, et une description si besoin.',
      '« Envoyer » (avec confirmation du total s\'il y a plusieurs '
          'destinataires) : une notification pour chaque compte.',
    ],
    scene: transferScene,
    script: playTransfer,
    focus: 'recipient',
  ),
  TutorialStep(
    chapter: _money,
    title: 'Payer sur place',
    text: 'Payer quelqu\'un à proximité, sans chercher son nom.',
    points: [
      '« Recevoir » : le QR code du compte, à montrer à qui paie.',
      '« Envoyer » : saisir le montant, puis payer.',
      '« Payer via NFC » : rapprocher les deux téléphones.',
      '« Payer via QR Code » : scanner le QR de l\'autre personne.',
    ],
    scene: payScene,
    script: playPay,
    focus: 'qr',
  ),

  // ── Côté utilisateurs ─────────────────────────────────────────────────────
  TutorialStep(
    chapter: _users,
    title: 'Acheter en boutique',
    text: 'Le marché tel que les utilisateurs le voient.',
    points: [
      'Les offres sont rangées par catégorie.',
      '« Limite atteinte » : le maximum d\'achats autorisé est atteint.',
      '« Épuisé » : tout le stock de l\'offre est vendu.',
      '« Acheter » montre le prix, le solde actuel et le solde après achat, '
          'avant de payer.',
    ],
    scene: shopScene,
    script: playBuy,
    focus: 'item_joker',
  ),
  TutorialStep(
    chapter: _users,
    title: 'Enchérir',
    text: 'La participation d\'un utilisateur à une enchère.',
    points: [
      'Onglet « Enchères » : prix actuel, meilleur enchérisseur, temps '
          'restant.',
      'Une offre doit dépasser le prix actuel d\'au moins 1 SC.',
      'Le meilleur enchérisseur choisit l\'émoji affiché à côté de son nom.',
    ],
    tip: 'L\'administrateur ne peut pas enchérir.',
    scene: shopScene,
    script: playBid,
    focus: 'shopTabs',
  ),
  TutorialStep(
    chapter: _users,
    title: 'Demander un prêt',
    text: 'Un utilisateur peut demander un prêt à un ou plusieurs autres '
        'utilisateurs précis.',
    points: [
      'Choisir le ou les prêteurs.',
      'Le montant emprunté et le taux d\'intérêt (de 0 à 100 %).',
      'L\'échéance : une date précise, ou une durée qui démarre quand le '
          'prêt est accepté.',
      '« Envoyer la demande », puis vérifier le récapitulatif.',
    ],
    tip: 'Le compte administrateur ne peut pas être choisi comme prêteur.',
    scene: loanCreateScene,
    script: playLoanCreate,
    focus: 'lenderSearch',
  ),
  TutorialStep(
    chapter: _users,
    title: 'Les prêts d\'un utilisateur',
    text: 'L\'onglet « Prêts » du profil : les prêts demandés et ceux à '
        'accorder.',
    points: [
      'Prêteur sollicité : « Accepter » envoie la somme, « Refuser » '
          'décline.',
      'Emprunteur : « Rembourser », en une ou plusieurs fois.',
      'Un prêt terminé se retire avec la corbeille.',
    ],
    scene: profileScene,
    initial: {'page': 'student'},
    script: playStudentLoans,
    focus: 'loanLender',
  ),

  // ── Profil et réglages ────────────────────────────────────────────────────
  TutorialStep(
    chapter: _profile,
    title: 'Le profil',
    text: 'Le compte en un coup d\'œil : photo, solde, mot de passe et '
        'raccourcis.',
    points: [
      'Toucher la photo pour la changer.',
      'En haut : Paramètres, Blockchain, Classement et Déconnexion.',
      '« Mot de passe » : le mot de passe actuel, puis le nouveau (8 '
          'caractères minimum), à confirmer.',
    ],
    tip: 'Pour les utilisateurs, le compte administrateur apparaît sous le '
        'nom « Mme Kajouj-Bouchelaghem ».',
    scene: profileScene,
    script: playProfile,
    focus: 'photo',
  ),
  TutorialStep(
    chapter: _profile,
    title: 'Les notifications',
    text: 'Tout ce qui attend une action : demandes de compte, photos à '
        'valider…',
    points: [
      'Non lue : titre en gras et point doré.',
      'Toucher une notification : marquée comme lue.',
      '« Changement de photo demandé » : ouvre directement l\'écran de '
          'validation de la photo.',
      'Glisser vers la gauche : supprimer.',
      '« Tout vu » marque tout comme lu ; « Tout supprimer » vide la liste.',
    ],
    scene: profileScene,
    initial: {'page': 'notifs'},
    script: playNotifications,
    focus: 'notif_0',
  ),
  TutorialStep(
    chapter: _profile,
    title: 'Les paramètres d\'apparence',
    text: 'Adapter l\'apparence de l\'application. Ces réglages ne concernent '
        'que le téléphone utilisé.',
    points: [
      'Thème : Système, Clair ou Sombre.',
      'Ambiance : la teinte des fonds et des cartes.',
      'Couleur d\'accent : boutons, montants, éléments actifs.',
      'Taille du texte, police et « Réduire les animations ».',
      '↺ en haut à droite : revenir aux réglages d\'origine.',
    ],
    scene: settingsScene,
    script: playSettings,
    focus: 'modeRow',
  ),
  TutorialStep(
    chapter: _profile,
    title: 'Classement, comptes et blockchain',
    text: 'Trois écrans pour observer l\'économie de la classe.',
    points: [
      'Classement : le podium des plus riches, puis tous les comptes '
          '(sans l\'administrateur).',
      'Comptes : l\'annuaire, avec recherche.',
      'Blockchain : toutes les transactions de tous les comptes, en direct.',
      'L\'icône de filtres : recherche, montant, type, méthode de paiement.',
    ],
    scene: explorerScene,
    script: playExplore,
    focus: 'podium',
  ),

  // ── Maintenance ───────────────────────────────────────────────────────────
  TutorialStep(
    chapter: _maintenance,
    title: 'L\'écran de maintenance',
    text: 'Pendant une maintenance, cet écran remplace l\'application, '
        'jusqu\'à la fin de l\'intervention.',
    points: [
      'Maintenance générale : tous les comptes voient cet écran.',
      'Anciennes versions de l\'application : connexion et actions refusées '
          'pendant la maintenance (« Maintenance en cours. »).',
      'Maintenance de l\'administration : seul le compte administrateur est '
          'bloqué ; les utilisateurs continuent normalement.',
      '« Vérifier la fin de la maintenance » relance la vérification ; '
          '« Se déconnecter » reste possible.',
    ],
    tip: 'Rien à faire : retour automatique de l\'application à la fin.',
    scene: maintenanceScene,
    script: playMaintenance,
    focus: 'balance',
  ),

  // ── Fin ───────────────────────────────────────────────────────────────────
  TutorialStep(
    chapter: _end,
    title: 'C\'est terminé !',
    text: 'Toutes les fonctions de SES Coin ont été présentées.',
    points: [
      '« Sommaire », en haut : revoir n\'importe quelle fonction.',
      'Le tutoriel reste disponible : Administration, tout en bas, '
          '« Tutoriel ».',
    ],
    scene: navScene,
    focus: 'adminButton',
  ),
];

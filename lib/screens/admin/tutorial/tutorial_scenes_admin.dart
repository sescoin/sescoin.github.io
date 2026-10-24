import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../common/admin_widgets.dart';
import '../../../common/app_dialog.dart';
import '../../../common/empty_state.dart';
import '../../../common/user_avatar.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../transaction/global_transaction_tile.dart';
import '../../../transaction/transaction_tile.dart';
import '../admin_screen.dart';
import 'tutorial_engine.dart';
import 'tutorial_mock.dart';
import '../../../core/user_handle.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Scènes du tutoriel : accueil et administration.
//
// Chaque scène reproduit un écran réel avec des données fictives ; chaque
// scénario (play…) rejoue une manipulation sur cette scène.
// ─────────────────────────────────────────────────────────────────────────────

final _dateFmt = DateFormat('dd/MM/yyyy à HH:mm');
final _shortFmt = DateFormat('dd/MM/yyyy HH:mm');

/// Repli animé d'un élément de liste (filtré, supprimé, traité…).
class _Collapse extends StatelessWidget {
  const _Collapse({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        heightFactor: visible ? 1 : 0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 260),
          opacity: visible ? 1 : 0,
          child: child,
        ),
      ),
    );
  }
}

/// Carte de formulaire titrée (« Informations », « Contenu »…).
class _FormSection extends StatelessWidget {
  const _FormSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Bouton principal ancré en bas d'un formulaire.
Widget _bottomAction(Widget button) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: button,
    );

ButtonStyle _dangerFilled() =>
    FilledButton.styleFrom(backgroundColor: AppTheme.negative);

ButtonStyle _dangerOutlined() => OutlinedButton.styleFrom(
      foregroundColor: AppTheme.negative,
      side: const BorderSide(color: AppTheme.negative),
    );

// ═════════════════════════════════════════════════════════════════════════════
// Accueil et panneau d'administration
// ═════════════════════════════════════════════════════════════════════════════

/// Accueil factice : solde, graphique, raccourcis, dernières transactions.
class DemoHomePage extends StatelessWidget {
  const DemoHomePage({super.key, required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final me = DemoIdentity.of(context);
    final titleStyle =
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);

    return MockScreen(
      back: false,
      titleWidget: const MockBrandTitle(),
      actions: [
        c.mark('bell', const MockIcon(Icons.notifications_outlined, badge: 2)),
        c.mark(
          'adminButton',
          const MockIcon(
            Icons.admin_panel_settings_rounded,
            badge: 3,
            badgeColor: AppTheme.warning,
          ),
        ),
      ],
      navIndex: 0,
      body: ListView(
        controller: c.scroller('home'),
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          c.mark('balance', _DemoBalanceCard(c: c, username: me.username)),
          const SizedBox(height: 20),
          c.mark('chart', _DemoChartCard(c: c)),
          const SizedBox(height: 20),
          Text('Actions rapides', style: titleStyle),
          const SizedBox(height: 12),
          c.mark('quick', const _DemoQuickActions()),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dernières transactions', style: titleStyle),
              const TextButton(onPressed: demoNoop, child: Text('Voir tout')),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                TransactionTile(
                  transaction: demoTx(
                    id: 'home-1',
                    type: TransactionType.transfer,
                    amount: 15,
                    incoming: true,
                    other: demoX,
                  ),
                ),
                const Divider(height: 1, indent: 16),
                TransactionTile(
                  transaction: demoTx(
                    id: 'home-2',
                    type: TransactionType.transfer,
                    amount: 20,
                    incoming: false,
                    other: demoY,
                    ago: const Duration(days: 1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoBalanceCard extends StatelessWidget {
  const _DemoBalanceCard({required this.c, required this.username});

  final DemoController c;
  final String username;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A2E),
            Color.lerp(const Color(0xFF16213E), accent, 0.12)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Solde',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              c.mark('rateBadge', const _DemoRateBadge(change: 4.2)),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: DemoAmount(
              value: c.number('myBalance', 999999),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            userHandle(username),
            style: TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoRateBadge extends StatelessWidget {
  const _DemoRateBadge({required this.change});

  final double change;

  @override
  Widget build(BuildContext context) {
    const color = AppTheme.positive;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.trending_up_rounded, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '+${change.toStringAsFixed(2)}%',
            style: const TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoChartCard extends StatelessWidget {
  const _DemoChartCard({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final onVariant = theme.colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.insights_rounded, color: accent, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Évolution du prix',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        "Selon l'offre et la demande",
                        style: TextStyle(fontSize: 12, color: onVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, Color.lerp(accent, Colors.black, 0.18)!],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '2,00 €',
                        style: TextStyle(
                          color: AppTheme.onAccent(accent),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '1 SC',
                        style: TextStyle(
                          color:
                              AppTheme.onAccent(accent).withValues(alpha: 0.75),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const DemoChartLegend(),
            const SizedBox(height: 10),
            c.mark(
              'chartArea',
              DemoMarketChart(
                demand: demoDemand,
                supply: demoSupply,
                price: demoPrice,
                selectedIndex: c.get<int>('chartTip'),
                height: 150,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 1; i <= 10; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        '$i',
                        style: TextStyle(
                          color: onVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoQuickActions extends StatelessWidget {
  const _DemoQuickActions();

  static const _actions = [
    (Icons.qr_code_scanner_rounded, 'Payer'),
    (Icons.send_rounded, 'Transférer'),
    (Icons.handshake_rounded, 'Prêts'),
    (Icons.people_alt_rounded, 'Comptes'),
    (Icons.leaderboard_rounded, 'Classement'),
    (Icons.hub_rounded, 'Blockchain'),
  ];

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 24) / 3;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final action in _actions)
              Container(
                width: width,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: context.isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(action.$1, color: accent, size: 20),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      action.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Panneau d'administration factice, construit depuis le même menu que le
/// vrai panneau.
class _DemoAdminPanel extends StatelessWidget {
  const _DemoAdminPanel({required this.c});

  final DemoController c;

  static const _badges = {'reports': 1, 'requests': 2};

  @override
  Widget build(BuildContext context) {
    final me = DemoIdentity.of(context);
    var index = 0;
    return MockScreen(
      title: 'Administration',
      body: ListView(
        controller: c.scroller('admin'),
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          AdminHeaderCard(name: me.name),
          for (final section in adminMenu) ...[
            const SizedBox(height: 18),
            AdminSectionTitle(icon: section.icon, title: section.title),
            for (final entry in section.entries)
              c.mark(
                'tile_${entry.id}',
                AdminTile(
                  index: ++index,
                  entry: entry,
                  badgeCount: _badges[entry.id] ?? 0,
                  onTap: demoNoop,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Accueil, puis panneau d'administration.
Widget navScene(BuildContext context, DemoController c) => DemoPages(
      page: c.page,
      builder: (page) =>
          page == 'admin' ? _DemoAdminPanel(c: c) : DemoHomePage(c: c),
    );

Future<void> playWelcome(DemoPlayer p) async {
  p.say('Depuis l\'accueil, toucher le bouclier en haut à droite');
  await p.tap('adminButton');
  p.set('page', 'admin');
  await p.wait(800);
  p.say('Ouverture du panneau d\'administration');
  await p.wait(900);
  p.say('Tout en bas, après toutes les fonctions : « Tutoriel »');
  await p.reveal('tile_tutorial', alignment: 0.8);
  await p.tap('tile_tutorial');
  await p.toast('Le tutoriel démarre.', kind: DemoToastKind.info);
}

Future<void> playHomeTour(DemoPlayer p) async {
  p.say('« Solde » : l\'argent disponible sur le compte');
  await p.moveTo('balance', at: const Alignment(-0.5, 0.2));
  await p.wait(1000);
  p.say('La pastille : le cours monte (vert) ou baisse (rouge)');
  await p.moveTo('rateBadge');
  await p.wait(1000);
  p.say('Toucher une colonne du graphique : affichage de son prix exact');
  await p.reveal('chartArea', alignment: 0.35);
  final chart = p.rectOf('chartArea');
  if (chart != null) {
    await p.tapAt(Offset(chart.left + chart.width * 0.75, chart.center.dy));
    p.set('chartTip', 7);
  }
  await p.wait(1500);
  p.say(
      'Les raccourcis : Payer, Transférer, Prêts, Comptes, Classement, Blockchain');
  await p.reveal('quick', alignment: 0.6);
  await p.moveTo('quick');
  await p.wait(1400);
  p.say('La cloche : les notifications (pastille rouge = non lues)');
  await p.reveal('balance', alignment: 0);
  await p.moveTo('bell');
  await p.wait(1100);
}

Future<void> playAdminPanel(DemoPlayer p) async {
  p.say('La pastille orange : 2 demandes de compte + 1 signalement');
  await p.moveTo('adminButton');
  await p.wait(1100);
  await p.tap('adminButton');
  p.set('page', 'admin');
  await p.wait(800);
  p.say('Comptes : tous les comptes, signalements, sanctions et demandes');
  await p.moveTo('tile_accounts', at: const Alignment(-0.5, 0));
  await p.wait(1000);
  await p.moveTo('tile_requests', at: const Alignment(-0.5, 0));
  await p.wait(700);
  p.say('Marché, Classes et Prêts');
  await p.reveal('tile_loans', alignment: 0.7);
  await p.moveTo('tile_market', at: const Alignment(-0.5, 0));
  await p.wait(600);
  await p.moveTo('tile_loans', at: const Alignment(-0.5, 0));
  await p.wait(700);
  p.say('Économie : taxe, récompense et cours de la monnaie');
  await p.reveal('tile_rate', alignment: 0.7);
  await p.moveTo('tile_tax', at: const Alignment(-0.5, 0));
  await p.wait(700);
  p.say('Aide : ce tutoriel, disponible à tout moment');
  await p.reveal('tile_tutorial', alignment: 0.8);
  await p.moveTo('tile_tutorial', at: const Alignment(-0.5, 0));
  await p.wait(1100);
}

// ═════════════════════════════════════════════════════════════════════════════
// Tous les comptes
// ═════════════════════════════════════════════════════════════════════════════

const _accountPeople = [
  demoU,
  demoV,
  demoY,
  demoZ,
  demoX,
  demoW,
];

Widget accountsScene(BuildContext context, DemoController c) {
  final target = c.text('target');
  final targetPerson =
      _accountPeople.where((p) => p.username == target).firstOrNull;

  return Stack(
    fit: StackFit.expand,
    children: [
      DemoPages(
        page: c.page,
        builder: (page) => switch (page) {
          'profile' => _DemoPublicProfile(c: c, person: demoY),
          'avatar' => DemoAvatarReview(c: c),
          _ => _DemoAccountsList(c: c),
        },
      ),
      DemoMenuLayer(
        controller: c,
        rect: c.get<Rect>('menuRect'),
        items: [
          const MockMenuItem(
            'm_credit',
            Icons.add_circle_outline,
            'Créditer',
            color: AppTheme.positive,
          ),
          const MockMenuItem(
            'm_debit',
            Icons.remove_circle_outline,
            'Débiter',
            color: AppTheme.negative,
          ),
          if (c.flag('targetBanned'))
            const MockMenuItem(
              'm_ban',
              Icons.lock_open_rounded,
              'Débannir',
              color: AppTheme.positive,
            )
          else
            const MockMenuItem(
              'm_ban',
              Icons.block_rounded,
              'Bannir',
              color: AppTheme.warning,
            ),
          const MockMenuItem(
            'm_reset',
            Icons.key_rounded,
            'Réinitialiser le mot de passe',
            color: AppTheme.info,
          ),
          const MockMenuItem(
            'm_delete',
            Icons.delete_rounded,
            'Supprimer',
            color: AppTheme.negative,
          ),
        ],
      ),
      DemoModal(
        open: c.get('dialog') == 'credit',
        child: AlertDialog(
          title: const Text('Créditer le compte'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              c.mark(
                'f_amount',
                MockField(
                  label: 'Montant',
                  suffix: 'SC',
                  value: c.text('amount'),
                  focused: c.get('focus') == 'amount',
                ),
              ),
              const SizedBox(height: 12),
              c.mark(
                'f_reason',
                MockField(
                  label: 'Raison',
                  value: c.text('reason'),
                  focused: c.get('focus') == 'reason',
                ),
              ),
            ],
          ),
          actions: [
            const TextButton(onPressed: demoNoop, child: Text('Annuler')),
            c.mark(
              'apply',
              const FilledButton(onPressed: demoNoop, child: Text('Appliquer')),
            ),
          ],
        ),
      ),
      DemoModal(
        open: c.get('dialog') == 'ban',
        child: AppDialog(
          icon: Icons.gavel_rounded,
          tone: AppDialogTone.danger,
          title: 'Suspendre ${userHandle(target)}',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              c.mark(
                'f_banReason',
                MockField(
                  label: 'Motif',
                  value: c.text('banReason'),
                  focused: c.get('focus') == 'banReason',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Durée',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final (i, label) in const [
                    '1 heure',
                    '24 heures',
                    '7 jours',
                    'Sans terme',
                    'Personnalisée',
                  ].indexed)
                    c.mark(
                      'chip_$i',
                      MockChoice(
                        label,
                        selected: (c.get<int>('banChoice') ?? 1) == i,
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            const TextButton(onPressed: demoNoop, child: Text('Annuler')),
            c.mark(
              'suspend',
              FilledButton(
                onPressed: demoNoop,
                style: _dangerFilled(),
                child: const Text('Suspendre'),
              ),
            ),
          ],
        ),
      ),
      DemoModal(
        open: c.get('dialog') == 'reset',
        child: AppDialog(
          icon: Icons.key_rounded,
          title: 'Réinitialiser le mot de passe',
          subtitle: userHandle(target),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              c.mark(
                'f_password',
                MockField(
                  label: 'Nouveau mot de passe',
                  helper: '8 caractères minimum',
                  value: c.text('password'),
                  focused: c.get('focus') == 'password',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Le nouveau mot de passe devra être communiqué au titulaire '
                'du compte : il ne lui sera pas envoyé.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            const TextButton(onPressed: demoNoop, child: Text('Annuler')),
            c.mark(
              'doReset',
              const FilledButton(
                onPressed: demoNoop,
                child: Text('Réinitialiser'),
              ),
            ),
          ],
        ),
      ),
      DemoModal(
        open: c.get('dialog') == 'delete',
        child: AlertDialog(
          title: const Text('Supprimer le compte'),
          content: Text(
            'Supprimer définitivement le compte de '
            '${targetPerson?.name ?? target} ?\nCette action est irréversible.',
          ),
          actions: [
            const TextButton(onPressed: demoNoop, child: Text('Annuler')),
            c.mark(
              'doDelete',
              FilledButton(
                onPressed: demoNoop,
                style: _dangerFilled(),
                child: const Text('Supprimer'),
              ),
            ),
          ],
        ),
      ),
      DemoModal(
        open: c.flag('photoZoom'),
        child: Dialog(
          clipBehavior: Clip.antiAlias,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
          child: Stack(
            children: [
              const AspectRatio(aspectRatio: 1, child: MockPhoto(radius: 0)),
              Positioned(
                top: 10,
                right: 10,
                child: c.mark(
                  'closeZoom',
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _DemoAccountsList extends StatelessWidget {
  const _DemoAccountsList({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final me = DemoIdentity.of(context);
    final query = c.text('query').toLowerCase();
    final deleted = c.get<List<String>>('deleted') ?? const <String>[];

    bool shown(DemoPerson p) =>
        !deleted.contains(p.username) &&
        (query.isEmpty ||
            p.name.toLowerCase().contains(query) ||
            p.username.contains(query));

    final count = _accountPeople.where(shown).length + (query.isEmpty ? 1 : 0);

    return MockScreen(
      title: 'Tous les comptes',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: c.mark(
              'search',
              MockField(
                hint: 'Rechercher un compte…',
                prefixIcon: Icons.search_rounded,
                value: c.text('query'),
                focused: c.flag('searchFocus'),
                dense: true,
                suffixIcon: query.isEmpty
                    ? null
                    : const Icon(Icons.close_rounded, size: 18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                Text(
                  '$count compte${count > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.accent,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: c.scroller('accounts'),
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _Collapse(
                  visible: query.isEmpty,
                  child: _DemoAccountCard(
                    c: c,
                    name: me.name,
                    username: me.username,
                    balance: 999999,
                    isMe: true,
                  ),
                ),
                for (final person in _accountPeople)
                  _Collapse(
                    visible: shown(person),
                    child: _DemoAccountCard(
                      c: c,
                      name: person.name,
                      username: person.username,
                      balance: person.balance,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoAccountCard extends StatelessWidget {
  const _DemoAccountCard({
    required this.c,
    required this.name,
    required this.username,
    required this.balance,
    this.isMe = false,
  });

  final DemoController c;
  final String name;
  final String username;
  final double balance;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;
    final banned =
        (c.get<List<String>>('banned') ?? const <String>[]).contains(username);
    final photo = c.flag('photoPending') && username == demoV.username;
    final value =
        (c.get<Map<String, double>>('balances') ?? const {})[username] ??
            balance;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: c.mark(
        'card_$username',
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                UserAvatar(username: username, radius: 21),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            MockPill('Admin', color: accent, square: true),
                          ],
                          if (banned) ...[
                            const SizedBox(width: 6),
                            const MockPill(
                              'Banni',
                              color: AppTheme.negative,
                              square: true,
                            ),
                          ],
                          if (photo) ...[
                            const SizedBox(width: 6),
                            c.mark(
                              'photoBadge',
                              const MockPill(
                                'Photo',
                                color: AppTheme.warning,
                                square: true,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              userHandle(username),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DemoAmount(
                            value: value,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isMe)
                  const SizedBox(width: 40)
                else
                  c.mark(
                    'dots_$username',
                    IconButton(
                      onPressed: demoNoop,
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoPublicProfile extends StatelessWidget {
  const _DemoPublicProfile({required this.c, required this.person});

  final DemoController c;
  final DemoPerson person;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return MockScreen(
      title: userHandle(person.username),
      body: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          c.mark(
            'profileHeader',
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1A1A2E),
                    Color.lerp(const Color(0xFF16213E), accent, 0.22)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  UserAvatar(username: person.username, radius: 28),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userHandle(person.username),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            '${DemoAmount.format(person.balance)} SC',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: accent,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Transactions récentes',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          GlobalTransactionTile(
            transaction: demoFeedTx(
              id: 'pp-1',
              type: TransactionType.transfer,
              amount: 12,
              from: person,
              to: demoX,
              description: 'Remboursement cantine',
              method: 'qr',
            ),
          ),
          const SizedBox(height: 12),
          GlobalTransactionTile(
            transaction: demoFeedTx(
              id: 'pp-2',
              type: TransactionType.reward,
              amount: 25,
              to: person,
              description: 'Bravo pour le projet',
              ago: const Duration(days: 2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Validation d'une photo de profil (aussi ouverte depuis la notification).
class DemoAvatarReview extends StatelessWidget {
  const DemoAvatarReview({super.key, required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget panel(String label, Widget child) => Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        );

    return MockScreen(
      title: 'Validation de photo',
      body: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    demoV.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userHandle(demoV.username),
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: panel(
                          'Photo actuelle',
                          Center(
                            child: UserAvatar(
                              username: demoV.username,
                              radius: 46,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: panel(
                          'Nouvelle photo',
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              c.mark(
                                'newPhoto',
                                const AspectRatio(
                                  aspectRatio: 1,
                                  child: MockPhoto(),
                                ),
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: c.mark(
                                  'expand',
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: context.accent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.colorScheme.surface,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.open_in_full_rounded,
                                      size: 12,
                                      color: context.onAccent,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomBar: _bottomAction(
        Row(
          children: [
            Expanded(
              child: c.mark(
                'refusePhoto',
                OutlinedButton.icon(
                  onPressed: demoNoop,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Refuser'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.negative,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: c.mark(
                'approvePhoto',
                FilledButton.icon(
                  onPressed: demoNoop,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Approuver'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openAccountMenu(DemoPlayer p, String username) async {
  p.set('target', username);
  await p.tap('dots_$username');
  p.set('menuRect', p.rectOf('dots_$username'));
  await p.wait(320);
}

Future<void> playSearchAccounts(DemoPlayer p) async {
  p.say('Toucher la barre de recherche');
  await p.tap('search');
  p.set('searchFocus', true);
  p.say('Taper un nom ou un identifiant : liste filtrée en direct');
  await p.type('query', 'y', perChar: 130);
  await p.wait(900);
  p.say('Toucher le compte pour ouvrir sa fiche');
  await p.tap('card_utilisateur.y', at: const Alignment(-0.4, 0));
  p
    ..set('searchFocus', false)
    ..set('page', 'profile');
  await p.wait(900);
  p.say('La fiche : solde et transactions récentes du compte');
  await p.moveTo('profileHeader', at: const Alignment(0.2, 0.3));
  await p.wait(1500);
}

Future<void> playCredit(DemoPlayer p) async {
  p.say('Toucher ⋮ à droite du compte');
  await _openAccountMenu(p, 'utilisateur.y');
  p.say('Choisir « Créditer » (ou « Débiter » pour retirer)');
  await p.tap('m_credit');
  p
    ..set('menuRect', null)
    ..set('dialog', 'credit');
  await p.wait(450);
  p.say('Saisir le montant');
  await p.tap('f_amount');
  p.set('focus', 'amount');
  await p.type('amount', '20', perChar: 160);
  p.say('Puis la raison, visible dans l\'historique du compte');
  await p.tap('f_reason');
  p.set('focus', 'reason');
  await p.type('reason', 'Exposé réussi');
  await p.wait(300);
  p.say('Valider avec « Appliquer »');
  await p.tap('apply');
  p
    ..set('focus', null)
    ..set('dialog', null)
    ..set('balances', {'utilisateur.y': 107.0});
  await p.wait(300);
  await p.toast('+20.00 SC appliqué.');
}

Future<void> playBan(DemoPlayer p) async {
  p.say('Toucher ⋮ puis « Bannir »');
  await _openAccountMenu(p, 'utilisateur.z');
  await p.tap('m_ban');
  p
    ..set('menuRect', null)
    ..set('dialog', 'ban');
  await p.wait(450);
  p.say('Écrire le motif, affiché sur l\'accueil du compte');
  await p.tap('f_banReason');
  p.set('focus', 'banReason');
  await p.type('banReason', 'Insultes dans le chat');
  p.say('Choisir la durée : ici 7 jours');
  await p.tap('chip_2');
  p.set('banChoice', 2);
  await p.wait(500);
  p.say('« Suspendre » applique la mesure immédiatement');
  await p.tap('suspend');
  p
    ..set('focus', null)
    ..set('dialog', null)
    ..set('banned', ['utilisateur.z']);
  await p.toast('Compte suspendu, levée automatique.', ms: 1900);
  p.say('Pour lever plus tôt : ⋮ puis « Débannir »');
  p.set('targetBanned', true);
  await _openAccountMenu(p, 'utilisateur.z');
  await p.tap('m_ban');
  p
    ..set('menuRect', null)
    ..set('banned', <String>[]);
  await p.toast('Compte débanni.');
}

Future<void> playResetPassword(DemoPlayer p) async {
  p.say('Toucher ⋮ puis « Réinitialiser le mot de passe »');
  await _openAccountMenu(p, 'utilisateur.x');
  await p.tap('m_reset');
  p
    ..set('menuRect', null)
    ..set('dialog', 'reset');
  await p.wait(450);
  p.say('Taper le nouveau mot de passe (8 caractères minimum)');
  await p.tap('f_password');
  p.set('focus', 'password');
  await p.type('password', 'Soleil2026', perChar: 90);
  await p.wait(400);
  p.say('« Réinitialiser », puis communiquer ce mot de passe au titulaire');
  await p.tap('doReset');
  p
    ..set('focus', null)
    ..set('dialog', null);
  await p.toast('Mot de passe réinitialisé.');
}

Future<void> playDeleteAccount(DemoPlayer p) async {
  p.say('Toucher ⋮ puis « Supprimer »');
  await _openAccountMenu(p, 'utilisateur.u');
  await p.tap('m_delete');
  p
    ..set('menuRect', null)
    ..set('dialog', 'delete');
  await p.wait(500);
  p.say('Confirmer : la suppression est définitive');
  await p.wait(700);
  await p.tap('doDelete');
  p
    ..set('dialog', null)
    ..set('deleted', ['utilisateur.u']);
  await p.wait(300);
  await p.toast('Compte supprimé.');
}

Future<void> playPhotoReview(DemoPlayer p) async {
  p.say('La pastille « Photo » : une nouvelle photo attend une validation');
  await p.moveTo('photoBadge');
  await p.wait(1000);
  await p.tap('photoBadge');
  p.set('page', 'avatar');
  await p.wait(900);
  p.say('À gauche la photo actuelle, à droite la nouvelle');
  await p.moveTo('newPhoto');
  await p.wait(1000);
  p.say('La flèche agrandit la nouvelle photo');
  await p.tap('expand');
  p.set('photoZoom', true);
  await p.wait(1400);
  await p.tap('closeZoom');
  p.set('photoZoom', false);
  await p.wait(450);
  p.say('« Approuver » : photo publiée. « Refuser » : photo rejetée');
  await p.tap('approvePhoto');
  p
    ..set('photoPending', false)
    ..set('page', 'list');
  await p.toast('Photo approuvée.');
}

// ═════════════════════════════════════════════════════════════════════════════
// Demandes de compte
// ═════════════════════════════════════════════════════════════════════════════

const _demoT = DemoPerson('Utilisateur T', 'utilisateur.t', 0);
const _demoClasses = ['Terminale B', 'Première A', 'Terminale C'];

Widget requestsScene(BuildContext context, DemoController c) {
  return Stack(
    fit: StackFit.expand,
    children: [
      MockScreen(
        title: 'Demandes de compte',
        actions: const [MockIcon(Icons.refresh_rounded)],
        body: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _Collapse(
              visible: !c.flag('approved'),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: c.mark(
                  'req_lea',
                  _DemoRequestCard(c: c, person: demoX, id: 'lea'),
                ),
              ),
            ),
            _DemoRequestCard(
              c: c,
              person: _demoT,
              id: 'jade',
              className: 'Première A',
            ),
          ],
        ),
      ),
      DemoModal(
        open: c.get('dialog') == 'approve',
        child: AppDialog(
          icon: Icons.how_to_reg_rounded,
          title: 'Approuver le compte',
          subtitle: userHandle(demoX.username),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Solde initial à attribuer :'),
              const SizedBox(height: 8),
              c.mark(
                'f_balance',
                MockField(
                  suffix: 'SC',
                  value: c.text('balance'),
                  focused: c.get('focus') == 'balance',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Classe :',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  c.mark(
                    'cls_none',
                    MockChoice('Aucune', selected: c.get('dlgClass') == null),
                  ),
                  for (final name in _demoClasses)
                    c.mark(
                      'cls_$name',
                      MockChoice(name, selected: c.get('dlgClass') == name),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            const TextButton(onPressed: demoNoop, child: Text('Annuler')),
            c.mark(
              'doApprove',
              const ElevatedButton(
                onPressed: demoNoop,
                child: Text('Approuver'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _DemoRequestCard extends StatelessWidget {
  const _DemoRequestCard({
    required this.c,
    required this.person,
    required this.id,
    this.className,
  });

  final DemoController c;
  final DemoPerson person;
  final String id;
  final String? className;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipOval(
                      child: MockPhoto(
                        size: 56,
                        radius: 28,
                        colors: id == 'lea'
                            ? const [Color(0xFF00B894), Color(0xFF0984E3)]
                            : const [Color(0xFFFDAC5D), Color(0xFFE17055)],
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.open_in_full_rounded,
                          size: 12,
                          color: context.onAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        userHandle(person.username),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.school_rounded, size: 14, color: accent),
                            const SizedBox(width: 4),
                            Text(
                              className ?? 'Aucune classe',
                              style: TextStyle(
                                fontSize: 12,
                                color: accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.edit_rounded, size: 12, color: accent),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: c.mark(
                    'reject_$id',
                    OutlinedButton(
                      onPressed: demoNoop,
                      style: _dangerOutlined(),
                      child: const Text('Refuser'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: c.mark(
                    'approve_$id',
                    const ElevatedButton(
                      onPressed: demoNoop,
                      child: Text('Approuver'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> playApproveRequest(DemoPlayer p) async {
  p.say('Chaque demande : photo, nom, identifiant et classe choisie');
  await p.moveTo('req_lea', at: const Alignment(-0.2, -0.45));
  await p.wait(1100);
  p.say('« Approuver » ouvre la validation');
  await p.tap('approve_lea');
  p.set('dialog', 'approve');
  await p.wait(450);
  p.say('Le solde de départ : 100 SC proposés, modifiable');
  await p.tap('f_balance');
  p
    ..set('focus', 'balance')
    ..set('balance', '');
  await p.type('balance', '150', perChar: 140);
  p.say('La classe de l\'utilisateur');
  await p.tap('cls_Terminale B');
  p
    ..set('focus', null)
    ..set('dlgClass', 'Terminale B');
  await p.wait(500);
  p.say('« Approuver » : le compte est créé tout de suite');
  await p.tap('doApprove');
  p
    ..set('dialog', null)
    ..set('approved', true);
  await p.wait(300);
  await p.toast('Compte approuvé avec 150.0 SC !');
}

// ═════════════════════════════════════════════════════════════════════════════
// Signalements
// ═════════════════════════════════════════════════════════════════════════════

Widget reportsScene(BuildContext context, DemoController c) {
  final reviewed = c.flag('reviewed');
  final showAll = c.flag('showAll');
  return MockScreen(
    title: 'Signalements',
    actions: [
      c.mark(
        'filter',
        TextButton(
          onPressed: demoNoop,
          child: Text(
            showAll ? 'Tous' : 'En attente',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ],
    body: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _Collapse(
          visible: !reviewed || showAll,
          child: _DemoReportCard(c: c, pending: !reviewed),
        ),
        if (reviewed && !showAll)
          const SizedBox(
            height: 320,
            child: EmptyState(
              icon: Icons.verified_user_rounded,
              title: 'Aucun signalement en attente',
              subtitle: 'Les nouveaux signalements apparaîtront ici',
            ),
          ),
      ],
    ),
  );
}

class _DemoReportCard extends StatelessWidget {
  const _DemoReportCard({required this.c, required this.pending});

  final DemoController c;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const severity = AppTheme.warning;
    final onVariant = theme.colorScheme.onSurfaceVariant;

    Widget line(IconData icon, String label, Color color, Widget child) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 82,
              child: Text(
                label,
                style: TextStyle(fontSize: 11.5, color: onVariant),
              ),
            ),
            Expanded(child: child),
          ],
        );

    Widget reporter(String username) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            userHandle(username),
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                c.mark(
                  'severity',
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: severity.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag_rounded, size: 13, color: severity),
                        SizedBox(width: 5),
                        Text(
                          '3 signalements',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: severity,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (!pending)
                  Text(
                    'traité',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: onVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            c.mark(
              'reportedMessage',
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'fais gaffe en rentrant chez toi',
                  style: TextStyle(fontSize: 13.5, height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            line(
              Icons.person_rounded,
              'Auteur',
              AppTheme.negative,
              Text(
                userHandle(demoW.username),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 6),
            line(
              Icons.flag_outlined,
              'Signalé par',
              onVariant,
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  reporter(demoX.username),
                  reporter(demoY.username),
                  reporter(demoV.username),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Premier signalement '
              '${_dateFmt.format(DateTime.now().subtract(const Duration(hours: 3)))}',
              style: TextStyle(fontSize: 11, color: onVariant),
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: c.mark(
                    'export',
                    OutlinedButton.icon(
                      onPressed: demoNoop,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Discussion'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: onVariant,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                if (pending) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: c.mark(
                      'markReviewed',
                      OutlinedButton.icon(
                        onPressed: demoNoop,
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Traité'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.positive,
                          side: BorderSide(
                            color: AppTheme.positive.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (pending) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: c.mark(
                  'banReport',
                  FilledButton.icon(
                    onPressed: demoNoop,
                    icon: const Icon(Icons.block_rounded, size: 16),
                    label: const Text('Bannir'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.negative,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> playReports(DemoPlayer p) async {
  p.say('Le nombre de signalements du message (orange : 3 ou 4)');
  await p.moveTo('severity');
  await p.wait(1000);
  p.say('Le message, son auteur et les utilisateurs qui l\'ont signalé');
  await p.moveTo('reportedMessage');
  await p.wait(1200);
  p.say('« Discussion » : toute la conversation dans un fichier texte');
  await p.tap('export');
  await p.toast('Discussion enregistrée (Téléchargements).', ms: 1700);
  p.say('« Bannir » ouvrirait la suspension, motif déjà rempli');
  await p.moveTo('banReport');
  await p.wait(1100);
  p.say('« Traité » retire le signalement de la file d\'attente');
  await p.tap('markReviewed');
  p.set('reviewed', true);
  await p.toast('Signalement traité.', ms: 1500);
  p.say('« En attente » ↔ « Tous » : revoir les signalements déjà traités');
  await p.tap('filter');
  p.set('showAll', true);
  await p.wait(1300);
}

// ═════════════════════════════════════════════════════════════════════════════
// Journal des sanctions
// ═════════════════════════════════════════════════════════════════════════════

Widget sanctionsScene(BuildContext context, DemoController c) {
  final me = DemoIdentity.of(context);
  final now = DateTime.now();
  return MockScreen(
    title: 'Journal des sanctions',
    body: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        c.mark(
          'sanc_ban',
          _DemoSanctionCard(
            c: c,
            id: 'ban',
            kind: 'ban',
            username: demoW.username,
            reason: 'Insultes répétées dans le chat',
            createdAt: now.subtract(const Duration(hours: 2)),
            until: now.add(const Duration(days: 7)),
            issuedBy: userHandle(me.username),
          ),
        ),
        c.mark(
          'sanc_mute',
          _DemoSanctionCard(
            c: c,
            id: 'mute',
            kind: 'mute',
            username: demoY.username,
            reason: '9 messages censurés en 24 h',
            createdAt: now.subtract(const Duration(hours: 5)),
            until: now.add(const Duration(hours: 19)),
            automatic: true,
          ),
        ),
        c.mark(
          'sanc_lifted',
          _DemoSanctionCard(
            c: c,
            id: 'lifted',
            kind: 'ban',
            username: demoU.username,
            reason: 'Messages répétés hors sujet',
            createdAt: now.subtract(const Duration(days: 3)),
            liftedAt: now.subtract(const Duration(days: 2)),
            issuedBy: userHandle(me.username),
          ),
        ),
      ],
    ),
  );
}

class _DemoSanctionCard extends StatelessWidget {
  const _DemoSanctionCard({
    required this.c,
    required this.id,
    required this.kind,
    required this.username,
    required this.reason,
    required this.createdAt,
    this.until,
    this.liftedAt,
    this.issuedBy,
    this.automatic = false,
  });

  final DemoController c;
  final String id;
  final String kind;
  final String username;
  final String reason;
  final DateTime createdAt;
  final DateTime? until;
  final DateTime? liftedAt;
  final String? issuedBy;
  final bool automatic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onVariant = theme.colorScheme.onSurfaceVariant;
    final (icon, color, label) = switch (kind) {
      'ban' => (Icons.block_rounded, AppTheme.negative, 'Compte suspendu'),
      'mute' => (Icons.volume_off_rounded, AppTheme.warning, 'Chat suspendu'),
      _ => (Icons.warning_amber_rounded, AppTheme.info, 'Avertissement'),
    };
    final lifted = liftedAt != null;

    Widget meta(IconData icon, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: onVariant),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(fontSize: 11, color: onVariant)),
          ],
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 7),
                        c.mark(
                          'status_$id',
                          MockPill(
                            lifted ? 'levée' : 'en cours',
                            color: lifted ? AppTheme.positive : color,
                            square: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      userHandle(username),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      reason,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: onVariant,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 10,
                      runSpacing: 3,
                      children: [
                        meta(
                            Icons.schedule_rounded, _dateFmt.format(createdAt)),
                        if (lifted)
                          meta(
                            Icons.lock_open_rounded,
                            'levée le ${_dateFmt.format(liftedAt!)}',
                          )
                        else if (until != null)
                          meta(
                            Icons.event_busy_rounded,
                            'jusqu\'au ${_dateFmt.format(until!)}',
                          ),
                        c.mark(
                          'by_$id',
                          meta(
                            automatic
                                ? Icons.smart_toy_rounded
                                : Icons.person_rounded,
                            automatic ? 'automatique' : (issuedBy ?? '@admin'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> playSanctions(DemoPlayer p) async {
  p.say('Une suspension de compte, encore « en cours »');
  await p.moveTo('status_ban');
  await p.wait(1100);
  p.say('Le motif, la date et la fin prévue de la mesure');
  await p.moveTo('sanc_ban', at: const Alignment(0.1, 0.45));
  await p.wait(1200);
  p.say('Le robot 🤖 : mesure prise automatiquement par l\'application');
  await p.moveTo('by_mute');
  await p.wait(1200);
  p.say('« levée » : la mesure est terminée');
  await p.moveTo('status_lifted');
  await p.wait(1200);
}

// ═════════════════════════════════════════════════════════════════════════════
// Gérer le marché
// ═════════════════════════════════════════════════════════════════════════════

PreferredSizeWidget _marketTabs(DemoController c) {
  const tabs = TabBar(
    tabs: [
      Tab(text: 'Boutique', icon: Icon(Icons.storefront_rounded)),
      Tab(text: 'Enchères', icon: Icon(Icons.gavel_rounded)),
    ],
  );
  return PreferredSize(
    preferredSize: tabs.preferredSize,
    child: c.mark('tabs', tabs),
  );
}

Widget marketAdminScene(BuildContext context, DemoController c) {
  return Stack(
    fit: StackFit.expand,
    children: [
      DemoPages(
        page: c.page,
        builder: (page) => switch (page) {
          'itemForm' => _DemoItemForm(c: c),
          'auctions' => _DemoAuctionsAdmin(c: c),
          'auctionForm' => _DemoAuctionForm(c: c),
          _ => _DemoShopAdmin(c: c),
        },
      ),
      DemoModal(
        sheet: true,
        open: c.get('sheet') == 'buyers',
        child: MockSheet(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Achats de Retrait d\'une absence',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                for (final (i, buyer) in const [demoX, demoU].indexed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: MockAvatar(buyer, radius: 18),
                    title: Text(buyer.name),
                    subtitle: Text(
                      'Retrait d\'une absence · x1 · '
                      '${_shortFmt.format(DateTime.now().subtract(Duration(days: i + 1)))}',
                    ),
                    trailing: Text(
                      '80.00 SC',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.accent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      DemoModal(
        sheet: true,
        open: c.get('sheet') == 'bids',
        child: MockSheet(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Historique de +1 point sur la dernière évaluation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Gagnant actuel : ${userHandle(demoX.username)} - 24.00 SC',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                for (final (person, amount) in const [
                  (demoX, 24.0),
                  (demoY, 22.0),
                  (demoZ, 15.0),
                ])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: MockAvatar(person, radius: 18),
                    title: Text(person.name),
                    subtitle: Text(userHandle(person.username)),
                    trailing: Text(
                      '${amount.toStringAsFixed(2)} SC',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: person == demoX ? context.accent : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _DemoShopAdmin extends StatelessWidget {
  const _DemoShopAdmin({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: MockScreen(
        title: 'Gérer le marché',
        bottom: _marketTabs(c),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: c.mark(
                  'addItem',
                  ElevatedButton.icon(
                    onPressed: demoNoop,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Ajouter une offre boutique'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _Collapse(
                    visible: c.flag('created'),
                    child: const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: _DemoItemCard(
                        id: 'new',
                        name: 'Joker devoir',
                        category: 'Privilèges',
                        price: 50,
                        stock: 10,
                        maxPerUser: 1,
                        description: 'Dispense d\'un devoir maison au choix.',
                      ),
                    ),
                  ),
                  _DemoItemCard(
                    c: c,
                    id: 'i0',
                    name: 'Retrait d\'une absence',
                    category: 'Privilèges',
                    price: c.number('price0', 80),
                    stock: 3,
                    maxPerUser: 1,
                    description:
                        'Quitter le cours cinq minutes avant la sonnerie.',
                  ),
                  const SizedBox(height: 10),
                  const _DemoItemCard(
                    id: 'i1',
                    name: 'Choisir sa place',
                    category: 'Privilèges',
                    price: 25,
                    stock: -1,
                    maxPerUser: -1,
                    description: 'Changer de place pour une journée.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoItemCard extends StatelessWidget {
  const _DemoItemCard({
    this.c,
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.maxPerUser,
    required this.description,
  });

  final DemoController? c;
  final String id;
  final String name;
  final String category;
  final double price;
  final int stock;
  final int maxPerUser;
  final String description;

  Widget _mark(String key, Widget child) =>
      c == null ? child : c!.mark('${id}_$key', child);

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    final neutral = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _mark(
                        'badges',
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            MockPill(category, color: accent),
                            MockPill(
                              stock == -1 ? 'Illimité' : '$stock restants',
                              color: stock == -1 || stock > 3
                                  ? neutral
                                  : AppTheme.negative,
                            ),
                            if (maxPerUser > 0)
                              MockPill('Max $maxPerUser/pers.', color: neutral),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                DemoAmount(
                  value: price,
                  style: TextStyle(fontWeight: FontWeight.w800, color: accent),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: neutral),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _mark(
                  'edit',
                  IconButton.outlined(
                    onPressed: demoNoop,
                    icon: const Icon(Icons.edit_rounded, size: 18),
                  ),
                ),
                const SizedBox(width: 8),
                _mark(
                  'history',
                  IconButton.outlined(
                    onPressed: demoNoop,
                    icon: const Icon(Icons.history_rounded, size: 18),
                  ),
                ),
                const Spacer(),
                _mark(
                  'delete',
                  OutlinedButton.icon(
                    onPressed: demoNoop,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.negative,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Supprimer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoItemForm extends StatelessWidget {
  const _DemoItemForm({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final editing = c.flag('editing');
    final focus = c.get<String>('focus');
    final accent = context.accent;

    MockField field(String key, String label,
            {String? suffix, int lines = 1}) =>
        MockField(
          label: label,
          suffix: suffix,
          maxLines: lines,
          value: c.text('f_$key'),
          focused: focus == key,
        );

    return MockScreen(
      title:
          editing ? 'Modifier une offre boutique' : 'Nouvelle offre boutique',
      body: ListView(
        controller: c.scroller('itemForm'),
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _FormSection(
            title: 'Informations',
            children: [
              c.mark('f_name', field('name', 'Nom')),
              const SizedBox(height: 12),
              c.mark('f_cat', field('cat', 'Catégorie')),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in const [
                    'Divers',
                    'Fournitures',
                    'Privilèges'
                  ])
                    c.mark(
                      'cat_$category',
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.30),
                          ),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              c.mark('f_price', field('price', 'Prix', suffix: 'SC')),
            ],
          ),
          const SizedBox(height: 16),
          _FormSection(
            title: 'Contenu',
            children: [
              field('desc', 'Description', lines: 3),
              const SizedBox(height: 12),
              c.mark('f_stock', field('stock', 'Stock')),
              const SizedBox(height: 12),
              c.mark('f_limit', field('limit', 'Limite par personne')),
              const SizedBox(height: 12),
              const MockField(label: 'URL image'),
              const SizedBox(height: 12),
              c.mark(
                'gallery',
                OutlinedButton.icon(
                  onPressed: demoNoop,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choisir depuis la galerie'),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomBar: _bottomAction(
        c.mark(
          'submitItem',
          FilledButton.icon(
            onPressed: demoNoop,
            icon: Icon(
              editing ? Icons.save_rounded : Icons.add_business_rounded,
            ),
            label: Text(editing ? 'Enregistrer l’offre' : 'Créer l’offre'),
          ),
        ),
      ),
    );
  }
}

class _DemoAuctionsAdmin extends StatelessWidget {
  const _DemoAuctionsAdmin({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: 1,
      child: MockScreen(
        title: 'Gérer le marché',
        bottom: _marketTabs(c),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: c.mark(
                  'addAuction',
                  ElevatedButton.icon(
                    onPressed: demoNoop,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Créer une enchère'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  _Collapse(
                    visible: c.flag('auctionCreated'),
                    child: const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: _DemoAuctionAdminCard(
                        id: 'a1',
                        name: 'Place au premier rang',
                        price: 20,
                        remaining: Duration(hours: 1, minutes: 30),
                      ),
                    ),
                  ),
                  _DemoAuctionAdminCard(
                    c: c,
                    id: 'a0',
                    name: '+1 point sur la dernière évaluation',
                    price: 24,
                    leader: demoX.username,
                    emoji: '🔥',
                    remaining: const Duration(minutes: 3, seconds: 40),
                    ended: c.flag('auctionEnded'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoAuctionAdminCard extends StatefulWidget {
  const _DemoAuctionAdminCard({
    this.c,
    required this.id,
    required this.name,
    required this.price,
    required this.remaining,
    this.leader,
    this.emoji,
    this.ended = false,
  });

  final DemoController? c;
  final String id;
  final String name;
  final double price;
  final Duration remaining;
  final String? leader;
  final String? emoji;
  final bool ended;

  @override
  State<_DemoAuctionAdminCard> createState() => _DemoAuctionAdminCardState();
}

class _DemoAuctionAdminCardState extends State<_DemoAuctionAdminCard> {
  late final DateTime _endsAt = DateTime.now().add(widget.remaining);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _mark(String key, Widget child) =>
      widget.c == null ? child : widget.c!.mark('${widget.id}_$key', child);

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    final neutral = Theme.of(context).colorScheme.onSurfaceVariant;
    final active = !widget.ended;
    var left = _endsAt.difference(DateTime.now());
    if (left.isNegative) left = Duration.zero;
    final urgent = left.inMinutes < 5 && active;
    String two(int v) => v.toString().padLeft(2, '0');
    final remainingLabel =
        '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _mark(
                        'badges',
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            MockPill(
                              active ? 'Active' : 'Terminée',
                              color: active ? AppTheme.positive : accent,
                            ),
                            MockPill(
                              'Fin ${_shortFmt.format(_endsAt)}',
                              color: neutral,
                            ),
                            if (active)
                              MockPill(
                                'Temps restant $remainingLabel',
                                color: urgent ? AppTheme.negative : accent,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${widget.price.toStringAsFixed(2)} SC',
                  style: TextStyle(fontWeight: FontWeight.w800, color: accent),
                ),
              ],
            ),
            if (widget.leader != null) ...[
              const SizedBox(height: 8),
              _mark(
                'leader',
                Text(
                  'En tête : ${userHandle(widget.leader)}'
                  '${widget.emoji != null ? ' ${widget.emoji}' : ''}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _mark(
                  'history',
                  IconButton.outlined(
                    onPressed: demoNoop,
                    icon: const Icon(Icons.history_rounded, size: 18),
                  ),
                ),
                if (active)
                  _mark(
                    'cancel',
                    const OutlinedButton(
                      onPressed: demoNoop,
                      child: Text('Annuler'),
                    ),
                  ),
                _mark(
                  'delete',
                  OutlinedButton.icon(
                    onPressed: demoNoop,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.negative,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Supprimer'),
                  ),
                ),
                if (active)
                  _mark(
                    'finalize',
                    const ElevatedButton(
                      onPressed: demoNoop,
                      child: Text('Clôturer'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoAuctionForm extends StatelessWidget {
  const _DemoAuctionForm({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final focus = c.get<String>('focus');
    MockField field(String key, String label,
            {String? suffix, int lines = 1}) =>
        MockField(
          label: label,
          suffix: suffix,
          maxLines: lines,
          value: c.text('a_$key'),
          focused: focus == key,
        );

    return MockScreen(
      title: 'Nouvelle enchère',
      body: ListView(
        controller: c.scroller('auctionForm'),
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _FormSection(
            title: 'Objet',
            children: [
              c.mark('a_name', field('name', 'Nom de l’objet')),
              const SizedBox(height: 12),
              c.mark('a_desc', field('desc', 'Description', lines: 3)),
              const SizedBox(height: 12),
              const MockField(label: 'URL image'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: demoNoop,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choisir depuis la galerie'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FormSection(
            title: 'Durée',
            children: [
              c.mark('a_price', field('price', 'Prix de départ', suffix: 'SC')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: c.mark('a_hours', field('hours', 'Heures'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: c.mark('a_minutes', field('minutes', 'Minutes')),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      bottomBar: _bottomAction(
        c.mark(
          'submitAuction',
          FilledButton.icon(
            onPressed: demoNoop,
            icon: const Icon(Icons.gavel_rounded),
            label: const Text('Créer l’enchère'),
          ),
        ),
      ),
    );
  }
}

Future<void> playCreateItem(DemoPlayer p) async {
  p.say('Onglet Boutique : « Ajouter une offre boutique »');
  await p.tap('addItem');
  p.set('page', 'itemForm');
  await p.wait(800);
  p.say('Le nom de l\'offre');
  await p.tap('f_name');
  p.set('focus', 'name');
  await p.type('f_name', 'Joker devoir');
  p.say('La catégorie : toucher une catégorie existante, ou en écrire une');
  await p.tap('cat_Privilèges');
  p
    ..set('focus', null)
    ..set('f_cat', 'Privilèges');
  await p.wait(500);
  p.say('Le prix, en SC');
  await p.tap('f_price');
  p.set('focus', 'price');
  await p.type('f_price', '50', perChar: 150);
  p.say('Le stock : 10 exemplaires (-1 = illimité)');
  await p.reveal('f_stock', alignment: 0.4);
  await p.tap('f_stock');
  p
    ..set('focus', 'stock')
    ..set('f_stock', '');
  await p.type('f_stock', '10', perChar: 150);
  p.say('La limite par utilisateur : 1 (-1 = sans limite)');
  await p.tap('f_limit');
  p
    ..set('focus', 'limit')
    ..set('f_limit', '');
  await p.type('f_limit', '1', perChar: 150);
  p.set('focus', null);
  p.say('« Créer l\'offre » : mise en vente immédiate');
  await p.tap('submitItem');
  p
    ..set('page', 'shop')
    ..set('created', true);
  await p.wait(300);
  await p.toast('Offre boutique créée !');
}

Future<void> playManageItem(DemoPlayer p) async {
  p.say(
      'Les pastilles : catégorie, stock restant (rouge à 3 ou moins), limite');
  await p.moveTo('i0_badges');
  await p.wait(1300);
  p.say('🕘 « Historique » : qui a acheté, quand et à quel prix');
  await p.tap('i0_history');
  p.set('sheet', 'buyers');
  await p.wait(1900);
  p.set('sheet', null);
  await p.wait(450);
  p.say('✏️ ouvre le formulaire de l\'offre pour la modifier');
  await p.tap('i0_edit');
  p
    ..set('editing', true)
    ..set('f_name', 'Retrait d\'une absence')
    ..set('f_cat', 'Privilèges')
    ..set('f_price', '80')
    ..set('f_stock', '3')
    ..set('f_limit', '1')
    ..set('f_desc', 'Demande de retrait d\'une absence du dossier.')
    ..set('page', 'itemForm');
  await p.wait(800);
  p.say('Exemple : baisser le prix à 60 SC');
  await p.tap('f_price');
  p
    ..set('focus', 'price')
    ..set('f_price', '');
  await p.type('f_price', '60', perChar: 150);
  p.set('focus', null);
  p.say('« Enregistrer l\'offre »');
  await p.tap('submitItem');
  p
    ..set('page', 'shop')
    ..set('price0', 60.0);
  await p.wait(300);
  await p.toast('Offre boutique mise à jour.', ms: 1700);
  p.say('« Supprimer » retire l\'offre immédiatement, sans confirmation');
  await p.moveTo('i0_delete');
  await p.wait(1300);
}

Future<void> playCreateAuction(DemoPlayer p) async {
  p.say('Onglet « Enchères »');
  await p.tap('tabs', at: const Alignment(0.5, 0));
  p.set('page', 'auctions');
  await p.wait(800);
  p.say('« Créer une enchère »');
  await p.tap('addAuction');
  p.set('page', 'auctionForm');
  await p.wait(800);
  p.say('Le nom de l\'objet mis aux enchères');
  await p.tap('a_name');
  p.set('focus', 'name');
  await p.type('a_name', 'Place au premier rang');
  p.say('Le prix de départ');
  await p.reveal('a_price', alignment: 0.4);
  await p.tap('a_price');
  p.set('focus', 'price');
  await p.type('a_price', '20', perChar: 150);
  p.say('La durée : 1 h 30, à partir de maintenant');
  await p.tap('a_hours');
  p
    ..set('focus', 'hours')
    ..set('a_hours', '');
  await p.type('a_hours', '1', perChar: 150);
  await p.tap('a_minutes');
  p
    ..set('focus', 'minutes')
    ..set('a_minutes', '');
  await p.type('a_minutes', '30', perChar: 150);
  p.set('focus', null);
  p.say('« Créer l\'enchère » : visible tout de suite');
  await p.tap('submitAuction');
  p
    ..set('page', 'auctions')
    ..set('auctionCreated', true);
  await p.wait(300);
  await p.toast('Enchère créée !');
}

Future<void> playManageAuction(DemoPlayer p) async {
  p.say('Statut, date de fin et compte à rebours (rouge sous 5 minutes)');
  await p.moveTo('a0_badges');
  await p.wait(1300);
  p.say('Le meilleur enchérisseur, avec son émoji');
  await p.moveTo('a0_leader');
  await p.wait(1000);
  p.say('🕘 « Historique » : toutes les offres placées');
  await p.tap('a0_history');
  p.set('sheet', 'bids');
  await p.wait(1900);
  p.set('sheet', null);
  await p.wait(450);
  p.say('« Annuler » : arrêt sans gagnant, X est remboursé');
  await p.moveTo('a0_cancel');
  await p.wait(1100);
  p.say('« Clôturer » : fin de l\'enchère, victoire de X');
  await p.tap('a0_finalize');
  p.set('auctionEnded', true);
  await p.wait(1400);
}

// ═════════════════════════════════════════════════════════════════════════════
// Classes
// ═════════════════════════════════════════════════════════════════════════════

Widget classesScene(BuildContext context, DemoController c) {
  return Stack(
    fit: StackFit.expand,
    children: [
      DemoPages(
        page: c.page,
        builder: (page) =>
            page == 'detail' ? _DemoClassDetail(c: c) : _DemoClassList(c: c),
      ),
      DemoMenuLayer(
        controller: c,
        rect: c.get<Rect>('menuRect'),
        items: const [
          MockMenuItem('m_rename', Icons.edit_rounded, 'Renommer'),
          MockMenuItem(
            'm_deleteClass',
            Icons.delete_rounded,
            'Supprimer',
            color: AppTheme.negative,
          ),
        ],
      ),
      DemoModal(
        open: c.get('dialog') == 'create',
        child: AppDialog(
          icon: Icons.add_rounded,
          title: 'Nouvelle classe',
          content: c.mark(
            'f_class',
            MockField(
              label: 'Nom de la classe',
              value: c.text('className'),
              focused: c.get('focus') == 'class',
            ),
          ),
          actions: [
            const TextButton(onPressed: demoNoop, child: Text('Annuler')),
            c.mark(
              'doCreate',
              const FilledButton(onPressed: demoNoop, child: Text('Créer')),
            ),
          ],
        ),
      ),
      DemoModal(
        open: c.get('dialog') == 'addMember',
        child: _DemoAddMemberDialog(c: c),
      ),
    ],
  );
}

class _DemoClassList extends StatelessWidget {
  const _DemoClassList({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    return MockScreen(
      title: 'Gestion des classes',
      actions: const [MockIcon(Icons.refresh_rounded)],
      floatingActionButton: c.mark(
        'fab',
        FloatingActionButton.extended(
          heroTag: null,
          onPressed: demoNoop,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nouvelle classe'),
          backgroundColor: context.accent,
          foregroundColor: context.onAccent,
        ),
      ),
      body: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _DemoClassCard(c: c, name: 'Terminale B', members: 3),
          _DemoClassCard(c: c, name: 'Première A', members: 2),
          _Collapse(
            visible: c.flag('created'),
            child: _DemoClassCard(c: c, name: 'Terminale C', members: 0),
          ),
        ],
      ),
    );
  }
}

class _DemoClassCard extends StatelessWidget {
  const _DemoClassCard({
    required this.c,
    required this.name,
    required this.members,
  });

  final DemoController c;
  final String name;
  final int members;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: c.mark(
        'class_$name',
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 6, 13),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: accent.withValues(alpha: 0.25)),
                  ),
                  child: Icon(Icons.school_rounded, color: accent, size: 22),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.people_rounded,
                            size: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            members == 1 ? '1 membre' : '$members membres',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                c.mark(
                  'dots_$name',
                  IconButton(
                    onPressed: demoNoop,
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoClassDetail extends StatelessWidget {
  const _DemoClassDetail({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;
    final members = [
      demoX,
      demoY,
      demoU,
      if (c.flag('memberAdded')) demoW,
    ];

    return MockScreen(
      title: 'Terminale B',
      body: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1A1A2E),
                  Color.lerp(const Color(0xFF16213E), accent, 0.22)!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withValues(alpha: 0.55)),
                  ),
                  child: Icon(Icons.school_rounded, color: accent, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Terminale B',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${members.length} membres',
                        style: TextStyle(
                          color: accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                c.mark(
                  'classChat',
                  const IconButton(
                    onPressed: demoNoop,
                    icon: Icon(Icons.chat_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                'Membres',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              c.mark(
                'addMember',
                FilledButton.tonalIcon(
                  onPressed: demoNoop,
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Ajouter'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent.withValues(alpha: 0.14),
                    foregroundColor: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final member in members)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Row(
                    children: [
                      MockAvatar(member),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              userHandle(member.username),
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      c.mark(
                        'remove_${member.username}',
                        const IconButton(
                          onPressed: demoNoop,
                          icon: Icon(
                            Icons.person_remove_rounded,
                            color: AppTheme.negative,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DemoAddMemberDialog extends StatelessWidget {
  const _DemoAddMemberDialog({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    final onAccent = context.onAccent;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 56),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent, Color.lerp(accent, Colors.black, 0.24)!],
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.person_add_alt_1_rounded, size: 19, color: onAccent),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ajouter un membre',
                      style: TextStyle(
                        color: onAccent,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '2 utilisateur(s) sans classe',
                      style: TextStyle(
                        color: onAccent.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          for (final person in const [demoW, _demoT])
            c.mark(
              'pick_${person.username}',
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                child: Row(
                  children: [
                    MockAvatar(person, radius: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                          Text(
                            userHandle(person.username),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.add_circle_rounded, size: 21, color: accent),
                  ],
                ),
              ),
            ),
          const Divider(height: 1),
          const Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 4, 12, 6),
              child: TextButton(onPressed: demoNoop, child: Text('Annuler')),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> playClasses(DemoPlayer p) async {
  p.say('« Nouvelle classe », en bas à droite');
  await p.tap('fab');
  p.set('dialog', 'create');
  await p.wait(450);
  p.say('Le nom de la classe');
  await p.tap('f_class');
  p.set('focus', 'class');
  await p.type('className', 'Terminale C', perChar: 140);
  p.say('« Créer »');
  await p.tap('doCreate');
  p
    ..set('focus', null)
    ..set('dialog', null)
    ..set('created', true);
  await p.wait(1000);
  p.say('⋮ : « Renommer » ou « Supprimer » une classe');
  await p.tap('dots_Terminale B');
  p.set('menuRect', p.rectOf('dots_Terminale B'));
  await p.wait(1700);
  p.set('menuRect', null);
  await p.wait(300);
}

Future<void> playClassMembers(DemoPlayer p) async {
  p.say('Toucher une classe pour ouvrir sa fiche');
  await p.tap('class_Terminale B', at: const Alignment(-0.4, 0));
  p.set('page', 'detail');
  await p.wait(900);
  p.say('« Ajouter » : choisir parmi les utilisateurs sans classe');
  await p.tap('addMember');
  p.set('dialog', 'addMember');
  await p.wait(700);
  await p.tap('pick_utilisateur.w');
  p
    ..set('dialog', null)
    ..set('memberAdded', true);
  await p.wait(1000);
  p.say('L\'icône rouge retire un membre de la classe');
  await p.moveTo('remove_utilisateur.y');
  await p.wait(1200);
  p.say('La bulle, en haut : le chat de la classe');
  await p.moveTo('classChat');
  await p.wait(1200);
}

// ═════════════════════════════════════════════════════════════════════════════
// Prêts (administration)
// ═════════════════════════════════════════════════════════════════════════════

PreferredSizeWidget _loanTabs(DemoController c) {
  const tabs = TabBar(tabs: [Tab(text: 'Prêts'), Tab(text: 'Paramètres')]);
  return PreferredSize(
    preferredSize: tabs.preferredSize,
    child: c.mark('tabs', tabs),
  );
}

Widget loansAdminScene(BuildContext context, DemoController c) {
  return Stack(
    fit: StackFit.expand,
    children: [
      DemoPages(
        page: c.page,
        builder: (page) =>
            page == 'settings' ? _DemoLoanSettings(c: c) : _DemoLoanList(c: c),
      ),
      DemoModal(
        sheet: true,
        open: c.get('sheet') == 'loan',
        child: MockSheet(child: _DemoLoanDetail(c: c)),
      ),
    ],
  );
}

class _DemoLoanList extends StatelessWidget {
  const _DemoLoanList({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget party(String label, String username, Color color) => Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 82,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              userHandle(username),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ],
        );

    Widget tile(
            String id, double amount, DemoPerson lender, DemoPerson borrower) =>
        c.mark(
          id,
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const MockPill(
                              'Actif',
                              color: AppTheme.positive,
                              square: true,
                            ),
                            const SizedBox(width: 9),
                            Text(
                              '${amount.toStringAsFixed(2)} SC',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                color: context.accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        party('Prêteur', lender.username, AppTheme.positive),
                        const SizedBox(height: 4),
                        party(
                            'Emprunteur', borrower.username, AppTheme.negative),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.45),
                  ),
                ],
              ),
            ),
          ),
        );

    return DefaultTabController(
      length: 2,
      child: MockScreen(
        title: 'Prêts',
        bottom: _loanTabs(c),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: MockField(
                hint: 'Rechercher un utilisateur…',
                prefixIcon: Icons.search_rounded,
                dense: true,
              ),
            ),
            Expanded(
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  tile('loan0', 30, demoX, demoY),
                  const SizedBox(height: 8),
                  tile('loan1', 12.5, demoZ, demoU),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoLoanDetail extends StatelessWidget {
  const _DemoLoanDetail({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;
    final now = DateTime.now();

    Widget row(IconData icon, String label, String value, {Color? color}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Icon(icon,
                  size: 17, color: color ?? theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.18),
                  accent.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  '30.00 SC',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: accent,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                const MockPill('Actif', color: AppTheme.positive, square: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          row(
            Icons.arrow_upward_rounded,
            'Prêteur',
            userHandle(demoX.username),
            color: AppTheme.positive,
          ),
          row(
            Icons.arrow_downward_rounded,
            'Emprunteur',
            userHandle(demoY.username),
            color: AppTheme.negative,
          ),
          const Divider(height: 18),
          row(Icons.percent_rounded, 'Taux d\'intérêt', '5.0 %'),
          row(Icons.summarize_rounded, 'Total dû', '31.50 SC'),
          row(Icons.check_circle_outline_rounded, 'Déjà remboursé', '11.00 SC'),
          c.mark(
            'loanRemaining',
            row(
              Icons.hourglass_bottom_rounded,
              'Restant dû',
              '20.50 SC',
              color: AppTheme.warning,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.35,
              minHeight: 7,
              color: AppTheme.positive,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '35 % remboursé',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Divider(height: 18),
          row(
            Icons.event_rounded,
            'Échéance',
            _shortFmt.format(now.add(const Duration(days: 3))),
          ),
        ],
      ),
    );
  }
}

class _DemoLoanSettings extends StatelessWidget {
  const _DemoLoanSettings({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final focus = c.get<String>('focus');
    Widget section(String title, List<Widget> children) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: context.accent,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: children),
              ),
            ),
          ],
        );
    Widget field(String key, String label, String suffix) => c.mark(
          'f_$key',
          MockField(
            label: label,
            suffix: suffix,
            value: c.text(key),
            focused: focus == key,
            dense: true,
          ),
        );

    return DefaultTabController(
      length: 2,
      initialIndex: 1,
      child: MockScreen(
        title: 'Prêts',
        bottom: _loanTabs(c),
        body: ListView(
          controller: c.scroller('loanSettings'),
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            section('Limites d\'emprunt', [
              field('daily', 'Limite quotidienne', 'SC / jour'),
              const SizedBox(height: 12),
              field('weekly', 'Limite hebdomadaire', 'SC / semaine'),
              const SizedBox(height: 12),
              field('active', 'Prêts actifs simultanés max', 'prêts'),
            ]),
            const SizedBox(height: 16),
            section('Conditions', [
              field('duration', 'Durée maximale', 'jours'),
              const SizedBox(height: 12),
              field('interest', 'Taux d\'intérêt maximum', 'pourcent'),
              const SizedBox(height: 12),
              field('minBalance', 'Solde minimum pour emprunter', 'SC'),
            ]),
            const SizedBox(height: 20),
            c.mark(
              'saveLoans',
              ElevatedButton.icon(
                onPressed: demoNoop,
                icon: const Icon(Icons.save_rounded),
                label: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const loanSettingsInitial = <String, Object?>{
  'daily': '100',
  'weekly': '1000',
  'active': '3',
  'duration': '14',
  'interest': '100',
  'minBalance': '10',
};

Future<void> playLoansList(DemoPlayer p) async {
  p.say('Chaque ligne : statut, montant, prêteur (vert) et emprunteur (rouge)');
  await p.moveTo('loan0', at: const Alignment(-0.3, 0));
  await p.wait(1200);
  p.say('Toucher un prêt pour voir tout le détail');
  await p.tap('loan0');
  p.set('sheet', 'loan');
  await p.wait(1000);
  p.say('Total dû, déjà remboursé, restant dû, progression et échéance');
  await p.moveTo('loanRemaining');
  await p.wait(1700);
  p.set('sheet', null);
  await p.wait(350);
}

Future<void> playLoanSettings(DemoPlayer p) async {
  p.say('Onglet « Paramètres »');
  await p.tap('tabs', at: const Alignment(0.5, 0));
  p.set('page', 'settings');
  await p.wait(800);
  p.say('Exemple : limite quotidienne portée à 150 SC');
  await p.tap('f_daily');
  p
    ..set('focus', 'daily')
    ..set('daily', '');
  await p.type('daily', '150', perChar: 140);
  p.set('focus', null);
  await p.wait(300);
  p.say('« Enregistrer » : nouvelles règles valables pour toutes les demandes');
  await p.reveal('saveLoans', alignment: 0.6);
  await p.tap('saveLoans');
  await p.toast('Paramètres enregistrés.');
}

// ═════════════════════════════════════════════════════════════════════════════
// Taxe et récompense
// ═════════════════════════════════════════════════════════════════════════════

Widget taxScene(BuildContext context, DemoController c) {
  final focus = c.get<String>('focus');
  return Stack(
    fit: StackFit.expand,
    children: [
      MockScreen(
        title: 'Taxe globale',
        body: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            const AdminActionHeader(
              icon: Icons.percent_rounded,
              title: 'Prélèvement global',
              message: 'Cette action prélève un pourcentage sur tous les '
                  'comptes actifs. Opération irréversible.',
              color: AppTheme.negative,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    c.mark(
                      'f_percent',
                      MockField(
                        label: 'Pourcentage de taxe',
                        hint: 'Ex : 5',
                        prefixIcon: Icons.percent_rounded,
                        suffix: '%',
                        value: c.text('percent'),
                        focused: focus == 'percent',
                      ),
                    ),
                    const SizedBox(height: 14),
                    c.mark(
                      'f_taxReason',
                      MockField(
                        label: 'Raison (facultative)',
                        helper: 'Affichée aux utilisateurs',
                        prefixIcon: Icons.notes_rounded,
                        value: c.text('taxReason'),
                        focused: focus == 'taxReason',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomBar: _bottomAction(
          c.mark(
            'applyTax',
            FilledButton.icon(
              onPressed: demoNoop,
              icon: const Icon(Icons.percent_rounded),
              label: const Text('Appliquer la taxe'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.negative,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ),
      ),
      DemoModal(
        open: c.get('dialog') == 'confirmTax',
        child: AlertDialog(
          title: const Text('Confirmer la taxe'),
          content: const Text(
            'Appliquer une taxe de 10.0% sur tous les comptes ?',
          ),
          actions: [
            const TextButton(onPressed: demoNoop, child: Text('Annuler')),
            c.mark(
              'confirmTax',
              FilledButton(
                onPressed: demoNoop,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.negative,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Appliquer'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Future<void> playTax(DemoPlayer p) async {
  p.say('Le pourcentage prélevé sur chaque solde');
  await p.tap('f_percent');
  p.set('focus', 'percent');
  await p.type('percent', '10', perChar: 160);
  p.say('La raison (facultative), affichée aux utilisateurs');
  await p.tap('f_taxReason');
  p.set('focus', 'taxReason');
  await p.type('taxReason', 'Impôt de fin de trimestre');
  p.set('focus', null);
  p.say('« Appliquer la taxe »');
  await p.tap('applyTax');
  p.set('dialog', 'confirmTax');
  await p.wait(600);
  p.say('Confirmer : l\'opération est irréversible');
  await p.tap('confirmTax');
  p.set('dialog', null);
  await p.wait(300);
  await p.toast('Taxe de 10.0% appliquée !');
}

Widget rewardScene(BuildContext context, DemoController c) {
  final focus = c.get<String>('focus');
  return MockScreen(
    title: 'Distribuer une récompense',
    body: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        const AdminActionHeader(
          icon: Icons.card_giftcard_rounded,
          title: 'Distribution globale',
          message: 'Cette action crédite tous les comptes actifs avec le '
              'même montant, en une seule fois.',
          color: AppTheme.positive,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                c.mark(
                  'f_rewardAmount',
                  MockField(
                    label: 'Montant par personne',
                    prefixIcon: Icons.savings_rounded,
                    suffix: 'SC',
                    value: c.text('rewardAmount'),
                    focused: focus == 'rewardAmount',
                  ),
                ),
                const SizedBox(height: 14),
                c.mark(
                  'f_rewardReason',
                  MockField(
                    label: 'Raison affichée aux utilisateurs',
                    prefixIcon: Icons.notes_rounded,
                    value: c.text('rewardReason'),
                    focused: focus == 'rewardReason',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    bottomBar: _bottomAction(
      c.mark(
        'distribute',
        FilledButton.icon(
          onPressed: demoNoop,
          icon: const Icon(Icons.card_giftcard_rounded),
          label: const Text('Distribuer'),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.positive,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    ),
  );
}

Future<void> playReward(DemoPlayer p) async {
  p.say('Le montant crédité à chaque utilisateur');
  await p.tap('f_rewardAmount');
  p.set('focus', 'rewardAmount');
  await p.type('rewardAmount', '25', perChar: 160);
  p.say('La raison, facultative, affichée aux utilisateurs');
  await p.tap('f_rewardReason');
  p.set('focus', 'rewardReason');
  await p.type('rewardReason', 'Bravo pour le projet');
  p.set('focus', null);
  p.say('« Distribuer » : tous les comptes sont crédités, sans confirmation');
  await p.tap('distribute');
  await p.wait(300);
  await p.toast('Récompense distribuée.');
}

// ═════════════════════════════════════════════════════════════════════════════
// Modifier le cours
// ═════════════════════════════════════════════════════════════════════════════

Widget rateScene(BuildContext context, DemoController c) {
  final theme = Theme.of(context);
  final accent = theme.colorScheme.primary;
  final series = c.get<DemoSeries>('series') ?? DemoSeries.demand;
  final price = c.get<List<double>>('price') ?? demoPrice;
  final focus = c.get<String>('focus');
  final seriesColor = switch (series) {
    DemoSeries.demand => AppTheme.negative,
    DemoSeries.supply => AppTheme.positive,
    DemoSeries.price => accent,
  };

  return Stack(
    fit: StackFit.expand,
    children: [
      MockScreen(
        title: 'Modifier le cours',
        body: ListView(
          controller: c.scroller('rate'),
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.touch_app_rounded, color: accent, size: 21),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cours actuel : 2.0000 EUR',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: accent,
                            fontSize: 14.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Sélectionner une série, puis glisser sur le '
                          'graphique pour dessiner la courbe. Appui long sur '
                          'une colonne : valeur exacte.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            c.mark(
              'series',
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<DemoSeries>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor:
                        seriesColor.withValues(alpha: 0.16),
                    selectedForegroundColor: seriesColor,
                  ),
                  segments: const [
                    ButtonSegment(
                      value: DemoSeries.demand,
                      label: Text('Demande'),
                      icon: Icon(Icons.shopping_cart_rounded, size: 15),
                    ),
                    ButtonSegment(
                      value: DemoSeries.supply,
                      label: Text('Offre'),
                      icon: Icon(Icons.inventory_2_rounded, size: 15),
                    ),
                    ButtonSegment(
                      value: DemoSeries.price,
                      label: Text('Prix'),
                      icon: Icon(Icons.show_chart_rounded, size: 15),
                    ),
                  ],
                  selected: {series},
                  onSelectionChanged: (_) {},
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
                child: Column(
                  children: [
                    c.mark(
                      'chartArea',
                      DemoMarketChart(
                        demand: c.get<List<double>>('demand') ?? demoDemand,
                        supply: c.get<List<double>>('supply') ?? demoSupply,
                        price: price,
                        editing: series,
                        dragIndex: c.get<int>('dragIndex'),
                        height: 210,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (var i = 1; i <= 10; i++)
                          Expanded(
                            child: Center(
                              child: Text(
                                '$i',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: c.mark(
                    'restore',
                    OutlinedButton.icon(
                      onPressed: demoNoop,
                      icon: const Icon(Icons.restore_rounded, size: 17),
                      label: const Text('Rétablir'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: c.mark(
                    'zero',
                    OutlinedButton.icon(
                      onPressed: demoNoop,
                      icon: const Icon(Icons.layers_clear_rounded, size: 17),
                      label: const Text('Tout à zéro'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.negative,
                        side: BorderSide(
                          color: AppTheme.negative.withValues(alpha: 0.55),
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: c.mark(
                            'f_rate',
                            MockField(
                              label: 'Cours affiché (EUR)',
                              value: c.text('rate'),
                              focused: focus == 'rate',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        c.mark(
                          'arrow',
                          OutlinedButton(
                            onPressed: demoNoop,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_downward_rounded,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    c.mark(
                      'f_rateReason',
                      MockField(
                        label: 'Raison affichée aux utilisateurs',
                        value: c.text('rateReason'),
                        focused: focus == 'rateReason',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            c.mark(
              'applyRate',
              FilledButton.icon(
                onPressed: demoNoop,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Appliquer le nouveau cours'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
      DemoModal(
        open: c.get('dialog') == 'exact',
        child: AppDialog(
          icon: Icons.show_chart_rounded,
          title: 'Prix — point 10',
          content: c.mark(
            'f_exact',
            MockField(
              label: 'Valeur exacte',
              suffix: 'EUR',
              value: c.text('exact'),
              focused: focus == 'exact',
            ),
          ),
          actions: [
            const TextButton(onPressed: demoNoop, child: Text('Annuler')),
            c.mark(
              'validateExact',
              const FilledButton(onPressed: demoNoop, child: Text('Valider')),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Volumes dessinés par l'exemple : leur maximum laisse l'échelle du
/// graphique (0 à 500) inchangée pendant le tracé.
const _newDemand = <double>[40, 120, 150, 170, 190, 210, 200, 180, 160, 140];
const _newSupply = <double>[30, 100, 130, 150, 160, 170, 175, 165, 150, 140];
const _volumeScale = 500.0;

/// Glisse sur le graphique pour redessiner une série de colonnes.
Future<void> _drawVolumes(
  DemoPlayer p,
  Rect inner,
  String key,
  List<double> start,
  List<double> target,
) async {
  final values = List<double>.of(start);
  await p.drag(
    // Les colonnes occupent 85 % de la hauteur.
    demoColumnPath(inner, [for (final v in target) v / _volumeScale * 0.85]),
    onPoint: (i) {
      values[i] = target[i];
      p
        ..set(key, List<double>.of(values))
        ..set('dragIndex', i);
    },
  );
  p.set('dragIndex', null);
  await p.wait(400);
}

Future<void> playRate(DemoPlayer p) async {
  await p.reveal('chartArea', alignment: 0.25);
  final chart = p.rectOf('chartArea');
  if (chart != null) {
    // Même repère que le dessin : marges de 18 en haut, 4 en bas.
    final inner = Rect.fromLTRB(
      chart.left,
      chart.top + 18,
      chart.right,
      chart.bottom - 4,
    );

    p.say('1. Série « Demande » : glisser sur le graphique pour la dessiner');
    await p.tap('series', at: const Alignment(-0.67, 0));
    p.set('series', DemoSeries.demand);
    await p.wait(400);
    await _drawVolumes(p, inner, 'demand', demoDemand, _newDemand);

    p.say('2. Série « Offre » : même geste');
    await p.tap('series', at: const Alignment(0, 0));
    p.set('series', DemoSeries.supply);
    await p.wait(400);
    await _drawVolumes(p, inner, 'supply', demoSupply, _newSupply);

    p.say('3. Série « Prix » : la courbe suit le mouvement');
    await p.tap('series', at: const Alignment(0.67, 0));
    p.set('series', DemoSeries.price);
    await p.wait(400);
    // Prix : 94 % de la hauteur, sur un axe de 0 à 10 €.
    const shape = [0.11, 0.13, 0.17, 0.2, 0.25, 0.29, 0.34, 0.39, 0.44, 0.5];
    final values = List<double>.of(demoPrice);
    await p.drag(
      demoColumnPath(inner, [for (final t in shape) t * 0.94]),
      onPoint: (i) {
        values[i] = (shape[i] * 1000).roundToDouble() / 100;
        p
          ..set('price', List<double>.of(values))
          ..set('dragIndex', i);
      },
    );
    p.set('dragIndex', null);
    await p.wait(400);

    p.say('4. Appui long sur une colonne : saisir sa valeur exacte');
    await p
        .longPressAt(Offset(chart.left + chart.width * 0.95, chart.center.dy));
    p.set('dialog', 'exact');
    await p.wait(450);
    await p.tap('f_exact');
    p
      ..set('focus', 'exact')
      ..set('exact', '');
    await p.type('exact', '5.5', perChar: 160);
    await p.tap('validateExact');
    values[9] = 5.5;
    p
      ..set('focus', null)
      ..set('dialog', null)
      ..set('price', List<double>.of(values));
    await p.wait(700);
  }

  p.say('5. La flèche ↓ reprend le dernier prix comme cours affiché');
  await p.reveal('arrow', alignment: 0.5);
  await p.tap('arrow');
  p.set('rate', '5.5000');
  await p.wait(500);
  p.say('6. La raison, puis « Appliquer le nouveau cours »');
  await p.tap('f_rateReason');
  p.set('focus', 'rateReason');
  await p.type('rateReason', 'Forte demande au marché');
  p.set('focus', null);
  await p.reveal('applyRate', alignment: 0.7);
  await p.tap('applyRate');
  await p.toast('Cours fixé à 5.5000.');
}

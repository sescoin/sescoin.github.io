import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../common/app_dialog.dart';
import '../../../common/empty_state.dart';
import '../../../common/password_strength.dart';
import '../../../common/user_avatar.dart';
import '../../../core/app_fonts.dart';
import '../../../core/constants.dart' show TransactionType;
import '../../../core/theme.dart';
import '../../../loan/loan_card.dart';
import '../../../market/auction_card.dart';
import '../../../market/market_item_card.dart';
import '../../../models/app_notification.dart';
import '../../../models/auction.dart';
import '../../../models/loan.dart';
import '../../../models/maintenance_status.dart';
import '../../../models/marketplace_item.dart';
import '../../../notification/notification_tile.dart';
import '../../../providers/settings_provider.dart';
import '../../../transaction/global_transaction_tile.dart';
import '../../../transaction/transaction_tile.dart';
import '../../maintenance/maintenance_screen.dart';
import 'tutorial_engine.dart';
import 'tutorial_mock.dart';
import 'tutorial_scenes_admin.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Scènes du tutoriel : fonctions communes à tous les comptes (chat, argent,
// marché, prêts, profil, réglages, maintenance).
// ─────────────────────────────────────────────────────────────────────────────

const _demoJade = DemoPerson('Jade Morel', 'jade.morel', 0);

String _id(DemoPerson person) => 'demo-${person.username}';

// ═════════════════════════════════════════════════════════════════════════════
// Chat
// ═════════════════════════════════════════════════════════════════════════════

Widget chatScene(BuildContext context, DemoController c) {
  final focus = c.get<String>('focus');
  return Stack(
    fit: StackFit.expand,
    children: [
      DemoPages(
        page: c.page,
        builder: (page) =>
            page == 'class' ? _DemoClassChat(c: c) : _DemoAnnouncements(c: c),
      ),
      DemoModal(
        sheet: true,
        open: c.get('sheet') == 'annOptions',
        child: MockOptionsSheet(
          title: 'Options de l\'annonce',
          children: [
            c.mark(
              'opt_edit',
              const MockOptionTile(icon: Icons.edit_rounded, label: 'Modifier'),
            ),
            const MockOptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Supprimer',
              color: Colors.red,
            ),
          ],
        ),
      ),
      DemoModal(
        sheet: true,
        open: c.get('sheet') == 'msgOptions',
        child: MockOptionsSheet(
          title: 'Options du message',
          children: [
            const MockOptionTile(
              icon: Icons.flag_outlined,
              label: 'Signaler',
              color: AppTheme.warning,
            ),
            c.mark(
              'opt_deleteMsg',
              const MockOptionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Supprimer',
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
      DemoModal(
        open: c.get('dialog') == 'edit',
        child: AppDialog(
          icon: Icons.edit_rounded,
          title: 'Modifier l\'annonce',
          subtitle: 'Visible par toute la classe',
          content: c.mark(
            'f_edit',
            MockField(
              hint: 'Annonce',
              value: c.text('editText'),
              focused: focus == 'edit',
              maxLines: 3,
            ),
          ),
          actions: [
            const TextButton(onPressed: demoNoop, child: Text('Annuler')),
            c.mark(
              'saveEdit',
              const FilledButton(
                  onPressed: demoNoop, child: Text('Enregistrer')),
            ),
          ],
        ),
      ),
      DemoModal(
        open: c.get('dialog') == 'gift',
        child: _DemoGiftDialog(c: c),
      ),
      DemoModal(
        open: c.get('dialog') == 'deleteMsg',
        child: AppDialog(
          icon: Icons.delete_outline_rounded,
          tone: AppDialogTone.danger,
          title: 'Supprimer le message ?',
          subtitle: 'Cette action est définitive',
          content: const Text('Cette action est définitive.'),
          actions: [
            const TextButton(onPressed: demoNoop, child: Text('Annuler')),
            c.mark(
              'confirmDeleteMsg',
              FilledButton(
                onPressed: demoNoop,
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Supprimer'),
              ),
            ),
          ],
        ),
      ),
      DemoModal(
        sheet: true,
        open: c.get('sheet') == 'attach',
        child: MockOptionsSheet(
          title: 'Partager avec la classe',
          children: [
            c.mark(
              'opt_gift',
              const MockOptionTile(
                icon: Icons.card_giftcard_rounded,
                label: 'Envoyer un cadeau',
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _DemoAnnouncements extends StatelessWidget {
  const _DemoAnnouncements({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final me = DemoIdentity.of(context);
    return MockScreen(
      title: 'Annonces',
      back: false,
      navIndex: 4,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: c.scroller('annonces'),
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                const _DemoTimeDivider('Aujourd\'hui · 08:15'),
                _DemoBubble(
                  c: c,
                  id: 'ann_0',
                  name: me.name,
                  username: me.username,
                  own: true,
                  text: 'Bonjour à tous ! Le marché ouvre à 10 h.',
                  time: '08:15',
                ),
                _DemoLoanRequestBubble(c: c),
                if (c.flag('sent'))
                  _DemoBubble(
                    c: c,
                    id: 'ann_new',
                    name: me.name,
                    username: me.username,
                    own: true,
                    text: c.text('sentText'),
                    time: 'à l\'instant',
                  ),
                if (c.flag('giftSent'))
                  c.mark(
                    'giftBubble',
                    _DemoGiftBubble(
                      claimedBy: c.flag('giftClaimed') ? demoLea : null,
                    ),
                  ),
              ],
            ),
          ),
          _DemoInputBar(
            c: c,
            hint: 'Écrire une annonce…',
            leadingIcon: Icons.card_giftcard_rounded,
            leadingId: 'giftBtn',
          ),
        ],
      ),
    );
  }
}

class _DemoClassChat extends StatelessWidget {
  const _DemoClassChat({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final me = DemoIdentity.of(context);
    return MockScreen(
      title: '5e B',
      body: Column(
        children: [
          Expanded(
            child: ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                const _DemoTimeDivider('Aujourd\'hui · 13:02'),
                _DemoBubble(
                  c: c,
                  id: 'msg_lea',
                  name: demoLea.name,
                  username: demoLea.username,
                  text: 'Quelqu\'un a fini l\'exercice 3 ?',
                  time: '13:02',
                  flagId: 'flag_lea',
                ),
                _Collapse(
                  visible: !c.flag('msgDeleted'),
                  child: _DemoBubble(
                    c: c,
                    id: 'msg_hugo',
                    name: demoHugo.name,
                    username: demoHugo.username,
                    text: 'Léa elle copie toujours sur les autres, quelle '
                        'tricheuse',
                    time: '13:03',
                    censored: c.flag('censored'),
                    flagId: 'flag_hugo',
                  ),
                ),
                _DemoBubble(
                  c: c,
                  id: 'msg_adam',
                  name: demoAdam.name,
                  username: demoAdam.username,
                  text: 'Je peux t\'aider Léa, on regarde ensemble ?',
                  time: '13:04',
                  flagId: 'flag_adam',
                ),
                _DemoBubble(
                  c: c,
                  id: 'msg_me',
                  name: me.name,
                  username: me.username,
                  own: true,
                  text: 'Pensez à réviser pour jeudi.',
                  time: '13:06',
                  readers: const [demoLea, demoHugo, demoAdam],
                  readersOpen: c.flag('readsOpen'),
                ),
              ],
            ),
          ),
          _DemoInputBar(
            c: c,
            hint: 'Écrire un message…',
            leadingIcon: Icons.add_rounded,
            leadingId: 'plus',
          ),
        ],
      ),
    );
  }
}

/// Repli animé d'un élément de liste.
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

class _DemoTimeDivider extends StatelessWidget {
  const _DemoTimeDivider(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoBubble extends StatelessWidget {
  const _DemoBubble({
    required this.c,
    required this.id,
    required this.name,
    required this.username,
    required this.text,
    required this.time,
    this.own = false,
    this.censored = false,
    this.flagId,
    this.readers = const [],
    this.readersOpen = false,
  });

  final DemoController c;
  final String id;
  final String name;
  final String username;
  final String text;
  final String time;
  final bool own;
  final bool censored;

  /// Repère du drapeau affiché à côté des messages des autres.
  final String? flagId;
  final List<DemoPerson> readers;
  final bool readersOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;
    final onVariant = theme.colorScheme.onSurfaceVariant;

    final bubble = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: own
            ? accent
            : (context.isDark
                ? const Color(0xFF2A2A3E)
                : const Color(0xFFEFEDE6)),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(own ? 18 : 5),
          bottomRight: Radius.circular(own ? 5 : 18),
        ),
      ),
      child: censored
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block_rounded, size: 14, color: onVariant),
                const SizedBox(width: 6),
                Text(
                  'Message censuré',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: onVariant,
                    fontSize: 13.5,
                  ),
                ),
              ],
            )
          : Text(
              text,
              style: TextStyle(
                color: own ? context.onAccent : theme.colorScheme.onSurface,
                fontSize: 14,
                height: 1.35,
              ),
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            own ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!own) ...[
            UserAvatar(username: username, radius: 14),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  own ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!own)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: onVariant,
                      ),
                    ),
                  ),
                c.mark(id, bubble),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(time,
                        style: TextStyle(fontSize: 10.5, color: onVariant)),
                    if (readers.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      c.mark(
                        'reads',
                        _DemoReaders(people: readers, expanded: readersOpen),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!own && flagId != null)
            c.mark(
              flagId!,
              Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.outlined_flag_rounded,
                  size: 16,
                  color: onVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DemoReaders extends StatelessWidget {
  const _DemoReaders({required this.people, required this.expanded});

  final List<DemoPerson> people;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: expanded
          ? Wrap(
              key: const ValueKey('expanded'),
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final person in people)
                  Container(
                    padding: const EdgeInsets.fromLTRB(2, 2, 8, 2),
                    decoration: BoxDecoration(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        UserAvatar(username: person.username, radius: 7),
                        const SizedBox(width: 4),
                        Text(
                          person.name.split(' ').first,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            )
          : SizedBox(
              key: const ValueKey('compact'),
              width: 14 + 11.0 * (people.length - 1),
              height: 16,
              child: Stack(
                children: [
                  for (var i = 0; i < people.length; i++)
                    Positioned(
                      left: i * 11.0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.scaffoldBackgroundColor,
                            width: 1.2,
                          ),
                        ),
                        child: UserAvatar(
                          username: people[i].username,
                          radius: 7,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _DemoLoanRequestBubble extends StatelessWidget {
  const _DemoLoanRequestBubble({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;
    final accepted = c.flag('loanAccepted');
    final neutral = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(username: demoHugo.username, radius: 14),
          const SizedBox(width: 8),
          Expanded(
            child: c.mark(
              'loanBubble',
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accent.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.handshake_rounded, size: 15, color: accent),
                        const SizedBox(width: 6),
                        Text(
                          'Demande de prêt',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: accent,
                          ),
                        ),
                        const Spacer(),
                        if (accepted)
                          const MockPill('Acceptée', color: AppTheme.positive)
                        else
                          c.mark(
                            'trashLoan',
                            const Icon(
                              Icons.delete_outline_rounded,
                              color: AppTheme.negative,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '@${demoHugo.username}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '30.00 SC',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    c.mark(
                      'loanDetails',
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          MockPill('Taux 5 %', color: neutral),
                          MockPill('Durée : 3 jours', color: neutral),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '« Pour la sortie scolaire »',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        color: neutral,
                      ),
                    ),
                    // Pas de bouton « Accepter le prêt » : l'administrateur
                    // ne prête pas.
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

class _DemoGiftBubble extends StatelessWidget {
  const _DemoGiftBubble({required this.claimedBy});

  final DemoPerson? claimedBy;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 60),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          width: 230,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFE84393), accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.card_giftcard_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Cadeau',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '5.00 SC',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Premier à répondre !',
                style: TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: Container(
                  key: ValueKey(claimedBy),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    claimedBy == null
                        ? 'En attente d\'un preneur'
                        : 'Récupéré par @${claimedBy!.username}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoInputBar extends StatelessWidget {
  const _DemoInputBar({
    required this.c,
    required this.hint,
    required this.leadingIcon,
    required this.leadingId,
  });

  final DemoController c;
  final String hint;
  final IconData leadingIcon;
  final String leadingId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;
    final text = c.text('input');
    final focused = c.flag('inputFocus');

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          c.mark(
            leadingId,
            IconButton(
              onPressed: demoNoop,
              icon: Icon(leadingIcon, color: accent),
            ),
          ),
          Expanded(
            child: c.mark(
              'input',
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.inputDecorationTheme.fillColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: focused ? accent : Colors.transparent,
                    width: 1.4,
                  ),
                ),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        text.isEmpty ? hint : text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: text.isEmpty
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (focused) const DemoCaret(),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          c.mark(
            'send',
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              child:
                  Icon(Icons.send_rounded, color: context.onAccent, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoGiftDialog extends StatelessWidget {
  const _DemoGiftDialog({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final focus = c.get<String>('focus');
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, Color.lerp(accent, Colors.black, 0.22)!],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.card_giftcard_rounded,
                color: theme.colorScheme.onPrimary,
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Envoyer un cadeau',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            c.mark(
              'f_giftAmount',
              MockField(
                label: 'Montant',
                suffix: 'SC',
                value: c.text('giftAmount'),
                focused: focus == 'giftAmount',
              ),
            ),
            const SizedBox(height: 10),
            c.mark(
              'f_giftNote',
              MockField(
                label: 'Motif (optionnel)',
                value: c.text('giftNote'),
                focused: focus == 'giftNote',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child:
                      TextButton(onPressed: demoNoop, child: Text('Annuler')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: c.mark(
                    'sendGift',
                    FilledButton.icon(
                      onPressed: demoNoop,
                      icon: const Icon(Icons.card_giftcard_rounded, size: 17),
                      label: const Text('Envoyer'),
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

Future<void> playAnnouncement(DemoPlayer p) async {
  p.say('Écrire l\'annonce dans le champ du bas');
  await p.tap('input');
  p.set('inputFocus', true);
  await p.type('input', 'Marché ouvert vendredi à 10 h !');
  p.say('Toucher la flèche pour la publier');
  await p.tap('send');
  p
    ..set('sentText', p.c.text('input'))
    ..set('sent', true)
    ..set('input', '')
    ..set('inputFocus', false);
  await p.wait(900);
  p.say('Appui long sur une de vos annonces : « Modifier » ou « Supprimer »');
  await p.longPress('ann_new');
  p.set('sheet', 'annOptions');
  await p.wait(1300);
  await p.tap('opt_edit');
  p
    ..set('sheet', null)
    ..set('editText', p.c.text('sentText'))
    ..set('dialog', 'edit');
  await p.wait(500);
  p.say('Corriger le texte, puis « Enregistrer »');
  await p.tap('f_edit');
  p.set('focus', 'edit');
  await p.type('editText', ' Salle B12.', append: true);
  await p.tap('saveEdit');
  p
    ..set('focus', null)
    ..set('dialog', null)
    ..set('sentText', p.c.text('editText'));
  await p.wait(1200);
}

Future<void> playGift(DemoPlayer p) async {
  p.say('🎁, à gauche du champ : envoyer un cadeau');
  await p.tap('giftBtn');
  p.set('dialog', 'gift');
  await p.wait(500);
  p.say('Le montant (0,01 SC minimum)');
  await p.tap('f_giftAmount');
  p.set('focus', 'giftAmount');
  await p.type('giftAmount', '5', perChar: 150);
  p.say('Un motif, facultatif');
  await p.tap('f_giftNote');
  p.set('focus', 'giftNote');
  await p.type('giftNote', 'Premier à répondre !');
  p.set('focus', null);
  p.say('« Envoyer » : le cadeau apparaît dans le chat');
  await p.tap('sendGift');
  p
    ..set('dialog', null)
    ..set('giftSent', true);
  await p.toast('Cadeau envoyé.', ms: 1600);
  p.say('Le premier élève qui touche « Récupérer » reçoit les 5 SC');
  await p.reveal('giftBubble', alignment: 0.8);
  await p.moveTo('giftBubble');
  await p.wait(1000);
  p.set('giftClaimed', true);
  await p.wait(1600);
}

Future<void> playChatLoan(DemoPlayer p) async {
  p.say('Une demande de prêt publiée par un élève');
  await p.moveTo('loanBubble', at: const Alignment(-0.3, -0.4));
  await p.wait(1100);
  p.say('Montant, taux, durée et motif de la demande');
  await p.moveTo('loanDetails');
  await p.wait(1200);
  p.say(
      'Pas de bouton « Accepter » pour vous : l\'administrateur ne prête pas');
  await p.moveTo('loanBubble', at: const Alignment(0, 0.75));
  await p.wait(1600);
  p.say(
      'La corbeille la supprime (réservé à l\'administrateur et à l\'auteur)');
  await p.moveTo('trashLoan');
  await p.wait(1200);
  p.say('Quand un élève accepte, la demande passe à « Acceptée »');
  p.hideCursor();
  await p.wait(500);
  p.set('loanAccepted', true);
  await p.wait(1800);
}

Future<void> playModerateClass(DemoPlayer p) async {
  p.say('Le drapeau à côté d\'un message : censure immédiate');
  await p.tap('flag_hugo');
  p.set('censored', true);
  await p.toast('Message censuré.', ms: 1600);
  p.say('Appui long sur un message : ses options');
  await p.longPress('msg_hugo');
  p.set('sheet', 'msgOptions');
  await p.wait(1100);
  p.say('« Supprimer » efface le message pour tout le monde');
  await p.tap('opt_deleteMsg');
  p
    ..set('sheet', null)
    ..set('dialog', 'deleteMsg');
  await p.wait(600);
  await p.tap('confirmDeleteMsg');
  p
    ..set('dialog', null)
    ..set('msgDeleted', true);
  await p.wait(1000);
  p.say('Sous vos messages : qui les a lus (toucher pour voir les noms)');
  await p.tap('reads');
  p.set('readsOpen', true);
  await p.wait(1500);
  p.say('Le bouton + : envoyer un cadeau à la classe');
  await p.tap('plus');
  p.set('sheet', 'attach');
  await p.wait(1400);
  p.set('sheet', null);
  await p.wait(300);
}

// ═════════════════════════════════════════════════════════════════════════════
// Portefeuille et transfert
// ═════════════════════════════════════════════════════════════════════════════

Widget walletScene(BuildContext context, DemoController c) {
  final txs = [
    demoTx(
      id: 'w1',
      type: TransactionType.transfer,
      amount: 15,
      incoming: true,
      other: demoLea,
      ago: const Duration(minutes: 20),
    ),
    demoTx(
      id: 'w2',
      type: TransactionType.transfer,
      amount: 10,
      incoming: false,
      other: demoNoah,
      description: 'Aide au projet',
      ago: const Duration(hours: 3),
    ),
    demoTx(
      id: 'w3',
      type: TransactionType.gift,
      amount: 5,
      incoming: false,
      ago: const Duration(hours: 5),
    ),
    demoTx(
      id: 'w4',
      type: TransactionType.transfer,
      amount: 8,
      incoming: true,
      other: demoHugo,
      ago: const Duration(days: 1),
    ),
    demoTx(
      id: 'w5',
      type: TransactionType.transfer,
      amount: 12,
      incoming: false,
      other: demoChloe,
      ago: const Duration(days: 2),
    ),
    demoTx(
      id: 'w6',
      type: TransactionType.initialBalance,
      amount: 100,
      incoming: true,
      ago: const Duration(days: 9),
    ),
  ];
  return MockScreen(
    title: 'Portefeuille',
    back: false,
    actions: [c.mark('walletRefresh', const MockIcon(Icons.refresh_rounded))],
    navIndex: 1,
    body: ListView.separated(
      controller: c.scroller('wallet'),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: txs.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, i) =>
          c.mark('tx_$i', TransactionTile(transaction: txs[i])),
    ),
  );
}

Future<void> playWallet(DemoPlayer p) async {
  p.say('Chaque ligne : le type d\'opération, l\'autre compte et la date');
  await p.moveTo('tx_0', at: const Alignment(-0.4, 0));
  await p.wait(1200);
  p.say('Le montant : en vert ce qui arrive, en rouge ce qui part');
  await p.moveTo('tx_1', at: const Alignment(0.8, 0));
  await p.wait(1200);
  p.say('Virements, cadeaux, solde initial… tout y figure');
  await p.moveTo('tx_2', at: const Alignment(-0.4, 0));
  await p.wait(900);
  await p.moveTo('tx_5', at: const Alignment(-0.4, 0));
  await p.wait(900);
  p.say('Chez les élèves s\'ajoutent récompenses, taxes, achats et prêts');
  await p.wait(1500);
  p.say('Descendre charge la suite ; ↻ en haut à droite actualise');
  await p.tap('walletRefresh');
  await p.wait(900);
}

Widget transferScene(BuildContext context, DemoController c) {
  final theme = Theme.of(context);
  final focus = c.get<String>('focus');
  final picked = c.flag('picked');
  final query = c.text('recipient');
  final label =
      theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600);

  return MockScreen(
    title: 'Transférer',
    body: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        Text('Destinataire', style: label),
        const SizedBox(height: 8),
        if (picked) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(
              avatar: CircleAvatar(
                backgroundColor: AppTheme.gold.withValues(alpha: 0.2),
                child: const Text(
                  'I',
                  style: TextStyle(fontSize: 12, color: AppTheme.gold),
                ),
              ),
              label: Text(demoInes.name),
              onDeleted: demoNoop,
            ),
          ),
          const SizedBox(height: 8),
        ],
        c.mark(
          'recipient',
          MockField(
            hint: 'Rechercher un utilisateur…',
            prefixIcon: Icons.search_rounded,
            value: picked ? demoInes.name : query,
            focused: focus == 'recipient',
          ),
        ),
        if (query.isNotEmpty && !picked) ...[
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: c.mark(
              'pickInes',
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.gold.withValues(alpha: 0.15),
                  child: const Text(
                    'I',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                title: Text(demoInes.name),
                subtitle: Text(
                  '@${demoInes.username}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text('Montant', style: label),
        const SizedBox(height: 8),
        c.mark(
          'f_amount',
          MockField(
            hint: '0.00',
            suffix: 'SC',
            value: c.text('amount'),
            focused: focus == 'amount',
          ),
        ),
        const SizedBox(height: 20),
        Text('Description (optionnelle)', style: label),
        const SizedBox(height: 8),
        c.mark(
          'f_desc',
          MockField(
            hint: 'Motif du transfert…',
            prefixIcon: Icons.notes_rounded,
            value: c.text('desc'),
            focused: focus == 'desc',
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: c.mark(
            'sendTransfer',
            ElevatedButton.icon(
              onPressed: demoNoop,
              icon: const Icon(Icons.send_rounded),
              label: const Text('Envoyer'),
            ),
          ),
        ),
      ],
    ),
  );
}

Future<void> playTransfer(DemoPlayer p) async {
  p.say('Chercher le destinataire');
  await p.tap('recipient');
  p.set('focus', 'recipient');
  await p.type('recipient', 'inès', perChar: 140);
  p.say('Le toucher dans la liste');
  await p.tap('pickInes', at: const Alignment(-0.4, 0));
  p
    ..set('picked', true)
    ..set('focus', null);
  await p.wait(500);
  p.say('Le montant');
  await p.tap('f_amount');
  p.set('focus', 'amount');
  await p.type('amount', '15', perChar: 150);
  p.say('Une description si besoin : elle figure dans les notifications');
  await p.tap('f_desc');
  p.set('focus', 'desc');
  await p.type('desc', 'Aide au projet');
  p.set('focus', null);
  p.say('« Envoyer » : les deux comptes sont prévenus');
  await p.tap('sendTransfer');
  await p.toast('15.00 SC envoyés à @${demoInes.username} !');
}

// ═════════════════════════════════════════════════════════════════════════════
// Payer (QR et NFC)
// ═════════════════════════════════════════════════════════════════════════════

PreferredSizeWidget _payTabs(DemoController c) {
  const tabs = TabBar(
    tabs: [
      Tab(text: 'Recevoir', icon: Icon(Icons.download_rounded)),
      Tab(text: 'Envoyer', icon: Icon(Icons.upload_rounded)),
    ],
  );
  return PreferredSize(
    preferredSize: tabs.preferredSize,
    child: c.mark('payTabs', tabs),
  );
}

Widget payScene(BuildContext context, DemoController c) {
  return Stack(
    fit: StackFit.expand,
    children: [
      DemoPages(
        page: c.page,
        builder: (page) => switch (page) {
          'send' => _DemoPaySend(c: c),
          'scan' => const _DemoPayScan(),
          _ => _DemoPayReceive(c: c),
        },
      ),
      DemoModal(
        open: c.get('dialog') == 'paySuccess',
        child: Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppTheme.positive.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 42,
                    color: AppTheme.positive,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Paiement effectué !',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '3.50 SC',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: context.accent,
                  ),
                ),
                Text(
                  'envoyés à ${demoInes.name}',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: c.mark(
                    'perfect',
                    const ElevatedButton(
                      onPressed: demoNoop,
                      child: Text('Parfait !'),
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

class _DemoPayReceive extends StatelessWidget {
  const _DemoPayReceive({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return DefaultTabController(
      length: 2,
      child: MockScreen(
        title: 'Payer',
        bottom: _payTabs(c),
        navIndex: 2,
        body: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.nfc_rounded, size: 18, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      'NFC actif · approche l’envoyeur',
                      style: TextStyle(
                        fontSize: 12,
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'QR de réception (alternative au NFC)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Center(
              child: c.mark(
                'qr',
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.85),
                      width: 5,
                    ),
                  ),
                  child: QrImageView(
                    data: 'sescoin-demo-tutoriel',
                    version: QrVersions.auto,
                    size: 170,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'L’envoyeur choisit le montant de son côté',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoPaySend extends StatelessWidget {
  const _DemoPaySend({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final label = Theme.of(context)
        .textTheme
        .labelLarge
        ?.copyWith(fontWeight: FontWeight.w600);
    return DefaultTabController(
      length: 2,
      initialIndex: 1,
      child: MockScreen(
        title: 'Payer',
        bottom: _payTabs(c),
        navIndex: 2,
        body: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Text('Montant à envoyer', style: label),
            const SizedBox(height: 8),
            c.mark(
              'payAmount',
              MockField(
                hint: '0.00',
                suffix: 'SC',
                value: c.text('payAmount'),
                focused: c.get('focus') == 'payAmount',
              ),
            ),
            const SizedBox(height: 16),
            const MockField(
              hint: 'Description (optionnelle)',
              prefixIcon: Icons.notes_rounded,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: c.mark(
                'payNfc',
                ElevatedButton.icon(
                  onPressed: demoNoop,
                  icon: const Icon(Icons.nfc_rounded),
                  label: const Text('Payer via NFC'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('ou', style: TextStyle(color: Colors.grey)),
                ),
                Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: c.mark(
                'payQr',
                TextButton.icon(
                  onPressed: demoNoop,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Payer via QR Code'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoPayScan extends StatelessWidget {
  const _DemoPayScan();

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return ColoredBox(
      color: const Color(0xFF0B0B10),
      child: Stack(
        children: [
          Center(
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                border: Border.all(color: accent, width: 2.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  builder: (context, t, child) =>
                      Opacity(opacity: t, child: child),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    color: Colors.white,
                    child: QrImageView(
                      data: 'sescoin-demo-ines',
                      version: QrVersions.auto,
                      size: 150,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              onPressed: demoNoop,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Retour'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> playPay(DemoPlayer p) async {
  p.say('« Recevoir » : votre QR code, à montrer à celui qui paie');
  await p.moveTo('qr');
  await p.wait(1300);
  p.say('« Envoyer » : pour payer quelqu\'un à côté de vous');
  await p.tap('payTabs', at: const Alignment(0.5, 0));
  p.set('page', 'send');
  await p.wait(800);
  p.say('Saisir le montant');
  await p.tap('payAmount');
  p.set('focus', 'payAmount');
  await p.type('payAmount', '3.50', perChar: 140);
  p.set('focus', null);
  p.say('« Payer via NFC » : il suffit d\'approcher les deux téléphones…');
  await p.moveTo('payNfc');
  await p.wait(1200);
  p.say('… ou « Payer via QR Code » : scanner le QR de l\'autre personne');
  await p.tap('payQr');
  p.set('page', 'scan');
  await p.wait(1700);
  p.set('dialog', 'paySuccess');
  await p.wait(1500);
  await p.tap('perfect');
  p
    ..set('dialog', null)
    ..set('payAmount', '')
    ..set('page', 'send');
  await p.wait(500);
}

// ═════════════════════════════════════════════════════════════════════════════
// Marché (côté utilisateur)
// ═════════════════════════════════════════════════════════════════════════════

PreferredSizeWidget _shopTabs(DemoController c) {
  const tabs = TabBar(
    tabs: [
      Tab(text: 'Boutique', icon: Icon(Icons.storefront_rounded)),
      Tab(text: 'Enchères', icon: Icon(Icons.gavel_rounded)),
    ],
  );
  return PreferredSize(
    preferredSize: tabs.preferredSize,
    child: c.mark('shopTabs', tabs),
  );
}

MarketplaceItem _demoItem(
  String id,
  String name,
  double price, {
  int stock = -1,
  int maxPerUser = -1,
  String description = '',
}) {
  final now = DateTime.now();
  return MarketplaceItem(
    id: id,
    name: name,
    description: description,
    price: price,
    category: 'Privilèges',
    stock: stock,
    maxPerUser: maxPerUser,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

Widget shopScene(BuildContext context, DemoController c) {
  return Stack(
    fit: StackFit.expand,
    children: [
      DemoPages(
        page: c.page,
        builder: (page) => switch (page) {
          'auctions' => _DemoAuctionsTab(c: c),
          'auction' => _DemoAuctionDetail(c: c),
          _ => _DemoShopTab(c: c),
        },
      ),
      DemoModal(
        open: c.get('dialog') == 'buy',
        child: AppDialog(
          icon: Icons.shopping_bag_rounded,
          title: 'Confirmer l\'achat',
          subtitle: 'Joker devoir',
          content: c.mark('buyRecap', const _DemoPurchaseRecap()),
          actions: [
            const TextButton(onPressed: demoNoop, child: Text('Annuler')),
            c.mark(
              'confirmBuy',
              FilledButton.icon(
                onPressed: demoNoop,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Acheter'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _DemoPurchaseRecap extends StatelessWidget {
  const _DemoPurchaseRecap();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(String label, String value,
            {bool emphasis = false, Color? color}) =>
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: emphasis ? 15 : 13.5,
                fontWeight: emphasis ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row('Prix', '50.00 SC', emphasis: true, color: context.accent),
        const SizedBox(height: 6),
        row('Solde actuel', '152.40 SC'),
        const Divider(height: 18),
        row('Après achat', '102.40 SC', emphasis: true),
      ],
    );
  }
}

class _DemoShopTab extends StatelessWidget {
  const _DemoShopTab({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: MockScreen(
        title: 'Marché',
        back: false,
        actions: const [MockIcon(Icons.edit_rounded)],
        bottom: _shopTabs(c),
        navIndex: 3,
        body: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Privilèges',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.accent,
                    ),
              ),
            ),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: c.mark(
                      'item_joker',
                      MarketItemCard(
                        item: _demoItem(
                          'joker',
                          'Joker devoir',
                          50,
                          stock: 10,
                          maxPerUser: 1,
                          description: 'Dispense d\'un devoir maison au choix.',
                        ),
                        fillHeight: true,
                        onBuy: demoNoop,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: c.mark(
                      'item_place',
                      MarketItemCard(
                        item: _demoItem(
                          'place',
                          'Choisir sa place',
                          25,
                          maxPerUser: 1,
                          description: 'Changer de place pour une journée.',
                        ),
                        fillHeight: true,
                        actionLabel: 'Limite atteinte',
                        onBuy: null,
                      ),
                    ),
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

/// Enchère fictive : l'échéance est fixée à l'ouverture de l'écran, pour que
/// le compte à rebours défile normalement.
class _DemoAuctionClock extends StatefulWidget {
  const _DemoAuctionClock({required this.builder});

  final Widget Function(Auction auction) builder;

  @override
  State<_DemoAuctionClock> createState() => _DemoAuctionClockState();
}

class _DemoAuctionClockState extends State<_DemoAuctionClock> {
  late final DateTime _endsAt =
      DateTime.now().add(const Duration(minutes: 24, seconds: 30));

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return widget.builder(
      Auction(
        id: 'demo-auction',
        itemName: 'Déjeuner avec le prof',
        itemDescription: 'Un déjeuner à la cantine avec votre professeur.',
        startingPrice: 10,
        currentPrice: 24,
        currentWinnerId: _id(demoLea),
        currentWinnerUsername: demoLea.username,
        currentWinnerEmoji: '🔥',
        status: AuctionStatus.active,
        startsAt: now.subtract(const Duration(hours: 1)),
        endsAt: _endsAt,
        bidCount: 4,
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
    );
  }
}

class _DemoAuctionsTab extends StatelessWidget {
  const _DemoAuctionsTab({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: 1,
      child: MockScreen(
        title: 'Marché',
        back: false,
        actions: const [MockIcon(Icons.edit_rounded)],
        bottom: _shopTabs(c),
        navIndex: 3,
        body: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _DemoAuctionClock(
              builder: (auction) => c.mark(
                'auctionCard',
                AuctionCard(auction: auction, onBid: demoNoop),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoAuctionDetail extends StatefulWidget {
  const _DemoAuctionDetail({required this.c});

  final DemoController c;

  @override
  State<_DemoAuctionDetail> createState() => _DemoAuctionDetailState();
}

class _DemoAuctionDetailState extends State<_DemoAuctionDetail> {
  late final DateTime _endsAt =
      DateTime.now().add(const Duration(minutes: 24, seconds: 10));
  Timer? _timer;

  static const _emojis = ['🔥', '😎', '👑', '🚀', '💎', '😈'];

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

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final theme = Theme.of(context);
    final accent = context.accent;
    final placed = c.flag('bidPlaced');
    final left = _endsAt.difference(DateTime.now());
    final remaining =
        '${left.inMinutes.toString().padLeft(2, '0')}:${(left.inSeconds % 60).toString().padLeft(2, '0')}';
    final bids = [
      if (placed) (demoMeUsername(context), 26.0),
      (demoLea.username, 24.0),
      (demoHugo.username, 22.0),
      (demoInes.username, 15.0),
    ];

    Widget stat(String label, String value, {Color? color}) => Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );

    return MockScreen(
      title: 'Déjeuner avec le prof',
      body: ListView(
        controller: c.scroller('auction'),
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Un déjeuner à la cantine avec votre professeur.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      stat(
                        'Prix actuel',
                        placed ? '26.00 SC' : '24.00 SC',
                        color: accent,
                      ),
                      stat('Offres', placed ? '5' : '4'),
                      stat('Temps restant', remaining),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      UserAvatar(
                        username:
                            placed ? demoMeUsername(context) : demoLea.username,
                        radius: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Dernier enchérisseur : @'
                          '${placed ? demoMeUsername(context) : demoLea.username}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        placed ? c.text('emoji') : '🔥',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!placed) ...[
            Text(
              'Placer une offre',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: c.mark(
                    'bidField',
                    MockField(
                      hint: 'Min. 25.00 SC',
                      suffix: 'SC',
                      value: c.text('bid'),
                      focused: c.get('focus') == 'bid',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                c.mark(
                  'bidBtn',
                  ElevatedButton.icon(
                    onPressed: demoNoop,
                    icon: const Icon(Icons.gavel_rounded, size: 18),
                    label: const Text('Enchérir'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.positive.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Meilleure enchère actuelle',
                style: TextStyle(
                  color: AppTheme.positive,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Émoji affiché sur l’enchère',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (i, emoji) in _emojis.indexed)
                  c.mark(
                    'emoji_$i',
                    ChoiceChip(
                      selected: c.text('emoji') == emoji,
                      label: Text(emoji, style: const TextStyle(fontSize: 18)),
                      onSelected: (_) {},
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Historique des offres',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          for (final (i, (username, amount)) in bids.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: UserAvatar(username: username, radius: 18),
              title: Text('@$username'),
              trailing: Text(
                '${amount.toStringAsFixed(2)} SC',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: i == 0 ? accent : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Identifiant de l'administrateur qui suit le tutoriel.
String demoMeUsername(BuildContext context) =>
    DemoIdentity.of(context).username;

Future<void> playBuy(DemoPlayer p) async {
  p.say('Les offres de la boutique, rangées par catégorie');
  await p.moveTo('item_joker', at: const Alignment(0, -0.4));
  await p.wait(1100);
  p.say('« Limite atteinte » : le maximum d\'achats par élève est atteint');
  await p.moveTo('item_place', at: const Alignment(0, 0.86));
  await p.wait(1200);
  p.say('« Acheter » ouvre un récapitulatif avant de payer');
  await p.tap('item_joker', at: const Alignment(0, 0.86));
  p.set('dialog', 'buy');
  await p.wait(600);
  p.say('Prix, solde actuel et solde après l\'achat');
  await p.moveTo('buyRecap');
  await p.wait(1400);
  await p.tap('confirmBuy');
  p.set('dialog', null);
  await p.toast('Achat effectué : Joker devoir.');
}

Future<void> playBid(DemoPlayer p) async {
  p.say('Onglet « Enchères »');
  await p.tap('shopTabs', at: const Alignment(0.5, 0));
  p.set('page', 'auctions');
  await p.wait(800);
  p.say('Le prix actuel, le meilleur enchérisseur et le temps restant');
  await p.moveTo('auctionCard', at: const Alignment(0, 0.25));
  await p.wait(1200);
  p.say('« Enchérir » ouvre l\'enchère');
  await p.tap('auctionCard', at: const Alignment(0, 0.86));
  p.set('page', 'auction');
  await p.wait(900);
  p.say('Saisir une offre : au moins le prix actuel + 1 SC');
  await p.tap('bidField');
  p.set('focus', 'bid');
  await p.type('bid', '26', perChar: 160);
  p.set('focus', null);
  await p.tap('bidBtn');
  p
    ..set('emoji', '')
    ..set('bidPlaced', true);
  await p.toast('Enchère placée.', ms: 1500);
  p.say('En tête, on choisit l\'émoji affiché à côté de son nom');
  await p.tap('emoji_2');
  p.set('emoji', '👑');
  await p.wait(1300);
}

// ═════════════════════════════════════════════════════════════════════════════
// Demander un prêt
// ═════════════════════════════════════════════════════════════════════════════

Widget loanCreateScene(BuildContext context, DemoController c) {
  final focus = c.get<String>('focus');
  final picked = c.flag('lenderPicked');
  final query = c.text('lenderQuery');
  final durationMode = (c.get<int>('mode') ?? 0) == 1;
  final theme = Theme.of(context);
  const label = TextStyle(fontWeight: FontWeight.w600, fontSize: 14);

  Widget durationField(String key, String text) => c.mark(
        'f_$key',
        MockField(
          label: text,
          hint: '0',
          value: c.text(key),
          focused: focus == key,
          dense: true,
          center: true,
        ),
      );

  return Stack(
    fit: StackFit.expand,
    children: [
      MockScreen(
        title: 'Demander un prêt',
        body: ListView(
          controller: c.scroller('loanForm'),
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Prêteur(s)', style: label),
            const SizedBox(height: 8),
            if (picked) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: CircleAvatar(
                    backgroundColor: context.accent.withValues(alpha: 0.2),
                    child: Text(
                      'L',
                      style: TextStyle(fontSize: 12, color: context.accent),
                    ),
                  ),
                  label: Text(demoLea.name),
                  onDeleted: demoNoop,
                ),
              ),
              const SizedBox(height: 8),
            ],
            c.mark(
              'lenderSearch',
              MockField(
                hint: 'Rechercher un utilisateur…',
                prefixIcon: Icons.search_rounded,
                value: query,
                focused: focus == 'lender',
              ),
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: c.mark(
                  'pickLender',
                  ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: context.accent.withValues(alpha: 0.15),
                      child: Text(
                        'L',
                        style: TextStyle(
                          color: context.accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(demoLea.name),
                    subtitle: Text(
                      '@${demoLea.username}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text('Montant emprunté', style: label),
            const SizedBox(height: 8),
            c.mark(
              'f_principal',
              MockField(
                hint: '0.00',
                suffix: 'SC',
                value: c.text('principal'),
                focused: focus == 'principal',
              ),
            ),
            const SizedBox(height: 20),
            const Text('Taux d\'intérêt', style: label),
            const SizedBox(height: 8),
            c.mark(
              'f_rate',
              MockField(
                hint: '0',
                suffix: '%',
                value: c.text('rate'),
                focused: focus == 'rate',
              ),
            ),
            const SizedBox(height: 20),
            Text(durationMode ? 'Durée *' : 'Échéance *', style: label),
            const SizedBox(height: 8),
            c.mark(
              'dueMode',
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.event_rounded, size: 16),
                      label: Text('Date'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: Icon(Icons.timer_outlined, size: 16),
                      label: Text('Durée'),
                    ),
                  ],
                  selected: {durationMode ? 1 : 0},
                  onSelectionChanged: (_) {},
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (!durationMode)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.inputDecorationTheme.fillColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 18),
                    const SizedBox(width: 12),
                    Text(
                      'Choisir une date et une heure',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(child: durationField('days', 'Jours')),
                  const SizedBox(width: 8),
                  Expanded(child: durationField('hours', 'Heures')),
                  const SizedBox(width: 8),
                  Expanded(child: durationField('minutes', 'Minutes')),
                ],
              ),
            const SizedBox(height: 20),
            const Text('Note (optionnelle)', style: label),
            const SizedBox(height: 8),
            MockField(hint: 'Motif du prêt…', value: c.text('note')),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: c.mark(
                'sendLoan',
                ElevatedButton.icon(
                  onPressed: demoNoop,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Envoyer la demande'),
                ),
              ),
            ),
          ],
        ),
      ),
      DemoModal(
        open: c.get('dialog') == 'confirmLoan',
        child: AppDialog(
          icon: Icons.handshake_rounded,
          title: 'Confirmer la demande',
          subtitle: 'Prêteur : ${demoLea.name}',
          content: const _DemoLoanRecap(),
          actions: [
            const TextButton(onPressed: demoNoop, child: Text('Annuler')),
            c.mark(
              'confirmSend',
              FilledButton.icon(
                onPressed: demoNoop,
                icon: const Icon(Icons.send_rounded, size: 17),
                label: const Text('Envoyer'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _DemoLoanRecap extends StatelessWidget {
  const _DemoLoanRecap();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;
    Widget row(IconData icon, String label, String value,
            {bool emph = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(icon, size: 17, color: accent),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: emph ? 15 : 13.5,
                  fontWeight: emph ? FontWeight.w800 : FontWeight.w600,
                  color: emph ? accent : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row(Icons.account_balance_wallet_rounded, 'Montant', '30.00 SC',
            emph: true),
        row(Icons.percent_rounded, 'Intérêt', '5.0 %'),
        row(Icons.payments_rounded, 'À rembourser', '31.50 SC', emph: true),
        row(Icons.timer_outlined, 'Durée', '3 jours'),
      ],
    );
  }
}

Future<void> playLoanCreate(DemoPlayer p) async {
  p.say('Chercher puis toucher un prêteur (plusieurs possibles)');
  await p.tap('lenderSearch');
  p.set('focus', 'lender');
  await p.type('lenderQuery', 'léa', perChar: 140);
  await p.tap('pickLender', at: const Alignment(-0.4, 0));
  p
    ..set('lenderPicked', true)
    ..set('lenderQuery', '')
    ..set('focus', null);
  await p.wait(500);
  p.say('Le montant emprunté et le taux d\'intérêt (de 0 à 100 %)');
  await p.tap('f_principal');
  p.set('focus', 'principal');
  await p.type('principal', '30', perChar: 150);
  await p.tap('f_rate');
  p.set('focus', 'rate');
  await p.type('rate', '5', perChar: 150);
  p.set('focus', null);
  p.say(
      'L\'échéance : une date précise, ou une durée qui démarre à l\'acceptation');
  await p.reveal('dueMode', alignment: 0.45);
  await p.tap('dueMode', at: const Alignment(0.5, 0));
  p.set('mode', 1);
  await p.wait(500);
  await p.tap('f_days');
  p.set('focus', 'days');
  await p.type('days', '3', perChar: 150);
  p.set('focus', null);
  p.say('« Envoyer la demande », puis vérifier le récapitulatif');
  await p.reveal('sendLoan', alignment: 0.85);
  await p.tap('sendLoan');
  p.set('dialog', 'confirmLoan');
  await p.wait(1500);
  await p.tap('confirmSend');
  p.set('dialog', null);
  await p.toast('1 demande(s) de prêt envoyée(s) avec succès !');
}

// ═════════════════════════════════════════════════════════════════════════════
// Profil, prêts, notifications, mot de passe
// ═════════════════════════════════════════════════════════════════════════════

Loan _demoLoan({
  required String id,
  required DemoPerson lender,
  required DemoPerson borrower,
  required double principal,
  required double rate,
  double repaid = 0,
  LoanStatus status = LoanStatus.active,
  DateTime? dueDate,
  int? durationMinutes,
  String? note,
}) {
  final now = DateTime.now();
  return Loan(
    id: id,
    lenderId: _id(lender),
    lenderUsername: lender.username,
    borrowerId: _id(borrower),
    borrowerUsername: borrower.username,
    principal: principal,
    interestRate: rate,
    totalDue: principal * (1 + rate / 100),
    amountRepaid: repaid,
    status: status,
    dueDate: dueDate,
    durationMinutes: durationMinutes,
    createdAt: now.subtract(const Duration(days: 1)),
    updatedAt: now,
    note: note,
  );
}

Widget profileScene(BuildContext context, DemoController c) {
  final focus = c.get<String>('focus');
  return Stack(
    fit: StackFit.expand,
    children: [
      DemoPages(
        page: c.page,
        builder: (page) => switch (page) {
          'student' => _DemoStudentLoans(c: c),
          'notifs' => _DemoProfile(c: c, tab: 1),
          'password' => _DemoPassword(c: c),
          _ => _DemoProfile(c: c, tab: 0),
        },
      ),
      DemoModal(
        open: c.get('dialog') == 'accept',
        child: AlertDialog(
          title: const Text('Accepter ce prêt ?'),
          content: Text('Le montant sera envoyé à ${demoHugo.username}.'),
          actions: [
            const TextButton(onPressed: demoNoop, child: Text('Annuler')),
            c.mark(
              'confirmAccept',
              const ElevatedButton(
                onPressed: demoNoop,
                child: Text('Confirmer'),
              ),
            ),
          ],
        ),
      ),
      DemoModal(
        open: c.get('dialog') == 'repay',
        child: AppDialog(
          icon: Icons.payments_rounded,
          title: 'Rembourser le prêt',
          subtitle: 'Restant : 21.00 SC',
          content: MockField(
            label: 'Montant à rembourser',
            suffix: 'SC',
            value: '21.00',
            focused: focus == 'repay',
          ),
          actions: [
            const TextButton(onPressed: demoNoop, child: Text('Annuler')),
            c.mark(
              'doRepay',
              const FilledButton(
                  onPressed: demoNoop, child: Text('Rembourser')),
            ),
          ],
        ),
      ),
    ],
  );
}

class _DemoProfileHeader extends StatelessWidget {
  const _DemoProfileHeader({
    required this.c,
    required this.name,
    required this.username,
    required this.balance,
  });

  final DemoController c;
  final String name;
  final String username;
  final double balance;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    final card = Theme.of(context).cardColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [Color.lerp(card, accent, 0.14)!, card],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                c.mark(
                  'photo',
                  Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(2.5),
                        child: UserAvatar(username: username, radius: 28),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(color: card, width: 2),
                          ),
                          child: Icon(
                            Icons.edit_rounded,
                            size: 12,
                            color: AppTheme.onAccent(accent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '@$username',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${DemoAmount.format(balance)} SC',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: c.mark(
                'pwdBtn',
                OutlinedButton.icon(
                  onPressed: demoNoop,
                  icon: const Icon(Icons.lock_outline_rounded, size: 18),
                  label: const Text('Mot de passe'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    side: BorderSide(color: accent.withValues(alpha: 0.4)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoProfileTabs extends StatelessWidget {
  const _DemoProfileTabs({required this.c, required this.selected});

  final DemoController c;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;
    Widget tab(int index, IconData icon, String label, {int badge = 0}) {
      final active = index == selected;
      return Expanded(
        child: Container(
          height: 42,
          decoration: active
              ? BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, Color.lerp(accent, Colors.black, 0.2)!],
                  ),
                  borderRadius: BorderRadius.circular(14),
                )
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active
                    ? context.onAccent
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13.5,
                  color: active
                      ? context.onAccent
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 6),
                MockPill('$badge', color: AppTheme.info),
              ],
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            tab(0, Icons.handshake_rounded, 'Prêts'),
            c.mark(
              'notifTab',
              tab(
                1,
                Icons.notifications_rounded,
                'Notifications',
                badge: c.flag('allRead') ? 0 : 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<Widget> _profileActions(DemoController c) => [
      c.mark('settingsIcon', const MockIcon(Icons.settings_rounded)),
      c.mark('hubIcon', const MockIcon(Icons.hub_rounded)),
      c.mark('leaderIcon', const MockIcon(Icons.leaderboard_rounded)),
      c.mark('logoutIcon', const MockIcon(Icons.logout_rounded)),
    ];

class _DemoProfile extends StatelessWidget {
  const _DemoProfile({required this.c, required this.tab});

  final DemoController c;
  final int tab;

  @override
  Widget build(BuildContext context) {
    final me = DemoIdentity.of(context);
    return MockScreen(
      title: 'Profil',
      back: false,
      actions: _profileActions(c),
      navIndex: 5,
      body: Column(
        children: [
          _DemoProfileHeader(
            c: c,
            name: me.name,
            username: me.username,
            balance: 1250,
          ),
          _DemoProfileTabs(c: c, selected: tab),
          Expanded(
            child: tab == 1
                ? _DemoNotifications(c: c)
                : const EmptyState(
                    icon: Icons.handshake_rounded,
                    title: 'Aucun prêt pour le moment',
                    subtitle: 'Crée une demande pour commencer',
                  ),
          ),
        ],
      ),
    );
  }
}

class _DemoStudentLoans extends StatelessWidget {
  const _DemoStudentLoans({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final accepted = c.flag('accepted');
    final repaid = c.flag('repaid');
    final asLender = _demoLoan(
      id: 'l-lender',
      lender: demoLea,
      borrower: demoHugo,
      principal: 20,
      rate: 0,
      status: accepted ? LoanStatus.active : LoanStatus.pending,
      durationMinutes: accepted ? null : 2 * 1440,
      dueDate: accepted ? DateTime.now().add(const Duration(days: 2)) : null,
      note: 'Pour le cinéma',
    );
    final asBorrower = _demoLoan(
      id: 'l-borrower',
      lender: demoInes,
      borrower: demoLea,
      principal: 30,
      rate: 5,
      repaid: repaid ? 31.5 : 10.5,
      status: repaid ? LoanStatus.repaid : LoanStatus.active,
      dueDate: DateTime.now().add(const Duration(days: 3)),
    );

    return MockScreen(
      title: 'Profil',
      back: false,
      actions: _profileActions(c),
      navIndex: 5,
      body: Column(
        children: [
          _DemoProfileHeader(
            c: c,
            name: demoLea.name,
            username: demoLea.username,
            balance: demoLea.balance,
          ),
          _DemoProfileTabs(c: c, selected: 0),
          Expanded(
            child: ListView(
              controller: c.scroller('studentLoans'),
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                ElevatedButton.icon(
                  onPressed: demoNoop,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nouvelle demande de prêt'),
                ),
                const SizedBox(height: 12),
                c.mark(
                  'loanLender',
                  LoanCard(
                    loan: asLender,
                    currentUserId: _id(demoLea),
                    onAccept: demoNoop,
                    onReject: demoNoop,
                  ),
                ),
                const SizedBox(height: 12),
                c.mark(
                  'loanBorrower',
                  LoanCard(
                    loan: asBorrower,
                    currentUserId: _id(demoLea),
                    onRepay: repaid ? null : demoNoop,
                    onDelete: repaid ? demoNoop : null,
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

class _DemoNotifications extends StatelessWidget {
  const _DemoNotifications({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final allRead = c.flag('allRead');
    final notifications = [
      AppNotification(
        id: 'n0',
        userId: demoMeId,
        type: NotificationType.system,
        title: 'Nouvelle demande de compte',
        body: '${_demoJade.name} demande un compte.',
        isRead: allRead,
        createdAt: now.subtract(const Duration(minutes: 8)),
      ),
      AppNotification(
        id: 'n1',
        userId: demoMeId,
        type: NotificationType.system,
        title: 'Changement de photo demandé',
        body: '${demoChloe.name} a envoyé une nouvelle photo de profil.',
        isRead: allRead || c.flag('read1'),
        createdAt: now.subtract(const Duration(minutes: 40)),
      ),
      AppNotification(
        id: 'n2',
        userId: demoMeId,
        type: NotificationType.transactionReceived,
        title: 'Paiement reçu',
        body: 'Tu as reçu 15 SC. Raison : Merci pour le prêt',
        isRead: true,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: c.mark(
                  'allSeen',
                  OutlinedButton.icon(
                    onPressed: demoNoop,
                    icon: const Icon(Icons.done_all_rounded),
                    label: const Text('Tout vu'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: c.mark(
                  'clearAll',
                  OutlinedButton.icon(
                    onPressed: demoNoop,
                    icon: const Icon(Icons.delete_sweep_rounded),
                    label: const Text('Tout supprimer'),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final (i, notification) in notifications.indexed)
                _Collapse(
                  visible: !(i == 2 && c.flag('removed2')),
                  child: c.mark(
                    'notif_$i',
                    Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: AppTheme.negative,
                            child: const Icon(
                              Icons.delete_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(i == 2 ? -c.number('swipe') : 0, 0),
                          child: Material(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            child: NotificationTile(
                              notification: notification,
                              onTap: demoNoop,
                              onDelete: demoNoop,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DemoPassword extends StatelessWidget {
  const _DemoPassword({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;
    final focus = c.get<String>('focus');
    final next = c.text('new');
    return MockScreen(
      title: 'Changer le mot de passe',
      body: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_rounded, color: accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sécurité du compte',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
                      ),
                      Text(
                        'Le nouveau mot de passe doit contenir au moins 8 '
                        'caractères.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  c.mark(
                    'f_old',
                    MockField(
                      label: 'Mot de passe actuel',
                      prefixIcon: Icons.lock_outline_rounded,
                      obscure: true,
                      value: c.text('old'),
                      focused: focus == 'old',
                    ),
                  ),
                  const SizedBox(height: 14),
                  c.mark(
                    'f_new',
                    MockField(
                      label: 'Nouveau mot de passe',
                      prefixIcon: Icons.key_rounded,
                      obscure: true,
                      value: next,
                      focused: focus == 'new',
                    ),
                  ),
                  if (next.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    c.mark(
                      'strength',
                      PasswordStrengthBar(strength: passwordStrength(next)),
                    ),
                  ],
                  const SizedBox(height: 14),
                  c.mark(
                    'f_confirm',
                    MockField(
                      label: 'Confirmer le mot de passe',
                      prefixIcon: Icons.check_circle_outline_rounded,
                      obscure: true,
                      value: c.text('confirm'),
                      focused: focus == 'confirm',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: c.mark(
          'updatePwd',
          FilledButton.icon(
            onPressed: demoNoop,
            icon: const Icon(Icons.lock_reset_rounded),
            label: const Text('Mettre à jour'),
          ),
        ),
      ),
    );
  }
}

Future<void> playStudentLoans(DemoPlayer p) async {
  p.say('Léa est sollicitée comme prêteuse : « Accepter » ou « Refuser »');
  await p.moveTo('loanLender', at: const Alignment(0.5, 0.86));
  await p.wait(1100);
  await p.tap('loanLender', at: const Alignment(0.5, 0.86));
  p.set('dialog', 'accept');
  await p.wait(600);
  await p.tap('confirmAccept');
  p
    ..set('dialog', null)
    ..set('accepted', true);
  await p.toast('Prêt accepté', ms: 1500);
  p.say('Léa a emprunté à Inès : « Rembourser », en une ou plusieurs fois');
  await p.reveal('loanBorrower', alignment: 0.6);
  await p.tap('loanBorrower', at: const Alignment(0, 0.86));
  p.set('dialog', 'repay');
  await p.wait(600);
  p.say('Le reste à payer est proposé ; on peut saisir moins');
  await p.wait(1200);
  await p.tap('doRepay');
  p
    ..set('dialog', null)
    ..set('repaid', true);
  await p.toast('Remboursement enregistré !', ms: 1600);
  p.say('Un prêt terminé se retire avec la corbeille');
  await p.moveTo('loanBorrower', at: const Alignment(0.88, -0.8));
  await p.wait(1200);
}

Future<void> playProfile(DemoPlayer p) async {
  p.say('Toucher la photo pour la changer (immédiat pour l\'administrateur)');
  await p.moveTo('photo');
  await p.wait(1200);
  p.say('En haut : Paramètres, Blockchain, Classement et Déconnexion');
  await p.moveTo('settingsIcon');
  await p.wait(450);
  await p.moveTo('hubIcon', ms: 350);
  await p.wait(300);
  await p.moveTo('leaderIcon', ms: 350);
  await p.wait(300);
  await p.moveTo('logoutIcon', ms: 350);
  await p.wait(800);
  p.say('« Mot de passe » : changer le mot de passe du compte');
  await p.tap('pwdBtn');
  p.set('page', 'password');
  await p.wait(900);
  p.say('Le mot de passe actuel, puis le nouveau (8 caractères minimum)');
  await p.tap('f_old');
  p.set('focus', 'old');
  await p.type('old', 'Ancien2025', perChar: 70);
  await p.tap('f_new');
  p.set('focus', 'new');
  await p.type('new', 'Nouveau#2026', perChar: 80);
  p.say('La jauge mesure la robustesse ; confirmer, puis « Mettre à jour »');
  await p.tap('f_confirm');
  p.set('focus', 'confirm');
  await p.type('confirm', 'Nouveau#2026', perChar: 55);
  p.set('focus', null);
  await p.tap('updatePwd');
  p.set('page', 'profile');
  await p.toast('Mot de passe modifié !');
}

Future<void> playNotifications(DemoPlayer p) async {
  p.say('Non lue : titre en gras et point doré');
  await p.moveTo('notif_0', at: const Alignment(0.7, -0.4));
  await p.wait(1100);
  p.say('La toucher la marque comme lue ; certaines ouvrent l\'écran utile');
  await p.tap('notif_1', at: const Alignment(-0.3, 0));
  p.set('read1', true);
  await p.wait(1000);
  p.say('Glisser vers la gauche (ou toucher la corbeille) : supprimer');
  final row = p.rectOf('notif_2');
  if (row != null) {
    final y = row.center.dy;
    final steps = [0.0, 70, 150, 240, 330];
    await p.drag(
      [for (final s in steps) Offset(row.right - 40 - s, y)],
      stepMs: 130,
      onPoint: (i) => p.set('swipe', steps[i].toDouble()),
    );
    p.set('removed2', true);
  }
  await p.toast('Notification supprimée.', ms: 1500);
  p.say('« Tout vu » marque tout comme lu ; « Tout supprimer » vide la liste');
  await p.tap('allSeen');
  p.set('allRead', true);
  await p.wait(1000);
  await p.moveTo('clearAll');
  await p.wait(1000);
}

// ═════════════════════════════════════════════════════════════════════════════
// Paramètres d'apparence
// ═════════════════════════════════════════════════════════════════════════════

Widget settingsScene(BuildContext context, DemoController c) {
  final base = Theme.of(context);
  final settings =
      ProviderScope.containerOf(context, listen: false).read(settingsProvider);
  final mode = c.get<String>('themeMode');
  final accentKey = c.get<String>('accent');
  final ambianceKey = c.get<String>('ambiance');

  var theme = base;
  if (mode != null || accentKey != null || ambianceKey != null) {
    final accent = accentKey == null ? settings.accent : accentByKey(accentKey);
    final ambiance =
        ambianceKey == null ? settings.ambiance : ambianceByKey(ambianceKey);
    final dark =
        mode == null ? base.brightness == Brightness.dark : mode == 'dark';
    final raw = dark
        ? AppTheme.dark(accent, ambiance: ambiance, fontKey: settings.fontKey)
        : AppTheme.light(accent, ambiance: ambiance, fontKey: settings.fontKey);
    // Theme.of renvoie un thème « localisé » : on prépare la cible de la
    // même façon, sans quoi la transition ne sait pas mêler les deux.
    theme = ThemeData.localize(
      raw,
      raw.typography.geometryThemeFor(ScriptCategory.englishLike),
    );
  }

  return AnimatedTheme(
    data: theme,
    child: _DemoSettings(c: c, settings: settings),
  );
}

class _DemoSettings extends StatelessWidget {
  const _DemoSettings({required this.c, required this.settings});

  final DemoController c;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final mode = c.get<String>('themeMode') ??
        switch (settings.themeMode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        };
    final accentKey = c.get<String>('accent') ?? settings.accentKey;
    final ambianceKey = c.get<String>('ambiance') ?? settings.ambianceKey;

    Widget title(IconData icon, String text, {String? trailing}) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
          child: Row(
            children: [
              Icon(icon, size: 17, color: primary),
              const SizedBox(width: 8),
              Text(
                text,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (trailing != null)
                Text(
                  trailing,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
            ],
          ),
        );

    Widget modeCard(String key, String label, IconData icon) {
      final selected = mode == key;
      return Expanded(
        child: c.mark(
          'mode_$key',
          AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color:
                  selected ? primary.withValues(alpha: 0.13) : theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.06),
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color:
                      selected ? primary : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? primary : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MockScreen(
      title: 'Paramètres',
      actions: [
        c.mark('resetSettings', const MockIcon(Icons.restart_alt_rounded)),
      ],
      body: ListView(
        controller: c.scroller('settings'),
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          title(Icons.brightness_6_rounded, 'Thème'),
          c.mark(
            'modeRow',
            Row(
              children: [
                modeCard('system', 'Système', Icons.phone_android_rounded),
                const SizedBox(width: 10),
                modeCard('light', 'Clair', Icons.light_mode_rounded),
                const SizedBox(width: 10),
                modeCard('dark', 'Sombre', Icons.dark_mode_rounded),
              ],
            ),
          ),
          const SizedBox(height: 20),
          title(
            Icons.texture_rounded,
            'Ambiance',
            trailing: ambianceByKey(ambianceKey).label,
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.8,
            children: [
              for (final ambiance in appAmbiances)
                c.mark(
                  'amb_${ambiance.key}',
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: ambianceKey == ambiance.key
                          ? primary.withValues(alpha: 0.10)
                          : theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: ambianceKey == ambiance.key
                            ? primary
                            : theme.colorScheme.onSurface
                                .withValues(alpha: 0.06),
                        width: ambianceKey == ambiance.key ? 1.6 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: ambiance.lightScaffold,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(-6, 3),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: ambiance.darkCard,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            ambiance.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: ambianceKey == ambiance.key
                                  ? primary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          title(
            Icons.palette_rounded,
            'Couleur d\'accent',
            trailing: accentByKey(accentKey).label,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final accent in appAccents)
                    c.mark(
                      'acc_${accent.key}',
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [accent.color, accent.dark],
                          ),
                          border: Border.all(
                            color: accentKey == accent.key
                                ? theme.colorScheme.onSurface
                                : Colors.transparent,
                            width: 2.4,
                          ),
                        ),
                        child: accentKey == accent.key
                            ? Icon(
                                Icons.check_rounded,
                                color: AppTheme.onAccent(accent.color),
                                size: 20,
                              )
                            : null,
                      ),
                    ),
                  c.mark(
                    'acc_custom',
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          colors: [
                            Color(0xFFE53935),
                            Color(0xFFFF9800),
                            Color(0xFFFFEB3B),
                            Color(0xFF4CAF50),
                            Color(0xFF03A9F4),
                            Color(0xFF3F51B5),
                            Color(0xFF9C27B0),
                            Color(0xFFE53935),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.colorize_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          title(Icons.visibility_rounded, 'Aperçu'),
          c.mark(
            'preview',
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: demoNoop,
                        child: const Text('Bouton'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: demoNoop,
                        child: const Text('Contour'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          title(Icons.format_size_rounded, 'Taille du texte'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SegmentedButton<double>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0.9, label: Text('Petit')),
                  ButtonSegment(value: 1.0, label: Text('Normal')),
                  ButtonSegment(value: 1.1, label: Text('Grand')),
                ],
                selected: {1.0},
                onSelectionChanged: (_) {},
              ),
            ),
          ),
          const SizedBox(height: 20),
          title(
            Icons.text_fields_rounded,
            'Police',
            trailing: fontByKey(settings.fontKey).label,
          ),
          for (final font in appFonts.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  font.label,
                  style: applyAppFont(font.key, theme.textTheme)
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          const SizedBox(height: 20),
          title(Icons.accessibility_new_rounded, 'Confort'),
          c.mark(
            'comfort',
            Card(
              child: SwitchListTile(
                secondary: const Icon(Icons.animation_rounded),
                title: const Text(
                  'Réduire les animations',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Désactive les effets décoratifs'),
                value: false,
                onChanged: (_) {},
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> playSettings(DemoPlayer p) async {
  p.say('Thème : Système, Clair ou Sombre');
  await p.tap('mode_dark');
  p.set('themeMode', 'dark');
  await p.wait(1300);
  p.say('L\'ambiance colore les fonds et les cartes');
  await p.reveal('amb_forest', alignment: 0.4);
  await p.tap('amb_forest');
  p.set('ambiance', 'forest');
  await p.wait(1300);
  p.say('La couleur d\'accent : boutons, montants, éléments actifs');
  await p.reveal('acc_ocean', alignment: 0.45);
  await p.tap('acc_ocean');
  p.set('accent', 'ocean');
  await p.wait(1300);
  p.say('« Perso » : n\'importe quelle couleur, ou son code (#RRGGBB)');
  await p.moveTo('acc_custom');
  await p.wait(1100);
  p.say('Puis la taille du texte, la police et « Réduire les animations »');
  await p.reveal('comfort', alignment: 0.85);
  await p.moveTo('comfort');
  await p.wait(1300);
  p.say('↺ en haut à droite : revenir aux réglages d\'origine');
  await p.reveal('modeRow', alignment: 0);
  await p.moveTo('resetSettings');
  await p.wait(1100);
}

// ═════════════════════════════════════════════════════════════════════════════
// Classement, comptes et blockchain
// ═════════════════════════════════════════════════════════════════════════════

Widget explorerScene(BuildContext context, DemoController c) {
  return DemoPages(
    page: c.page,
    builder: (page) => switch (page) {
      'accounts' => _DemoDirectory(c: c),
      'explorer' => _DemoExplorer(c: c),
      _ => _DemoLeaderboard(c: c),
    },
  );
}

const _ranking = [demoInes, demoLea, demoChloe, demoHugo, demoAdam, demoNoah];

class _DemoLeaderboard extends StatelessWidget {
  const _DemoLeaderboard({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget spot(DemoPerson person, int rank, Color color, double height) =>
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (rank == 1) const Text('👑', style: TextStyle(fontSize: 22)),
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2.2),
                ),
                child: MockAvatar(person, radius: rank == 1 ? 28 : 22),
              ),
              const SizedBox(height: 6),
              Text(
                person.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
              Text(
                '${DemoAmount.format(person.balance)} SC',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0.55),
                      color.withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: rank == 1 ? 30 : 24,
                      fontWeight: FontWeight.w900,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

    return MockScreen(
      title: 'Classement',
      body: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          c.mark(
            'podium',
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                spot(_ranking[1], 2, const Color(0xFFC9D1D9), 70),
                const SizedBox(width: 10),
                spot(_ranking[0], 1, AppTheme.gold, 92),
                const SizedBox(width: 10),
                spot(_ranking[2], 3, const Color(0xFFCD7F32), 56),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final (i, person) in _ranking.skip(3).indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        '#${i + 4}',
                        style: const TextStyle(
                          color: Color(0xFF8E9AB3),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    MockAvatar(person, radius: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        person.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${DemoAmount.format(person.balance)} SC',
                      style: TextStyle(
                        color: context.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DemoDirectory extends StatelessWidget {
  const _DemoDirectory({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color? podium(int rank) => switch (rank) {
          1 => const Color(0xFFD4AF37),
          2 => const Color(0xFF9AA3B2),
          3 => const Color(0xFFB87333),
          _ => null,
        };

    return MockScreen(
      title: 'Comptes',
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: MockField(
              hint: 'Rechercher un compte',
              prefixIcon: Icons.search_rounded,
              dense: true,
            ),
          ),
          Expanded(
            child: c.mark(
              'directory',
              ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  for (final (i, person) in _ranking.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 28,
                                child: Text(
                                  '${i + 1}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: podium(i + 1) ??
                                        theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              MockAvatar(person, radius: 18),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      person.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '@${person.username}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${person.balance.toStringAsFixed(2)} SC',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: context.accent,
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                            ],
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
    );
  }
}

class _DemoExplorer extends StatelessWidget {
  const _DemoExplorer({required this.c});

  final DemoController c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = c.get<String>('typeFilter') == 'purchase';
    final all = [
      demoFeedTx(
        id: 'e1',
        type: TransactionType.transfer,
        amount: 12,
        from: demoHugo,
        to: demoLea,
        description: 'Cantine',
        method: 'nfc',
        ago: const Duration(minutes: 4),
      ),
      demoFeedTx(
        id: 'e2',
        type: TransactionType.purchase,
        amount: 50,
        from: demoInes,
        description: 'Achat boutique : Joker devoir',
        ago: const Duration(minutes: 30),
      ),
      demoFeedTx(
        id: 'e3',
        type: TransactionType.reward,
        amount: 25,
        to: demoAdam,
        description: 'Bravo pour le projet',
        ago: const Duration(hours: 2),
      ),
    ];
    final visible = filtered
        ? all.where((t) => t.type == TransactionType.purchase).toList()
        : all;
    final users = {
      for (final t in visible) ...[
        if (t.fromUsername != null) t.fromUsername!,
        if (t.toUsername != null) t.toUsername!,
      ],
    }.length;

    return Stack(
      fit: StackFit.expand,
      children: [
        MockScreen(
          title: 'Blockchain',
          actions: [
            c.mark(
              'filters',
              IconButton(
                onPressed: demoNoop,
                icon: Badge(
                  isLabelVisible: filtered,
                  label: const Text('1'),
                  child: const Icon(Icons.tune_rounded),
                ),
              ),
            ),
          ],
          body: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              c.mark(
                'feedHeader',
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.hub_rounded, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                filtered
                                    ? 'Résultats filtrés'
                                    : 'Flux global des transactions',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${visible.length} transaction(s) · '
                                '$users utilisateur(s)',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final tx in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlobalTransactionTile(transaction: tx),
                ),
            ],
          ),
        ),
        _DemoFilterDrawer(c: c, open: c.flag('drawer')),
      ],
    );
  }
}

class _DemoFilterDrawer extends StatelessWidget {
  const _DemoFilterDrawer({required this.c, required this.open});

  final DemoController c;
  final bool open;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.accent;
    final selected = c.get<String>('typeFilter');

    Widget chip(String label, String? value) {
      final active = selected == value;
      final widget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? accent
                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? accent : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
      return value == null ? widget : c.mark('chip_$value', widget);
    }

    Widget section(IconData icon, String title, Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: accent),
                  const SizedBox(width: 7),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        );

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: open ? 1 : 0,
          child: const ColoredBox(color: Color(0x8A000000)),
        ),
        AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          offset: open ? Offset.zero : const Offset(1.05, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.84,
              child: Material(
                color: theme.colorScheme.surface,
                elevation: 8,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, color: accent),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Filtres',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Icon(Icons.close_rounded),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                        children: [
                          section(
                            Icons.search_rounded,
                            'Recherche',
                            const MockField(
                              hint: 'Utilisateur, motif ou note',
                              prefixIcon: Icons.search_rounded,
                              dense: true,
                            ),
                          ),
                          section(
                            Icons.payments_rounded,
                            'Montant',
                            const Row(
                              children: [
                                Expanded(
                                  child: MockField(
                                    label: 'Min.',
                                    suffix: 'SC',
                                    dense: true,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: MockField(
                                    label: 'Max.',
                                    suffix: 'SC',
                                    dense: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          section(
                            Icons.category_rounded,
                            'Type de transaction',
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                chip('Tous', null),
                                chip('Virement', 'transfer'),
                                chip('Achat', 'purchase'),
                                chip('Enchère', 'auction'),
                                chip('Prêt', 'loan'),
                                chip('Récompense', 'reward'),
                                chip('Taxe', 'tax'),
                              ],
                            ),
                          ),
                          section(
                            Icons.contactless_rounded,
                            'Méthode de paiement',
                            Wrap(
                              spacing: 7,
                              children: [
                                chip('Toutes', null),
                                chip('NFC', 'nfc'),
                                chip('QR', 'qr'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          c.mark(
                            'applyFilters',
                            FilledButton.icon(
                              onPressed: demoNoop,
                              icon: const Icon(Icons.check_rounded),
                              label: const Text('Appliquer'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const OutlinedButton(
                            onPressed: demoNoop,
                            child: Text('Réinitialiser'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> playExplore(DemoPlayer p) async {
  p.say('Classement : le podium des trois plus riches, puis tous les comptes');
  await p.moveTo('podium');
  await p.wait(1400);
  p.set('page', 'accounts');
  await p.wait(800);
  p.say('Comptes : l\'annuaire par solde, avec recherche et accès aux fiches');
  await p.moveTo('directory', at: const Alignment(0, -0.6));
  await p.wait(1300);
  p.set('page', 'explorer');
  await p.wait(800);
  p.say('Blockchain : toutes les transactions de tous les comptes, en direct');
  await p.moveTo('feedHeader');
  await p.wait(1200);
  p.say(
      'L\'icône de filtres : recherche, montant, type, méthode, tri, période');
  await p.tap('filters');
  p.set('drawer', true);
  await p.wait(900);
  p.say('Exemple : n\'afficher que les achats');
  await p.tap('chip_purchase');
  p.set('typeFilter', 'purchase');
  await p.wait(700);
  await p.tap('applyFilters');
  p.set('drawer', false);
  await p.wait(800);
  p.say('La pastille compte les filtres actifs');
  await p.moveTo('filters');
  await p.wait(1200);
}

// ═════════════════════════════════════════════════════════════════════════════
// Écran de maintenance
// ═════════════════════════════════════════════════════════════════════════════

Widget maintenanceScene(BuildContext context, DemoController c) {
  final mode = c.get<MaintenanceMode>('mode');
  return Stack(
    fit: StackFit.expand,
    children: [
      DemoHomePage(c: c),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        child: mode == null
            ? const SizedBox.shrink(key: ValueKey('open'))
            : MaintenanceScreen(
                key: ValueKey(mode),
                mode: mode,
                startedAt: c.get<DateTime>('since'),
                preview: true,
              ),
      ),
    ],
  );
}

Future<void> playMaintenance(DemoPlayer p) async {
  p.say('Une maintenance générale commence : cet écran s\'affiche pour tous');
  await p.wait(800);
  p
    ..set('since', DateTime.now())
    ..set('mode', MaintenanceMode.global);
  await p.wait(2400);
  p.say('Rien à faire : l\'application vérifie toute seule');
  await p.wait(1800);
  p.say(
      'Maintenance de l\'administration : seuls les accès admin sont suspendus');
  p.set('mode', MaintenanceMode.admin);
  await p.wait(2600);
  p.say('Fin de la maintenance : l\'application revient d\'elle-même');
  p.set('mode', null);
  await p.wait(600);
  await p.toast('Maintenance terminée : bon retour !');
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../common/animations.dart';
import '../../../common/user_avatar.dart';
import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../models/transaction.dart';
import 'tutorial_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Briques des écrans factices du tutoriel.
//
// Les écrans sont construits avec les vrais composants de l'application
// (Scaffold, AppBar, Card, boutons, thème) pour lui ressembler trait pour
// trait, mais sans aucune donnée réelle ni aucune action.
// ─────────────────────────────────────────────────────────────────────────────

/// Action vide : les boutons factices s'affichent actifs, sans rien faire.
void demoNoop() {}

/// Compte fictif des démonstrations.
class DemoPerson {
  const DemoPerson(this.name, this.username, this.balance, {this.className});

  final String name;
  final String username;
  final double balance;
  final String? className;
}

const demoX = DemoPerson(
  'Utilisateur X',
  'utilisateur.x',
  152.40,
  className: 'TG1',
);
const demoY = DemoPerson(
  'Utilisateur Y',
  'utilisateur.y',
  87.00,
  className: 'TG1',
);
const demoZ = DemoPerson(
  'Utilisateur Z',
  'utilisateur.z',
  240.10,
  className: '1G1',
);
const demoW = DemoPerson('Utilisateur W', 'utilisateur.w', 35.75);
const demoV = DemoPerson(
  'Utilisateur V',
  'utilisateur.v',
  118.20,
  className: '1G1',
);
const demoU = DemoPerson(
  'Utilisateur U',
  'utilisateur.u',
  64.00,
  className: 'TG1',
);

/// Identifiant fictif du compte qui suit le tutoriel, pour les tuiles de
/// transaction (crédit ou débit se lisent par rapport à lui).
const demoMeId = 'demo-moi';

/// Nom de l'administrateur qui suit le tutoriel : les écrans factices sont
/// à son nom.
class DemoIdentity extends InheritedWidget {
  const DemoIdentity({
    super.key,
    required this.name,
    required this.username,
    required super.child,
  });

  final String name;
  final String username;

  static ({String name, String username}) of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DemoIdentity>();
    return (
      name: scope?.name ?? 'Administrateur',
      username: scope?.username ?? 'admin',
    );
  }

  @override
  bool updateShouldNotify(DemoIdentity oldWidget) =>
      oldWidget.name != name || oldWidget.username != username;
}

/// Transaction fictive, pour réutiliser les vraies tuiles de l'application.
Transaction demoTx({
  required String id,
  required TransactionType type,
  required double amount,
  required bool incoming,
  DemoPerson? other,
  String? description,
  Duration ago = const Duration(hours: 2),
  Map<String, dynamic>? metadata,
}) {
  return Transaction(
    id: id,
    fromUserId:
        incoming ? (other == null ? null : 'demo-${other.username}') : demoMeId,
    toUserId:
        incoming ? demoMeId : (other == null ? null : 'demo-${other.username}'),
    fromUsername: incoming ? other?.username : null,
    fromDisplayName: incoming ? other?.name : null,
    toUsername: incoming ? null : other?.username,
    toDisplayName: incoming ? null : other?.name,
    amount: amount,
    type: type,
    description: description,
    metadata: metadata,
    createdAt: DateTime.now().subtract(ago),
  );
}

/// Transaction fictive entre deux élèves (flux de la blockchain).
Transaction demoFeedTx({
  required String id,
  required TransactionType type,
  required double amount,
  DemoPerson? from,
  DemoPerson? to,
  String? description,
  String? method,
  Duration ago = const Duration(minutes: 30),
}) {
  return Transaction(
    id: id,
    fromUserId: from == null ? null : 'demo-${from.username}',
    toUserId: to == null ? null : 'demo-${to.username}',
    fromUsername: from?.username,
    fromDisplayName: from?.name,
    toUsername: to?.username,
    toDisplayName: to?.name,
    amount: amount,
    type: type,
    description: description,
    metadata: method == null ? null : {'payment_method': method},
    createdAt: DateTime.now().subtract(ago),
  );
}

// ── Écran ────────────────────────────────────────────────────────────────────

/// Écran factice : un vrai Scaffold dans le thème de l'application.
class MockScreen extends StatelessWidget {
  const MockScreen({
    super.key,
    this.title,
    this.titleWidget,
    this.back = true,
    this.actions = const [],
    this.bottom,
    required this.body,
    this.navIndex,
    this.floatingActionButton,
    this.bottomBar,
  });

  final String? title;
  final Widget? titleWidget;
  final bool back;
  final List<Widget> actions;
  final PreferredSizeWidget? bottom;
  final Widget body;

  /// Onglet sélectionné de la barre de navigation, ou null sans barre.
  final int? navIndex;
  final Widget? floatingActionButton;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        primary: false,
        automaticallyImplyLeading: false,
        leading: back
            ? const IconButton(onPressed: demoNoop, icon: BackButtonIcon())
            : null,
        title: titleWidget ?? (title == null ? null : Text(title!)),
        actions: actions,
        bottom: bottom,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar:
          bottomBar ?? (navIndex == null ? null : MockNavBar(index: navIndex!)),
    );
  }
}

/// Barre de navigation principale (Accueil, Portefeuille, Payer…).
class MockNavBar extends StatelessWidget {
  const MockNavBar({super.key, required this.index});

  final int index;

  static const _tabs = [
    (Icons.home_outlined, Icons.home_rounded, 'Accueil'),
    (
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded,
      'Portefeuille',
    ),
    (Icons.qr_code_scanner_outlined, Icons.qr_code_scanner_rounded, 'Payer'),
    (Icons.storefront_outlined, Icons.storefront_rounded, 'Marché'),
    (Icons.chat_bubble_outline_rounded, Icons.chat_rounded, 'Chat'),
    (Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.0,
      child: NavigationBar(
        selectedIndex: index,
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.$1),
              selectedIcon: Icon(tab.$2),
              label: tab.$3,
            ),
        ],
      ),
    );
  }
}

/// Bouton d'icône factice d'une barre d'application.
class MockIcon extends StatelessWidget {
  const MockIcon(this.icon, {super.key, this.badge = 0, this.badgeColor});

  final IconData icon;
  final int badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(onPressed: demoNoop, icon: Icon(icon)),
        if (badge > 0)
          Positioned(
            right: 7,
            top: 7,
            child: AnimatedBadge(
              count: badge,
              color: badgeColor ?? AppTheme.negative,
            ),
          ),
      ],
    );
  }
}

/// Titre animé de l'accueil (« S » doré + « SES Coin »).
class MockBrandTitle extends StatelessWidget {
  const MockBrandTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, Color.lerp(accent, Colors.black, 0.28)!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Text(
            'S',
            style: GoogleFonts.spaceGrotesk(
              color: AppTheme.onAccent(accent),
              fontWeight: FontWeight.w700,
              fontSize: 15,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          'SES Coin',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ── Champs ───────────────────────────────────────────────────────────────────

/// Champ de saisie factice : la même décoration qu'un vrai champ, le texte
/// étant écrit par le scénario.
class MockField extends StatelessWidget {
  const MockField({
    super.key,
    this.label,
    this.hint,
    this.value = '',
    this.suffix,
    this.prefixIcon,
    this.suffixIcon,
    this.helper,
    this.focused = false,
    this.obscure = false,
    this.maxLines = 1,
    this.dense = false,
    this.center = false,
  });

  final String? label;
  final String? hint;
  final String value;
  final String? suffix;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? helper;
  final bool focused;
  final bool obscure;
  final int maxLines;
  final bool dense;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final shown = obscure ? '•' * value.length : value;
    return InputDecorator(
      isFocused: focused,
      isEmpty: value.isEmpty,
      textAlign: center ? TextAlign.center : TextAlign.start,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
        suffixIcon: suffixIcon,
        helperText: helper,
        isDense: dense,
      ),
      child: Row(
        mainAxisAlignment:
            center ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              shown,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          if (focused) const DemoCaret(),
        ],
      ),
    );
  }
}

/// Pastille de texte (statut, catégorie, stock…).
class MockPill extends StatelessWidget {
  const MockPill(this.label,
      {super.key, required this.color, this.square = false});

  final String label;
  final Color color;

  /// Coins légèrement arrondis plutôt qu'en pastille.
  final bool square;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: square ? 6 : 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(square ? 5 : 999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: square ? 10 : 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Puce sélectionnable (durée, classe, filtre…).
class MockChoice extends StatelessWidget {
  const MockChoice(this.label, {super.key, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected
            ? accent.withValues(alpha: 0.16)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? accent : Colors.transparent,
          width: 1.4,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: selected ? accent : null,
        ),
      ),
    );
  }
}

// ── Fenêtres ─────────────────────────────────────────────────────────────────

/// Feuille du bas, avec sa poignée.
class MockSheet extends StatelessWidget {
  const MockSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color:
          theme.bottomSheetTheme.backgroundColor ?? theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Feuille d'options flottante du chat (« Options du message »…).
class MockOptionsSheet extends StatelessWidget {
  const MockOptionsSheet({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Text(
              title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Ligne d'action d'une feuille d'options.
class MockOptionTile extends StatelessWidget {
  const MockOptionTile({
    super.key,
    required this.icon,
    required this.label,
    this.color,
    this.badge,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tint.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(icon, color: tint, size: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color ?? theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (badge != null) MockPill(badge!, color: tint),
          ],
        ),
      ),
    );
  }
}

/// Ligne d'un menu déroulant factice.
class MockMenuItem {
  const MockMenuItem(this.id, this.icon, this.label, {this.color});

  /// Repère de la ligne, pour que le doigt puisse la toucher.
  final String id;
  final IconData icon;
  final String label;
  final Color? color;
}

/// Menu déroulant ouvert à la place du bouton ⋮ dont [rect] est la zone.
class DemoMenuLayer extends StatelessWidget {
  const DemoMenuLayer({
    super.key,
    required this.controller,
    required this.rect,
    required this.items,
  });

  final DemoController controller;
  final Rect? rect;
  final List<MockMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final r = rect;
    final theme = Theme.of(context);
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            if (r != null)
              Positioned(
                top: r.top,
                right: (constraints.maxWidth - r.right).clamp(
                  6.0,
                  constraints.maxWidth,
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.scale(
                      scale: 0.9 + 0.1 * t,
                      alignment: Alignment.topRight,
                      child: child,
                    ),
                  ),
                  child: Material(
                    elevation: 6,
                    color: theme.colorScheme.surfaceContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: IntrinsicWidth(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final item in items)
                              controller.mark(
                                item.id,
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        item.icon,
                                        size: 22,
                                        color: item.color ??
                                            theme.colorScheme.primary,
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        item.label,
                                        style: theme.textTheme.bodyLarge,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
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

// ── Images factices ──────────────────────────────────────────────────────────

/// Photo factice : un dégradé et un visage stylisé.
class MockPhoto extends StatelessWidget {
  const MockPhoto({
    super.key,
    this.size,
    this.colors = const [Color(0xFF6C5CE7), Color(0xFFE84393)],
    this.radius = 20,
  });

  /// null = toute la place disponible.
  final double? size;
  final List<Color> colors;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Icon(
          Icons.face_retouching_natural_rounded,
          color: Colors.white.withValues(alpha: 0.92),
          size: math.min(constraints.maxWidth, constraints.maxHeight) * 0.55,
        ),
      ),
    );
  }
}

/// Avatar d'un compte fictif (initiales sur couleur), comme dans l'app.
class MockAvatar extends StatelessWidget {
  const MockAvatar(this.person, {super.key, this.radius = 21});

  final DemoPerson person;
  final double radius;

  @override
  Widget build(BuildContext context) =>
      UserAvatar(username: person.username, radius: radius);
}

// ── Graphique du cours ───────────────────────────────────────────────────────

/// Série modifiable du graphique de cours.
enum DemoSeries { demand, supply, price }

/// Graphique demande / offre / prix, dessiné comme sur l'accueil.
class DemoMarketChart extends StatelessWidget {
  const DemoMarketChart({
    super.key,
    required this.demand,
    required this.supply,
    required this.price,
    this.selectedIndex,
    this.editing,
    this.dragIndex,
    this.height = 190,
  });

  final List<double> demand;
  final List<double> supply;
  final List<double> price;

  /// Colonne touchée : sa valeur de prix exacte est affichée.
  final int? selectedIndex;

  /// Série en cours de modification (écran « Modifier le cours »).
  final DemoSeries? editing;
  final int? dragIndex;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxVolume = math.max(
      math.max(demand.reduce(math.max), supply.reduce(math.max)),
      1.0,
    );
    final maxPrice = editing == null
        ? math.max(10.0, (price.reduce(math.max) / 10).ceil() * 10.0)
        : demoNiceCeil(price.reduce(math.max) * 1.3);
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _DemoChartPainter(
          demand: demand,
          supply: supply,
          price: price,
          maxVolume: editing == null
              ? maxVolume
              : demoNiceCeil(maxVolume * 1.3, minimum: 100),
          maxPrice: maxPrice,
          accent: theme.colorScheme.primary,
          surface: theme.cardColor,
          grid: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          selectedIndex: selectedIndex,
          editing: editing,
          dragIndex: dragIndex,
        ),
      ),
    );
  }
}

class _DemoChartPainter extends CustomPainter {
  _DemoChartPainter({
    required this.demand,
    required this.supply,
    required this.price,
    required this.maxVolume,
    required this.maxPrice,
    required this.accent,
    required this.surface,
    required this.grid,
    required this.selectedIndex,
    required this.editing,
    required this.dragIndex,
  });

  final List<double> demand;
  final List<double> supply;
  final List<double> price;
  final double maxVolume;
  final double maxPrice;
  final Color accent;
  final Color surface;
  final Color grid;
  final int? selectedIndex;
  final DemoSeries? editing;
  final int? dragIndex;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 18.0;
    const bottom = 4.0;
    final chartHeight = size.height - top - bottom;
    final chartBottom = size.height - bottom;
    final count = price.length;
    final group = size.width / count;
    final barWidth = group * 0.26;
    const gap = 3.0;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = top + chartHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (dragIndex != null) {
      canvas.drawRect(
        Rect.fromLTWH(group * dragIndex!, 0, group, size.height),
        Paint()..color = accent.withValues(alpha: 0.07),
      );
    }

    double alpha(DemoSeries series) =>
        editing == null || editing == series ? 0.9 : 0.25;

    final demandPaint = Paint()
      ..color = AppTheme.negative.withValues(alpha: alpha(DemoSeries.demand));
    final supplyPaint = Paint()
      ..color = AppTheme.positive.withValues(alpha: alpha(DemoSeries.supply));
    final linePath = Path();
    final points = <Offset>[];

    for (var i = 0; i < count; i++) {
      final cx = group * i + group / 2;
      final dh = (demand[i] / maxVolume).clamp(0.0, 1.0) * chartHeight * 0.85;
      final sh = (supply[i] / maxVolume).clamp(0.0, 1.0) * chartHeight * 0.85;
      if (dh > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(
                cx - barWidth - gap / 2, chartBottom - dh, barWidth, dh),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          demandPaint,
        );
      }
      if (sh > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(cx + gap / 2, chartBottom - sh, barWidth, sh),
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          supplyPaint,
        );
      }
      final py = chartBottom -
          (price[i] / maxPrice).clamp(0.0, 1.0) * chartHeight * 0.94;
      final point = Offset(cx, py);
      points.add(point);
      if (i == 0) {
        linePath.moveTo(point.dx, point.dy);
      } else {
        linePath.lineTo(point.dx, point.dy);
      }
    }

    final priceAlpha = alpha(DemoSeries.price);
    canvas.drawPath(
      linePath,
      Paint()
        ..color = surface
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      linePath,
      Paint()
        ..color = accent.withValues(alpha: priceAlpha == 0.9 ? 1 : 0.3)
        ..strokeWidth = editing == DemoSeries.price ? 3 : 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // Points du prix, ou poignées de la série modifiée.
    final handleColor = switch (editing) {
      DemoSeries.demand => AppTheme.negative,
      DemoSeries.supply => AppTheme.positive,
      _ => accent,
    };
    for (var i = 0; i < count; i++) {
      final center = switch (editing) {
        DemoSeries.demand => Offset(
            group * i + group / 2 - gap / 2 - barWidth / 2,
            chartBottom -
                (demand[i] / maxVolume).clamp(0.0, 1.0) * chartHeight * 0.85,
          ),
        DemoSeries.supply => Offset(
            group * i + group / 2 + gap / 2 + barWidth / 2,
            chartBottom -
                (supply[i] / maxVolume).clamp(0.0, 1.0) * chartHeight * 0.85,
          ),
        _ => points[i],
      };
      final radius = editing == null ? 3.4 : (i == dragIndex ? 7.5 : 5.0);
      canvas.drawCircle(center, radius, Paint()..color = handleColor);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = surface
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }

    final badgeIndex =
        selectedIndex ?? (editing == DemoSeries.price ? dragIndex : null);
    if (badgeIndex != null) {
      final anchor = points[badgeIndex];
      final tp = TextPainter(
        text: TextSpan(
          text:
              '${price[badgeIndex].toStringAsFixed(2).replaceAll('.', ',')} €',
          style: TextStyle(
            color: accent,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            fontFeatures: const [ui.FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx =
          (anchor.dx - tp.width / 2).clamp(2.0, size.width - tp.width - 2);
      final above = anchor.dy - tp.height - 16;
      final dy = above < 2 ? anchor.dy + 12 : above;
      final bg = RRect.fromRectAndRadius(
        Rect.fromLTWH(dx - 6, dy - 4, tp.width + 12, tp.height + 8),
        const Radius.circular(8),
      );
      canvas.drawRRect(bg, Paint()..color = surface.withValues(alpha: 0.95));
      canvas.drawRRect(
        bg,
        Paint()
          ..color = accent.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _DemoChartPainter oldDelegate) => true;
}

/// Pastilles de légende du graphique (Demande, Offre, Prix).
class DemoChartLegend extends StatelessWidget {
  const DemoChartLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget pill(Color color, String label, {bool line = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: line ? 14 : 9,
                height: line ? 3 : 9,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(line ? 2 : 3),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        );
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        pill(AppTheme.negative, 'Demande'),
        pill(AppTheme.positive, 'Offre'),
        pill(theme.colorScheme.primary, 'Prix', line: true),
      ],
    );
  }
}

/// Valeurs de départ du cours dans les démonstrations.
const demoDemand = <double>[0, 189, 180, 147, 205, 160, 120, 140, 0, 0];
const demoSupply = <double>[0, 161, 29, 138, 139, 150, 90, 110, 0, 0];
const demoPrice = <double>[1.0, 1.1, 1.6, 1.4, 1.9, 2.1, 1.8, 2.0, 2.0, 2.0];

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ses_coin/core/theme.dart';
import 'package:ses_coin/providers/auth_provider.dart';
import 'package:ses_coin/providers/settings_provider.dart';
import 'package:ses_coin/screens/admin/tutorial/admin_tutorial_screen.dart';
import 'package:ses_coin/screens/admin/tutorial/tutorial_engine.dart';
import 'package:ses_coin/screens/admin/tutorial/tutorial_mock.dart';
import 'package:ses_coin/screens/admin/tutorial/tutorial_steps.dart';

/// Joueur qui note les éléments introuvables : le doigt les ignorerait
/// sans rien dire.
class _CheckingPlayer extends DemoPlayer {
  _CheckingPlayer(super.c, super.stageKey);

  final missing = <String>{};

  @override
  Rect? rectOf(String id) {
    final rect = super.rectOf(id);
    if (rect == null) missing.add(id);
    return rect;
  }
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;

    // Une vraie police quand la machine en fournit une : la police de test,
    // aux lettres toutes carrées, ferait déborder des lignes qui tiennent
    // sur un vrai téléphone.
    final loader = FontLoader('Roboto');
    var found = false;
    for (final name in ['segoeui', 'segoeuib', 'seguisb', 'segoeuil']) {
      final file = File('C:/Windows/Fonts/$name.ttf');
      if (!file.existsSync()) continue;
      found = true;
      loader.addFont(
        file.readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
      );
    }
    if (found) await loader.load();
  });

  for (final (i, step) in tutorialSteps.indexed) {
    testWidgets('Étape ${i + 1} : ${step.title}', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      // Taille du plateau dans le tutoriel, sur un téléphone de 390 × 844.
      tester.view
        ..physicalSize = const Size(390 * 3, 690 * 3)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final controller = DemoController(step.initial);
      final stageKey = GlobalKey();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentUserIdProvider.overrideWithValue(demoMeId),
          ],
          child: MaterialApp(
            theme: AppTheme.light(accentByKey('flame')),
            home: Scaffold(
              body: DemoIdentity(
                name: 'Admin Test',
                username: 'admin',
                child: DemoStage(
                  controller: controller,
                  stageKey: stageKey,
                  focus: step.focus,
                  scene: ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => step.scene(context, controller),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      final focus = step.focus;
      if (focus != null) {
        expect(
          demoRectOf(stageKey, controller.anchor(focus)),
          isNotNull,
          reason: 'élément mis en avant introuvable : $focus',
        );
      }

      final script = step.script;
      if (script != null) {
        final player = _CheckingPlayer(controller, stageKey);
        var done = false;
        Object? error;
        script(player).then(
          (_) => done = true,
          onError: (Object e) {
            error = e;
            done = true;
          },
        );
        for (var t = 0; !done && t < 180000; t += 50) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(done, isTrue, reason: 'exemple jamais terminé');
        expect(error, isNull);
        expect(player.missing, isEmpty, reason: 'éléments introuvables');
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
      controller.dispose();
    });
  }

  for (final size in const [Size(390, 844), Size(360, 740)]) {
    testWidgets('Écran du tutoriel (${size.width.toInt()} de large)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      tester.view
        ..physicalSize = size * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: AppTheme.light(accentByKey('flame')),
            home: const AdminTutorialScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Bienvenue dans le tutoriel'), findsOneWidget);
      expect(find.text('Quitter le tutoriel'), findsOneWidget);
      expect(find.text('Retour'), findsOneWidget);
      expect(find.text('Suivant'), findsOneWidget);

      // L'exemple se joue, puis la bulle propose de le rejouer.
      await tester.tap(find.text('Jouer l\'exemple'));
      for (var t = 0; t < 30000; t += 100) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('Rejouer l\'exemple').evaluate().isNotEmpty) break;
      }
      expect(find.text('Rejouer l\'exemple'), findsOneWidget);

      await tester.tap(find.text('Suivant'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('L\'écran d\'accueil'), findsOneWidget);

      // Arrêter un exemple en cours.
      await tester.tap(find.text('Jouer l\'exemple'));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Arrêter'), findsOneWidget);
      await tester.tap(find.text('Arrêter'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Jouer l\'exemple'), findsOneWidget);

      await tester.tap(find.text('Retour'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Bienvenue dans le tutoriel'), findsOneWidget);

      // Sommaire : aller directement à une étape.
      await tester.tap(find.text('Sommaire'));
      await tester.pump(const Duration(seconds: 1));
      final target = find.text('Taxer tout le monde');
      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(target.last);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Taxer tout le monde'), findsWidgets);
      expect(find.text('Étape 25 / ${tutorialSteps.length}'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}

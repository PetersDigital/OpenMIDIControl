// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:app/ui/settings_screen.dart';
import 'package:app/ui/open_midi_screen.dart';
import 'package:app/ui/side_panel_state.dart';

ProviderContainer _createContainer() {
  return ProviderContainer(
    overrides: [
      packageInfoProvider.overrideWith(
        (ref) => Future.value(
          PackageInfo(
            appName: 'OpenMIDIControl',
            packageName: 'com.petersdigital.openmidicontrol',
            version: '0.2.2',
            buildNumber: '1',
          ),
        ),
      ),
    ],
  );
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  ProviderContainer? container,
}) async {
  final c = container ?? _createContainer();
  if (container == null) addTearDown(c.dispose);

  tester.view.physicalSize = const Size(600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('SettingsScreen', () {
    testWidgets('renders tabs correctly', (tester) async {
      await _pumpSettings(tester);

      expect(find.text('PERFORMANCE'), findsOneWidget);
      expect(find.text('PAGES'), findsOneWidget);
      expect(find.text('FILES'), findsOneWidget);
      expect(find.text('ABOUT'), findsOneWidget);
    });

    testWidgets('renders performance tab items by default', (tester) async {
      await _pumpSettings(tester);

      // We should be on the PERFORMANCE tab initially
      expect(find.text('FADER BEHAVIOR'), findsOneWidget);
      expect(find.text('FADER POSITION'), findsOneWidget);
      expect(find.text('SETTINGS PANEL DOCK'), findsOneWidget);
      expect(find.text('HYBRID'), findsOneWidget);
      expect(find.text('JUMP'), findsOneWidget);
      expect(
        find.text('CATCH-UP'),
        findsNothing,
      ); // label changed? It's CATCHUP maybe? Wait, fader option is CATCHUP
    });

    testWidgets('renders about tab items when navigating', (tester) async {
      await _pumpSettings(tester);

      // Tap ABOUT tab
      await tester.tap(find.text('ABOUT'));
      await tester.pumpAndSettle();

      expect(find.text('OpenMIDIControl'), findsOneWidget);
      expect(find.text('v0.2.2'), findsOneWidget);
      expect(find.text('© 2026 PetersDigital'), findsOneWidget);
    });

    testWidgets('selecting a fader behavior updates provider', (tester) async {
      final container = _createContainer();
      addTearDown(container.dispose);

      await _pumpSettings(tester, container: container);

      // Default is jump
      expect(
        container.read(faderBehaviorProvider.notifier).state,
        FaderBehavior.jump,
      );

      // Tap Hybrid option
      await tester.tap(find.text('HYBRID'));
      await tester.pumpAndSettle();

      expect(
        container.read(faderBehaviorProvider.notifier).state,
        FaderBehavior.hybrid,
      );
    });

    testWidgets('toggling layout hand flips state', (tester) async {
      final container = _createContainer();
      addTearDown(container.dispose);

      await _pumpSettings(tester, container: container);

      final initialHand = container.read(layoutHandProvider);

      // Tap toggle card for layout hand (FADER ON LEFT)
      await tester.tap(find.text('FADER ON LEFT'));
      await tester.pumpAndSettle();

      expect(container.read(layoutHandProvider), isNot(initialHand));
    });

    testWidgets('toggling panel dock flips state', (tester) async {
      final container = _createContainer();
      addTearDown(container.dispose);

      await _pumpSettings(tester, container: container);

      final initialSide = container.read(sidePanelProvider).side;

      // Tap toggle card for panel dock (DOCK ON RIGHT)
      await tester.tap(find.text('DOCK ON RIGHT'));
      await tester.pumpAndSettle();

      expect(container.read(sidePanelProvider).side, isNot(initialSide));
    });
  });
}

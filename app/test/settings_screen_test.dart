// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:app/ui/settings_screen.dart';
import 'package:app/ui/open_midi_screen.dart';

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

Future<void> _pumpSettings(WidgetTester tester) async {
  final container = _createContainer();
  addTearDown(container.dispose);

  tester.view.physicalSize = const Size(600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('SettingsScreen', () {
    testWidgets('renders header with app name and version', (tester) async {
      await _pumpSettings(tester);

      expect(find.text('OpenMIDIControl'), findsOneWidget);
      expect(find.text('v0.2.2'), findsOneWidget);
      expect(find.text('© PetersDigital'), findsOneWidget);
    });

    testWidgets('renders all 3 fader behavior options', (tester) async {
      await _pumpSettings(tester);

      expect(find.text('HYBRID'), findsOneWidget);
      expect(find.text('JUMP'), findsOneWidget);
      expect(find.text('CATCHUP'), findsOneWidget);
      expect(find.text('FADER CONFIGURATION'), findsOneWidget);
    });

    testWidgets('selecting a fader behavior updates provider', (tester) async {
      final container = _createContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

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

    testWidgets('renders layout hand and panel position toggles', (
      tester,
    ) async {
      await _pumpSettings(tester);

      expect(find.textContaining('FADER ON'), findsOneWidget);
      expect(find.textContaining('DOCK ON'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNWidgets(2));
    });

    testWidgets('toggling layout hand flips state', (tester) async {
      final container = _createContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final initialHand = container.read(layoutHandProvider);
      // Tap first SwitchListTile (Layout Hand)
      await tester.tap(find.byType(SwitchListTile).at(0));
      await tester.pumpAndSettle();

      expect(container.read(layoutHandProvider), isNot(initialHand));
    });

    testWidgets('renders layout hand toggle', (WidgetTester tester) async {
      await _pumpSettings(tester);

      expect(find.text('LAYOUT'), findsOneWidget);
      expect(find.textContaining('FADER ON'), findsOneWidget);
    });

    testWidgets('renders panel position toggle', (tester) async {
      await _pumpSettings(tester);

      // Scroll to ensure it's in view
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('PANEL POSITION'), findsOneWidget);
      expect(find.textContaining('DOCK ON'), findsOneWidget);
    });
  });
}

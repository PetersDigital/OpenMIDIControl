// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/ui/open_midi_screen.dart';

void main() {
  group('Transport Controls Visibility', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Widget buildWidget(WidgetTester tester) {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      return ProviderScope(
        overrides: [
          firstLaunchCheckProvider.overrideWith((ref) => Future.value(false)),
        ],
        child: const MaterialApp(home: OpenMIDIMainScreen()),
      );
    }

    testWidgets('transport controls are hidden by default if not first launch', (
      WidgetTester tester,
    ) async {
      await prefs.setBool('hasLaunched', true);

      await tester.pumpWidget(buildWidget(tester));
      await tester.pumpAndSettle();

      // Should not find the transport grid (represented by _StatusDisplay or specific icons)
      // _StatusDisplay has label "TEMPO"
      expect(find.text('TEMPO'), findsNothing);
    });

    testWidgets('toggling transport visibility via top bar button', (
      WidgetTester tester,
    ) async {
      await prefs.setBool('hasLaunched', true);

      await tester.pumpWidget(buildWidget(tester));
      await tester.pumpAndSettle();

      expect(find.text('TEMPO'), findsNothing);

      // Find the toggle button by tooltip
      final toggleButton = find.byTooltip('Toggle Transport');
      expect(toggleButton, findsOneWidget);

      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(find.text('TEMPO').hitTestable(), findsWidgets);

      // Toggle again to hide
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(find.text('TEMPO'), findsNothing);
    });

    testWidgets('first launch behavior: show for 2 seconds then hide', (
      WidgetTester tester,
    ) async {
      // SharedPreferences is empty, so it's first launch
      SharedPreferences.setMockInitialValues({});

      // Manually pump with first launch override
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Ensure we return true for first launch check
            firstLaunchCheckProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(home: OpenMIDIMainScreen()),
        ),
      );

      // Wait for the future to complete and first frame callback to fire
      await tester.pump();
      await tester.pump(); // Second pump to catch state change after future

      // Should be visible initially on first launch
      await tester.pumpAndSettle();
      expect(find.text('TEMPO').hitTestable(), findsWidgets);

      // Wait for 2 seconds
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Should be hidden now
      expect(find.text('TEMPO'), findsNothing);
    });

    testWidgets('toggling transport visibility in landscape layout', (
      WidgetTester tester,
    ) async {
      await prefs.setBool('hasLaunched', true);

      // Set to mobile landscape size (shortest side < 600, width enough for Row)
      tester.view.physicalSize = const Size(1100, 550);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            firstLaunchCheckProvider.overrideWith((ref) => Future.value(false)),
          ],
          child: const MaterialApp(home: OpenMIDIMainScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Initially SHOWN in landscape (due to auto-toggle logic in OpenMIDIMainScreen)
      expect(find.text('TEMPO').hitTestable(), findsWidgets);
      expect(
        find.byKey(const ValueKey('transport_toggle_button_panel')),
        findsOneWidget,
      );

      // Tap panel button to hide
      await tester.tap(
        find.byKey(const ValueKey('transport_toggle_button_panel')),
      );
      await tester.pumpAndSettle();

      expect(find.text('TEMPO'), findsNothing);
      expect(
        find.byKey(const ValueKey('transport_toggle_button_floating')),
        findsOneWidget,
      );

      // Tap floating button to show again
      await tester.tap(
        find.byKey(const ValueKey('transport_toggle_button_floating')),
      );
      await tester.pumpAndSettle();

      expect(find.text('TEMPO').hitTestable(), findsWidgets);
      expect(
        find.byKey(const ValueKey('transport_toggle_button_panel')),
        findsOneWidget,
      );
    });
  });
}

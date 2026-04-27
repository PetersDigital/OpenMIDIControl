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

      return const ProviderScope(
        child: MaterialApp(home: OpenMIDIMainScreen()),
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

      expect(find.text('TEMPO'), findsWidgets);

      // Toggle again to hide
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(find.text('TEMPO'), findsNothing);
    });

    testWidgets('first launch behavior: show for 2 seconds then hide', (
      WidgetTester tester,
    ) async {
      // SharedPreferences is empty, so it's first launch

      await tester.pumpWidget(buildWidget(tester));

      // Wait for the first frame callback
      await tester.pump();

      // Should be visible initially on first launch
      expect(find.text('TEMPO'), findsWidgets);

      // Wait for 2 seconds
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Should be hidden now
      expect(find.text('TEMPO'), findsNothing);

      // Verify hasLaunched is set to true
      expect(prefs.getBool('hasLaunched'), isTrue);
    });
  });
}

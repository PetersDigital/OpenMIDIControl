// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/ui/open_midi_screen.dart';

void main() {
  group('Transport Controls Visibility', () {
    late SharedPreferences prefs;

    setUp(() async {
      const channel = MethodChannel('com.petersdigital.openmidicontrol/midi');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'resetMidiTransport') return null;
            return null;
          });

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
      // _StatusDisplay has label "TEMPO" - now check for play icon
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    testWidgets('toggling transport visibility via top bar button', (
      WidgetTester tester,
    ) async {
      await prefs.setBool('hasLaunched', true);

      await tester.pumpWidget(buildWidget(tester));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow), findsNothing);

      // Find the toggle button by tooltip
      final toggleButton = find.byTooltip('Toggle Transport');
      expect(toggleButton, findsOneWidget);

      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow).hitTestable(), findsWidgets);

      // Toggle again to hide
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow), findsNothing);
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
      expect(find.byIcon(Icons.play_arrow).hitTestable(), findsWidgets);

      // Wait for 2 seconds
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Should be hidden now
      expect(find.byIcon(Icons.play_arrow), findsNothing);
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
      expect(find.byIcon(Icons.play_arrow).hitTestable(), findsWidgets);
      expect(
        find.byKey(const ValueKey('transport_toggle_button_landscape')),
        findsOneWidget,
      );

      // Tap panel button to hide
      await tester.tap(
        find.byKey(const ValueKey('transport_toggle_button_landscape')),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow), findsNothing);
      expect(
        find.byKey(const ValueKey('transport_toggle_button_landscape')),
        findsOneWidget,
      );

      // Tap floating button to show again
      await tester.tap(
        find.byKey(const ValueKey('transport_toggle_button_landscape')),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow).hitTestable(), findsWidgets);
      expect(
        find.byKey(const ValueKey('transport_toggle_button_landscape')),
        findsOneWidget,
      );
    });

    testWidgets('syncing transport visibility on multiple rotations', (
      WidgetTester tester,
    ) async {
      await prefs.setBool('hasLaunched', true);

      // 1. Start in Portrait
      tester.view.physicalSize = const Size(600, 800);
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

      // Initially hidden in portrait
      expect(find.byIcon(Icons.play_arrow), findsNothing);

      // 2. Rotate to Landscape
      tester.view.physicalSize = const Size(1100, 550);
      await tester.pump(); // Trigger build
      await tester.pumpAndSettle(); // Allow post-frame callback

      // Should be visible in landscape
      expect(find.byIcon(Icons.play_arrow).hitTestable(), findsWidgets);

      // 3. Rotate back to Portrait
      tester.view.physicalSize = const Size(600, 800);
      await tester.pump();
      await tester.pumpAndSettle();

      // Should be hidden in portrait again
      expect(find.byIcon(Icons.play_arrow), findsNothing);

      // 4. Rotate to Landscape AGAIN (Verifies flag reset)
      tester.view.physicalSize = const Size(1100, 550);
      await tester.pump();
      await tester.pumpAndSettle();

      // Should be visible in landscape again
      expect(find.byIcon(Icons.play_arrow).hitTestable(), findsWidgets);
    });
  });
}

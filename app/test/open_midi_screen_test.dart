// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/ui/hybrid_touch_fader.dart';
import 'package:app/ui/midi_service.dart';
import 'package:app/ui/open_midi_screen.dart';

void main() {
  group('HybridTouchFader', () {
    Future<void> pumpFader(
      WidgetTester tester, {
      int ccNumber = 1,
      String label = 'MOD',
      FaderBehavior behavior = FaderBehavior.jump,
      double initialValue = 0.5,
      bool isMobile = true,
    }) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 400,
                child: HybridTouchFader(
                  ccNumber: ccNumber,
                  label: label,
                  activeColor: Colors.blue,
                  labelColor: Colors.white,
                  behavior: behavior,
                  initialValue: initialValue,
                  isMobile: isMobile,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders with correct CC label', (tester) async {
      await pumpFader(tester, ccNumber: 7, label: 'VOL');

      expect(find.text('VOL'), findsOneWidget);
    });

    testWidgets('renders with initial value display (padded to 3 chars)', (
      tester,
    ) async {
      await pumpFader(tester, initialValue: 0.5);

      // Value display uses .padLeft(3, ' '), so 64 becomes " 64"
      expect(find.textContaining('64'), findsOneWidget);
    });

    testWidgets('renders with full value display', (tester) async {
      await pumpFader(tester, initialValue: 1.0);

      expect(find.text('127'), findsOneWidget);
    });

    testWidgets('renders with zero value display (padded to 3 chars)', (
      tester,
    ) async {
      await pumpFader(tester, initialValue: 0.0);

      // 0 becomes "  0" with padding
      expect(find.textContaining('0'), findsOneWidget);
    });

    testWidgets(
      'jump behavior animates to external CC updates using spring retargeting',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 200,
                  height: 400,
                  child: HybridTouchFader(
                    ccNumber: 1,
                    label: 'MOD',
                    activeColor: Colors.blue,
                    labelColor: Colors.white,
                    behavior: FaderBehavior.jump,
                    initialValue: 0.0,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('  0'), findsOneWidget);

        container.read(controlStateProvider.notifier).updateCC("0:1", 127);

        await tester.pumpAndSettle(const Duration(seconds: 1));

        expect(find.text('127'), findsOneWidget);
      },
    );

    testWidgets(
      'jump behavior retargets spring simulation on rapid successive CC updates',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 200,
                  height: 400,
                  child: HybridTouchFader(
                    ccNumber: 1,
                    label: 'MOD',
                    activeColor: Colors.blue,
                    labelColor: Colors.white,
                    behavior: FaderBehavior.jump,
                    initialValue: 0.0,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('  0'), findsOneWidget);

        final notifier = container.read(controlStateProvider.notifier);
        notifier.updateCC("0:1", 127);
        notifier.updateCC("0:1", 64);

        await tester.pumpAndSettle(const Duration(seconds: 1));

        expect(find.text(' 64'), findsOneWidget);
      },
    );

    testWidgets('renders active color as fader track', (tester) async {
      await pumpFader(tester, initialValue: 0.5);

      // Find containers with the active color
      final activeContainers = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.color == Colors.blue);
      expect(activeContainers, isNotEmpty);
    });

    testWidgets('long-press on label opens CC selection popup menu', (
      tester,
    ) async {
      await pumpFader(tester);

      // Long press on the CC label text
      await tester.longPress(find.text('MOD'));
      await tester.pumpAndSettle();

      // Should show CC options in popup menu
      expect(find.textContaining('Modulation'), findsOneWidget);
      expect(find.textContaining('Volume'), findsOneWidget);
      expect(find.textContaining('Pan'), findsOneWidget);
    });

    testWidgets('updates only selected CC after changing CC assignment', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 400,
                child: HybridTouchFader(
                  ccNumber: 1,
                  label: 'MOD',
                  activeColor: Colors.blue,
                  labelColor: Colors.white,
                  behavior: FaderBehavior.jump,
                  initialValue: 0.0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final notifier = container.read(controlStateProvider.notifier);
      notifier.updateCC("0:1", 127);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('127'), findsOneWidget);

      await tester.longPress(find.text('MOD'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CC2 – Breath'));
      await tester.pumpAndSettle();

      // After switching to CC2, updates to CC1 should no longer affect the fader.
      notifier.updateCC("0:1", 10);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('127'), findsOneWidget);

      notifier.updateCC("0:2", 64);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text(' 64'), findsOneWidget);
    });

    testWidgets('shows correct label font size for mobile', (tester) async {
      await pumpFader(tester, isMobile: true);

      final labelFinder = find.text('MOD');
      expect(labelFinder, findsOneWidget);

      final labelText = tester.widget<Text>(labelFinder);
      expect(labelText.style?.fontSize, 14.0);
    });
  });

  group('OpenMIDIMainScreen - Expanded Tests', () {
    testWidgets('renders 2 faders in portrait mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: OpenMIDIMainScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HybridTouchFader), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow in landscape mode', (tester) async {
      tester.view.physicalSize = const Size(2400, 1080);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: OpenMIDIMainScreen())),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(HybridTouchFader), findsNWidgets(2));
    });

    testWidgets('renders without overflow on tablet size', (tester) async {
      tester.view.physicalSize = const Size(1600, 2560);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: OpenMIDIMainScreen())),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(HybridTouchFader), findsNWidgets(2));
    });
  });
}

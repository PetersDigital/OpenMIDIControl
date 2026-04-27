// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/ui/open_midi_screen.dart';
import 'package:app/ui/hybrid_touch_fader.dart';
import 'package:app/ui/widgets/hybrid_xy_pad.dart';
import 'package:app/ui/panels/drum_grid_panel.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'hasLaunched': true});
  });

  group('OpenMIDIMainScreen Pagination', () {
    Widget buildWidget() {
      return const ProviderScope(
        child: MaterialApp(home: OpenMIDIMainScreen()),
      );
    }

    testWidgets(
      'renders PerformanceZone with PageView containing Faders initially',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildWidget());

        // Should default to page 0 (Faders)
        expect(find.byType(PageView), findsOneWidget);
        expect(find.byType(HybridTouchFader), findsWidgets);

        // Other pages should be in tree but maybe offscreen
        // HybridXYPad should exist in the tree (next page)
        // Only faders are built immediately if we use PageView (lazy loading)
        // expect(find.byType(HybridXYPad), findsWidgets);
      },
    );

    testWidgets('swiping navigates to XY Pads and Drum Grid', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildWidget());

      // Swipe left to go to page 1
      await tester.drag(find.byType(PageView), const Offset(-800, 0));
      await tester.pumpAndSettle();

      // Page 1 is XY Pads
      final xyPads = find.byType(HybridXYPad);
      expect(xyPads, findsWidgets);

      // Swipe left again to go to page 2
      await tester.drag(find.byType(PageView), const Offset(-800, 0));
      await tester.pumpAndSettle();

      // Page 2 is Drum Grid Panel
      expect(find.byType(DrumGridPanel), findsOneWidget);
    });
  });
}

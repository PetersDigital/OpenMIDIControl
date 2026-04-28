// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/ui/panels/drum_grid_panel.dart';
import 'package:app/ui/widgets/velocity_drum_pad.dart';

void main() {
  group('DrumGridPanel', () {
    Widget buildWidget({required Size size}) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: const DrumGridPanel(),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders 2x4 grid in portrait mode', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildWidget(size: const Size(600, 800)));

      // In the new 2x4 vertical standard, it should render exactly 8 pads
      expect(find.byType(VelocityDrumPad), findsNWidgets(8));

      // General MIDI Kick Drum (36) is the first note
      expect(find.text('KICK 1'), findsOneWidget);
    });

    testWidgets('renders 2x4 grid in landscape mode', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildWidget(size: const Size(1200, 600)));

      // In 2x4 standard, total pads remains 8.
      expect(find.byType(VelocityDrumPad), findsNWidgets(8));
    });

    testWidgets('renders 2x4 grid in very wide landscape mode', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1500, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildWidget(size: const Size(1500, 600)));

      // Even in wide landscape, the 2x4 standard enforces 8 pads.
      expect(find.byType(VelocityDrumPad), findsNWidgets(8));
    });
  });
}

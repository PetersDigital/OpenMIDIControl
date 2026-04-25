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

    testWidgets('renders 3x3 grid in portrait mode', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildWidget(size: const Size(600, 800)));

      // In portrait, it should render exactly 9 pads
      expect(find.byType(VelocityDrumPad), findsNWidgets(9));

      // General MIDI Kick Drum (36) is the first note
      expect(find.text('KICK 1'), findsOneWidget);
    });

    testWidgets(
      'renders wider grid in landscape mode while maintaining aspect ratio',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildWidget(size: const Size(1200, 600)));

        // In landscape 1200x600, pad size logic:
        // maxHeight = 600 / 2 = 300 padSize
        // maxWidth 1200 / 300 = 4 crossAxisCount.
        // Total pads = 4 * 2 = 8 pads.
        expect(find.byType(VelocityDrumPad), findsNWidgets(8));

        // Get the first pad and verify it is a square (1:1 aspect ratio)
        final padRect = tester.getRect(find.byType(VelocityDrumPad).first);
        expect(padRect.width, closeTo(padRect.height, 0.1));
      },
    );

    testWidgets('renders 5 columns in very wide landscape mode', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1500, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildWidget(size: const Size(1500, 600)));

      // In landscape 1500x600:
      // maxHeight = 600 / 2 = 300 padSize
      // maxWidth 1500 / 300 = 5 crossAxisCount.
      // Total pads = 5 * 2 = 10 pads.
      expect(find.byType(VelocityDrumPad), findsNWidgets(10));
    });
  });
}

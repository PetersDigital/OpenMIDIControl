// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/ui/panels/utility_grid_panel.dart';
import 'package:app/ui/widgets/endless_encoder.dart';
import 'package:app/ui/widgets/midi_buttons.dart';
import 'package:app/ui/widgets/control_config_modal.dart';

void main() {
  Widget buildTestSubject() {
    return const ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 800, height: 600, child: UtilityGridPanel()),
        ),
      ),
    );
  }

  testWidgets(
    'UtilityGridPanel renders correctly with default configurations',
    (WidgetTester tester) async {
      await tester.pumpWidget(buildTestSubject());

      // Should find 4 Encoders
      expect(find.byType(EndlessEncoderWidget), findsNWidgets(4));

      // Should find 4 Toggle buttons
      expect(find.byType(ToggleButton), findsNWidgets(4));

      // Should find 4 Momentary buttons
      expect(find.byType(MomentaryButton), findsNWidgets(4));

      // Verify default labels
      expect(find.text('CC 20'), findsOneWidget); // Encoder
      expect(find.text('TOGGLE\nCC 24'), findsOneWidget); // Toggle
      expect(find.text('MOMENT\nCC 28'), findsOneWidget); // Momentary
    },
  );

  testWidgets(
    'UtilityGridPanel shows config modal on long press and updates config',
    (WidgetTester tester) async {
      await tester.pumpWidget(buildTestSubject());

      // Long press the first encoder
      await tester.longPress(find.byType(EndlessEncoderWidget).first);
      await tester.pumpAndSettle();

      // Verify modal is shown
      expect(find.byType(ControlConfigModal), findsOneWidget);

      // Change CC value in modal to 99
      await tester.enterText(find.byType(TextFormField), '99');
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify the label updated
      expect(find.text('CC 99'), findsOneWidget);
      expect(find.text('CC 20'), findsNothing); // Old one is gone
    },
  );
}

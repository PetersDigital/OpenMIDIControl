// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/ui/panels/utility_grid_panel.dart';
import 'package:app/ui/widgets/endless_encoder.dart';
import 'package:app/ui/widgets/midi_buttons.dart';
import 'package:app/ui/widgets/control_config_modal.dart';
import 'package:app/ui/midi_settings_state.dart';

class MockConfigGestureModeNotifier extends ConfigGestureModeNotifier {
  @override
  ConfigGestureMode build() => ConfigGestureMode.tapHold;
}

void main() {
  Widget buildTestSubject() {
    return ProviderScope(
      overrides: [
        configGestureModeProvider.overrideWith(
          () => MockConfigGestureModeNotifier(),
        ),
      ],
      child: const MaterialApp(
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

      // Should find 2 Encoders
      expect(find.byType(EndlessEncoderWidget), findsNWidgets(2));

      // Should find 2 Toggle buttons
      expect(find.byType(ToggleButton), findsNWidgets(2));

      // Should find 4 Momentary buttons
      expect(find.byType(MomentaryButton), findsNWidgets(4));

      // Verify default labels
      expect(find.text('ENC 20'), findsOneWidget); // Encoder
      expect(
        find.text('TOGGLE'),
        findsAtLeastNWidgets(1),
      ); // Toggle center label
      expect(find.text('CC 24'), findsOneWidget); // Toggle CC label
      expect(
        find.text('MOMENT'),
        findsAtLeastNWidgets(1),
      ); // Momentary center label
      expect(find.text('CC 28'), findsOneWidget); // Momentary CC label
    },
  );

  testWidgets(
    'UtilityGridPanel shows config modal on long press and updates config',
    (WidgetTester tester) async {
      await tester.pumpWidget(buildTestSubject());

      // Hold the first encoder for > 1.0s
      final encoder = find.byType(EndlessEncoderWidget).first;
      final gesture = await tester.startGesture(tester.getCenter(encoder));
      await tester.pump(const Duration(milliseconds: 1100));
      await gesture.up();
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
      expect(find.text('ENC 99'), findsOneWidget);
      expect(find.text('ENC 20'), findsNothing); // Old one is gone
    },
  );
}

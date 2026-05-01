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
import 'package:app/ui/layout_state.dart';
import 'package:app/core/models/layout_models.dart';
import 'package:app/ui/midi_service.dart';

class FakeMidiService implements MidiService {
  @override
  Map<String, dynamic> get currentState => {};

  @override
  Stream<Map<String, dynamic>> get uiStateUpdates => const Stream.empty();

  @override
  Future<void> sendCC(
    int cc,
    int value, {
    int channel = 0,
    bool isFinal = false,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLayoutStateNotifier extends LayoutStateNotifier {
  final LayoutState initialState;
  MockLayoutStateNotifier(this.initialState);

  @override
  LayoutState build() => initialState;
}

class MockConfigGestureModeNotifier extends ConfigGestureModeNotifier {
  @override
  ConfigGestureMode build() => ConfigGestureMode.tapHold;
}

void main() {
  Widget buildTestSubject() {
    final mockUtilityPage = LayoutPage(
      id: 'page_3',
      name: 'UTILITY',
      controls: [
        // 4 Encoders
        ...List.generate(
          4,
          (i) => LayoutControl(
            id: 'encoder_$i',
            type: ControlType.encoder,
            defaultCc: 20 + i,
            channel: 0,
            customName: 'ENC ${i + 1}',
          ),
        ),
        // 4 Toggles
        ...List.generate(
          4,
          (i) => LayoutControl(
            id: 'toggle_$i',
            type: ControlType.toggle,
            defaultCc: 24 + i,
            channel: 0,
            customName: 'TOGGLE ${i + 1}',
          ),
        ),
        // 4 Triggers
        ...List.generate(
          4,
          (i) => LayoutControl(
            id: 'trigger_$i',
            type: ControlType.trigger,
            defaultCc: 28 + i,
            channel: 0,
            customName: 'TRIG ${i + 1}',
          ),
        ),
      ],
    );

    final mockState = LayoutState(
      pages: [
        LayoutPage(id: 'p0', name: 'P0', controls: []),
        LayoutPage(id: 'p1', name: 'P1', controls: []),
        LayoutPage(id: 'p2', name: 'P2', controls: []),
        mockUtilityPage,
      ],
      activePageIndex: 3,
      isPerformanceLocked: false,
    );

    return ProviderScope(
      overrides: [
        midiServiceProvider.overrideWithValue(FakeMidiService()),
        configGestureModeProvider.overrideWith(
          () => MockConfigGestureModeNotifier(),
        ),
        layoutStateProvider.overrideWith(
          () => MockLayoutStateNotifier(mockState),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 1000, height: 800, child: UtilityGridPanel()),
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
      expect(find.byType(Toggle), findsNWidgets(4));

      // Should find 4 Trigger buttons
      expect(find.byType(Trigger), findsNWidgets(4));

      // Verify default labels - using textContaining to be safe
      expect(find.textContaining('ENC 1'), findsOneWidget); // Encoder 1
      expect(find.textContaining('TOGGLE 1'), findsOneWidget); // Toggle label
      expect(find.textContaining('TRIG 1'), findsOneWidget); // Trigger label
    },
  );

  testWidgets(
    'UtilityGridPanel shows config modal on long press and updates config',
    (WidgetTester tester) async {
      await tester.pumpWidget(buildTestSubject());
      await tester.pumpAndSettle();

      final encoderFinder = find.byKey(
        const ValueKey('config_wrapper_encoder_encoder_0'),
      );
      expect(encoderFinder, findsOneWidget);

      final gesture = await tester.startGesture(
        tester.getCenter(encoderFinder),
      );
      await tester.pump(const Duration(milliseconds: 2000));
      await gesture.up();
      await tester.pumpAndSettle();

      // Verify modal is shown
      expect(find.byType(ControlConfigModal), findsOneWidget);

      // Change CC value in modal to 99
      await tester.enterText(find.byType(TextFormField).first, '99');
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify the encoder CC label updated (name and CC are separate Text widgets)
      expect(find.text('ENC 1'), findsOneWidget);
      expect(find.text('CC 99'), findsOneWidget);
    },
  );
}

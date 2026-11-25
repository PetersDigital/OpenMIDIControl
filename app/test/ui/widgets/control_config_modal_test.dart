// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/models/action_payload.dart';
import 'package:app/ui/layout_state.dart';
import 'package:app/ui/widgets/control_config_modal.dart';

void main() {
  Future<ProviderContainer> openInspector(
    WidgetTester tester,
    String controlId,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: ControlConfigModal(controlId: controlId)),
        ),
      ),
    );
    return container;
  }

  Future<void> select(
    WidgetTester tester,
    String current,
    String option,
  ) async {
    final field = find.text(current);
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  testWidgets('ControlConfigModal renders correctly and saves to state', (
    WidgetTester tester,
  ) async {
    final container = await openInspector(tester, 'fader_0');

    expect(find.text('Configure Control'), findsOneWidget);
    expect(
      find.text('Channel 1'),
      findsOneWidget,
    ); // Default for fader_0 is 0 (Channel 1)

    // Default identifier for fader_0 is 1
    expect(find.widgetWithText(TextFormField, '1'), findsOneWidget);

    // Enter a new value
    await tester.enterText(find.widgetWithText(TextFormField, '1'), '64');
    await tester.pumpAndSettle();

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify it's gone (modal closed)
    expect(find.byType(ControlConfigModal), findsNothing);
    expect(
      container.read(layoutStateProvider).getControlById('fader_0')!.payload,
      const CcPayload(channel: 0, cc: 64),
    );
  });

  testWidgets('selects note, velocity mode, and curve', (tester) async {
    final container = await openInspector(tester, 'fader_0');

    await select(tester, 'CC', 'Note');
    await select(tester, 'Fixed', 'Touch Position');
    await select(tester, 'Linear', 'Drum Pad');
    final note = find.widgetWithText(
      TextFormField,
      'MIDI Note (e.g., C3 or 60)',
    );
    await tester.ensureVisible(note);
    await tester.enterText(note, 'C999999999999999999999999');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a note name or a number from 0 to 127'),
      findsOneWidget,
    );

    await tester.enterText(note, 'C3');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      container.read(layoutStateProvider).getControlById('fader_0')!.payload,
      const NotePayload(
        channel: 0,
        note: 60,
        velocityMode: NoteVelocityMode.touchPosition,
        velocityCurve: NoteVelocityCurve.drumPad,
      ),
    );
  });

  testWidgets('restricts 14-bit CC to the paired controller range', (
    tester,
  ) async {
    final container = await openInspector(tester, 'fader_0');
    await tester.tap(find.text('14-bit CC'));
    await tester.pumpAndSettle();

    final cc = find.widgetWithText(TextFormField, 'CC Number (0-31)');
    await tester.enterText(cc, '32');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a CC number from 0 to 31'), findsOneWidget);

    await tester.enterText(cc, '31');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      container.read(layoutStateProvider).getControlById('fader_0')!.payload,
      const CcPayload(channel: 0, cc: 31, highResolution: true),
    );
  });

  testWidgets('validates the pitch bend value on a trigger', (tester) async {
    final container = await openInspector(tester, 'trigger_0');
    await select(tester, 'CC', 'Pitch Bend');

    final value = find.widgetWithText(
      TextFormField,
      'Pitch Bend Value (0-16383)',
    );
    await tester.enterText(value, '16384');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a value from 0 to 16383'), findsOneWidget);

    await tester.enterText(value, '4096');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      container.read(layoutStateProvider).getControlById('trigger_0')!.payload,
      const PitchBendPayload(channel: 0, value: 4096),
    );
  });

  testWidgets('saves relative X without rewriting the existing Y action', (
    tester,
  ) async {
    final container = await openInspector(tester, 'xy_main');
    final before = container
        .read(layoutStateProvider)
        .getControlById('xy_main')!;

    await select(tester, 'CC', 'Relative CC');
    await select(tester, 'Signed Bit', 'Binary Offset');
    await select(tester, 'Channel 1', 'Channel 4');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final after = container
        .read(layoutStateProvider)
        .getControlById('xy_main')!;
    expect(
      after.payload,
      const RelativeCcPayload(
        channel: 3,
        cc: 1,
        encoding: RelativeCcEncoding.binaryOffset,
      ),
    );
    expect(after.secondaryPayload, before.secondaryPayload);
    expect(after.invertY, before.invertY);
  });

  testWidgets('ControlConfigModal handles Clear action', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ControlConfigModal(controlId: 'fader_0')),
        ),
      ),
    );

    // Tap Clear
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(find.byType(ControlConfigModal), findsNothing);
  });
}

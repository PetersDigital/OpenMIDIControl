// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/core/models/action_payload.dart';
import 'package:app/core/models/layout_models.dart';
import 'package:app/ui/layout_state.dart';
import 'package:app/ui/widgets/control_config_modal.dart';

void main() {
  Future<ProviderContainer> openInspector(
    WidgetTester tester,
    String controlId, {
    LayoutControl? initialControl,
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    if (initialControl != null) {
      final notifier = container.read(layoutStateProvider.notifier);
      notifier.setPageIndex(1);
      final page = container.read(layoutStateProvider).activePage!;
      notifier.overwriteActivePage(page.copyWith(controls: [initialControl]));
    }
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
    String option, {
    String? axis,
  }) async {
    final field = axis == null
        ? find.text(current)
        : find.descendant(
            of: find.byKey(ValueKey('xy-$axis-action')),
            matching: find.text(current),
          );
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

  testWidgets('configures a latch duration and CC assignment together', (
    tester,
  ) async {
    final container = await openInspector(
      tester,
      'latch',
      initialControl: LayoutControl(
        id: 'latch',
        type: ControlType.latchPad,
        defaultCc: -1,
        channel: -1,
      ),
    );
    await select(tester, 'Unassigned', 'CC');
    final cc = find.widgetWithText(TextFormField, 'CC Number (0-127)');
    await tester.ensureVisible(cc);
    await tester.enterText(cc, '71');
    final slider = find.byType(Slider);
    await tester.ensureVisible(slider);
    final bounds = tester.getRect(slider);
    await tester.tapAt(Offset(bounds.right - 2, bounds.center.dy));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final control = container
        .read(layoutStateProvider)
        .getControlById('latch')!;
    expect(control.payload, const CcPayload(channel: 0, cc: 71));
    expect(control.latchDurationMs, 16000);
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

  testWidgets('configures an aftertouch note and validates its expression CC', (
    tester,
  ) async {
    final container = await openInspector(
      tester,
      'aftertouch',
      initialControl: LayoutControl(
        id: 'aftertouch',
        type: ControlType.aftertouchPad,
        defaultCc: -1,
        channel: -1,
      ),
    );
    final expression = find.widgetWithText(
      TextFormField,
      'Expression CC (0-127)',
    );
    expect(find.widgetWithText(TextFormField, '74'), findsOneWidget);
    await select(tester, 'Unassigned', 'Note');
    await select(tester, 'Channel 1', 'Channel 4');
    final note = find.widgetWithText(
      TextFormField,
      'MIDI Note (e.g., C3 or 60)',
    );
    await tester.ensureVisible(note);
    await tester.enterText(note, 'C3');
    await tester.ensureVisible(expression);
    await tester.enterText(expression, '128');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a CC number from 0 to 127'), findsOneWidget);
    await tester.enterText(expression, '71');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = container
        .read(layoutStateProvider)
        .getControlById('aftertouch')!;
    expect(
      saved.payload,
      const NotePayload(
        channel: 3,
        note: 60,
        velocityMode: NoteVelocityMode.touchPosition,
        velocityCurve: NoteVelocityCurve.drumPad,
      ),
    );
    expect(
      saved.effectiveSecondaryPayload,
      const CcPayload(channel: 3, cc: 71),
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

  testWidgets('saves and reopens a 32-bit CC fader assignment', (tester) async {
    final container = await openInspector(tester, 'fader_0');
    await tester.tap(find.text('32-bit MIDI 2.0'));
    await tester.pumpAndSettle();

    final cc = find.widgetWithText(
      TextFormField,
      'CC Number (64–95 or 102–119)',
    );
    await tester.enterText(cc, '98');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a CC from 64 to 95 or 102 to 119'), findsOneWidget);

    await tester.enterText(cc, '74');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final payload = container
        .read(layoutStateProvider)
        .getControlById('fader_0')!
        .payload!;
    expect(payload, const CcPayload(channel: 0, cc: 74, midi2: true));
    expect(ActionPayload.fromJson(payload.toJson()), payload);
  });

  testWidgets('saves relative X without rewriting the existing Y action', (
    tester,
  ) async {
    final container = await openInspector(tester, 'xy_main');
    final before = container
        .read(layoutStateProvider)
        .getControlById('xy_main')!;

    await select(tester, 'CC', 'Relative CC', axis: 'x');
    await select(tester, 'Signed Bit', 'Binary Offset', axis: 'x');
    await select(tester, 'Channel 1', 'Channel 4', axis: 'x');
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

  testWidgets('edits a typed Y assignment and validates numeric CC input', (
    tester,
  ) async {
    final container = await openInspector(
      tester,
      'xy_main',
      initialControl: LayoutControl(
        id: 'xy_main',
        type: ControlType.xyPad,
        defaultCc: 21,
        channel: 2,
        secondaryPayload: const NotePayload(channel: 5, note: 42),
      ),
    );
    final yFields = find.byKey(const ValueKey('xy-y-action'));
    expect(
      find.descendant(of: yFields, matching: find.text('Channel 6')),
      findsOneWidget,
    );
    await select(tester, 'Note', 'CC', axis: 'y');
    await select(tester, 'Channel 6', 'Channel 7', axis: 'y');

    final highResolution = find.descendant(
      of: yFields,
      matching: find.text('14-bit CC'),
    );
    await tester.ensureVisible(highResolution);
    await tester.tap(highResolution);
    await tester.pumpAndSettle();
    final cc = find.descendant(
      of: yFields,
      matching: find.widgetWithText(TextFormField, 'CC Number (0-31)'),
    );
    await tester.ensureVisible(cc);
    await tester.enterText(cc, 'C3');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a CC number from 0 to 31'), findsOneWidget);

    await tester.enterText(cc, '31');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final control = container
        .read(layoutStateProvider)
        .getControlById('xy_main')!;
    expect(control.payload, const CcPayload(channel: 2, cc: 21));
    expect(
      control.secondaryPayload,
      const CcPayload(channel: 6, cc: 31, highResolution: true),
    );
  });

  for (final axis in ['x', 'y']) {
    testWidgets('clearing $axis preserves the other XY assignment', (
      tester,
    ) async {
      final container = await openInspector(tester, 'xy_main');
      final before = container
          .read(layoutStateProvider)
          .getControlById('xy_main')!;
      await select(tester, 'CC', 'Unassigned', axis: axis);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final after = container
          .read(layoutStateProvider)
          .getControlById('xy_main')!;
      expect(after.payload, axis == 'x' ? isNull : before.payload);
      expect(
        after.secondaryPayload,
        axis == 'y' ? isNull : before.secondaryPayload,
      );
    });
  }

  testWidgets('opens an implicit legacy Y assignment on the original channel', (
    tester,
  ) async {
    await openInspector(
      tester,
      'xy_main',
      initialControl: LayoutControl(
        id: 'xy_main',
        type: ControlType.xyPad,
        defaultCc: 21,
        channel: 2,
      ),
    );
    final yFields = find.byKey(const ValueKey('xy-y-action'));
    expect(
      find.descendant(of: yFields, matching: find.text('Channel 3')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: yFields,
        matching: find.widgetWithText(TextFormField, '11'),
      ),
      findsOneWidget,
    );
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

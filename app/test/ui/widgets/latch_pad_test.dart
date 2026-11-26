// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:app/core/lifecycle/app_lifecycle_manager.dart';
import 'package:app/core/models/action_payload.dart';
import 'package:app/core/models/layout_models.dart';
import 'package:app/ui/midi_service.dart';
import 'package:app/ui/widgets/latch_pad.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _RecordingMidiService implements MidiService {
  final events = <(String, int, int, int)>[];

  @override
  Future<void> sendCC(
    int cc,
    int value, {
    int channel = 0,
    bool isFinal = false,
  }) async {
    events.add(('cc', channel, cc, value));
  }

  @override
  Future<void> sendNoteOn(
    int note,
    int velocity, {
    int channel = 9,
    bool isFinal = false,
  }) async {
    events.add(('on', channel, note, velocity));
  }

  @override
  Future<void> sendNoteOff(
    int note, {
    int channel = 9,
    bool isFinal = false,
  }) async {
    events.add(('off', channel, note, 0));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestLifecycle extends AppLifecycleStateNotifier {
  @override
  AppLifecycleState build() => AppLifecycleState.resumed;

  void emit(AppLifecycleState next) => state = next;
}

void main() {
  late _RecordingMidiService midi;
  late _TestLifecycle lifecycle;
  late ProviderContainer container;
  final pad = find.byType(LatchPad);
  final ccPad = LayoutControl(
    id: 'latch',
    type: ControlType.latchPad,
    defaultCc: 71,
    channel: 3,
    latchDurationMs: 500,
  );
  final notePad = ccPad.withActions(
    payload: const NotePayload(channel: 3, note: 60),
    latchDurationMs: 2000,
  );

  setUp(() {
    midi = _RecordingMidiService();
    lifecycle = _TestLifecycle();
    container = ProviderContainer.test(
      overrides: [
        midiServiceProvider.overrideWithValue(midi),
        appLifecycleStateProvider.overrideWith(() => lifecycle),
      ],
    );
  });

  Future<void> pumpPad(
    WidgetTester tester,
    LayoutControl control, {
    bool active = true,
  }) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.square(
                dimension: 150,
                child: LatchPad(control: control, isActive: active),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'holds CC through pointer-up and releases at the configured deadline',
    (tester) async {
      await pumpPad(tester, ccPad);
      await tester.tap(pad);
      await tester.pump(const Duration(milliseconds: 499));
      expect(midi.events, [('cc', 3, 71, 127)]);
      await tester.pump(const Duration(milliseconds: 1));
      expect(midi.events, [('cc', 3, 71, 127), ('cc', 3, 71, 0)]);
      await tester.pump(const Duration(seconds: 1));
      expect(midi.events, hasLength(2));
    },
  );

  testWidgets('a second tap cancels the note and permits a new full latch', (
    tester,
  ) async {
    await pumpPad(tester, notePad);
    await tester.tap(pad);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(pad);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(pad);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(midi.events, [
      ('on', 3, 60, 127),
      ('off', 3, 60, 0),
      ('on', 3, 60, 127),
    ]);
    await tester.pump(const Duration(milliseconds: 1));
    expect(midi.events.last, ('off', 3, 60, 0));
    expect(midi.events, hasLength(4));
  });

  testWidgets(
    'page switch, reassignment, background and disposal each release once',
    (tester) async {
      await pumpPad(tester, notePad);
      await tester.tap(pad);
      await pumpPad(tester, notePad, active: false);
      await tester.tap(pad);
      await pumpPad(tester, notePad);
      await tester.tap(pad);
      await pumpPad(tester, ccPad);
      await pumpPad(tester, notePad);
      await tester.tap(pad);
      lifecycle.emit(AppLifecycleState.paused);
      await tester.pump();
      await tester.tap(pad);
      lifecycle.emit(AppLifecycleState.resumed);
      await tester.tap(pad);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
      expect(midi.events, [
        for (var i = 0; i < 4; i++) ...[('on', 3, 60, 127), ('off', 3, 60, 0)],
      ]);
    },
  );

  testWidgets('dims unassigned pads to 30% opacity', (tester) async {
    await pumpPad(tester, ccPad);
    final assignedOpacity = tester.widget<Opacity>(
      find.descendant(of: pad, matching: find.byType(Opacity)),
    );
    expect(assignedOpacity.opacity, 1.0);

    await pumpPad(tester, ccPad.withActions(payload: null));
    final unassignedOpacity = tester.widget<Opacity>(
      find.descendant(of: pad, matching: find.byType(Opacity)),
    );
    expect(unassignedOpacity.opacity, 0.3);
  });
}

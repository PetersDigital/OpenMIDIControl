// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:app/core/lifecycle/app_lifecycle_manager.dart';
import 'package:app/core/models/action_payload.dart';
import 'package:app/core/models/layout_models.dart';
import 'package:app/ui/midi_service.dart';
import 'package:app/ui/widgets/aftertouch_pad.dart';
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
  const note = NotePayload(
    channel: 3,
    note: 60,
    velocityMode: NoteVelocityMode.touchPosition,
  );
  final control = LayoutControl(
    id: 'aftertouch',
    type: ControlType.aftertouchPad,
    defaultCc: 60,
    channel: 3,
    payload: note,
  );

  late _RecordingMidiService midi;
  late _TestLifecycle lifecycle;
  late ProviderContainer container;

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
    WidgetTester tester, {
    bool active = true,
    LayoutControl? mapped,
  }) {
    return tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.square(
                dimension: 200,
                child: AftertouchPad(
                  control: mapped ?? control,
                  isActive: active,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  final pad = find.byType(AftertouchPad);

  testWidgets('sends velocity and coalesces vertical expression while held', (
    tester,
  ) async {
    await pumpPad(tester);
    final center = tester.getCenter(pad);
    final touch = await tester.startGesture(center + const Offset(0, 50));
    await touch.moveTo(center + const Offset(0, -25));
    expect(midi.events, [('on', 3, 60, 32), ('cc', 3, 74, 64)]);

    final anotherTouch = await tester.startGesture(center);
    await anotherTouch.moveBy(const Offset(0, -40));
    await anotherTouch.up();
    expect(midi.events, hasLength(2));
    await touch.moveTo(center - const Offset(0, 40));
    await touch.moveTo(center - const Offset(0, 70));
    await tester.pump(const Duration(milliseconds: 12));
    expect(midi.events.last, ('cc', 3, 74, 102));

    await touch.moveBy(const Offset(0, -10));
    await touch.up();
    final beforeWait = List.of(midi.events);
    await tester.pump(const Duration(milliseconds: 20));
    expect(midi.events, beforeWait);
    expect(midi.events.last, ('off', 3, 60, 0));
  });

  testWidgets(
    'cancel, page switch, binding change, background and disposal release once',
    (tester) async {
      await pumpPad(tester);
      var touch = await tester.startGesture(tester.getCenter(pad));
      await touch.cancel();
      await pumpPad(tester);
      touch = await tester.startGesture(tester.getCenter(pad));
      await pumpPad(tester, active: false);
      await touch.up();
      await pumpPad(tester);

      touch = await tester.startGesture(tester.getCenter(pad));
      await pumpPad(
        tester,
        mapped: control.withActions(
          payload: const NotePayload(channel: 3, note: 64),
        ),
      );
      await touch.up();
      await pumpPad(tester);

      touch = await tester.startGesture(tester.getCenter(pad));
      lifecycle.emit(AppLifecycleState.paused);
      await tester.pump();
      await touch.up();
      lifecycle.emit(AppLifecycleState.resumed);
      touch = await tester.startGesture(tester.getCenter(pad));
      await tester.pumpWidget(const SizedBox.shrink());
      await touch.up();
      expect(midi.events, [
        for (var i = 0; i < 5; i++) ...[('on', 3, 60, 64), ('off', 3, 60, 0)],
      ]);
    },
  );

  testWidgets('a disabled expression assignment leaves the note gate active', (
    tester,
  ) async {
    await pumpPad(
      tester,
      mapped: control.withActions(payload: note, clearSecondary: true),
    );
    final touch = await tester.startGesture(tester.getCenter(pad));
    await touch.moveBy(const Offset(0, -30));
    await touch.up();
    expect(midi.events, [('on', 3, 60, 64), ('off', 3, 60, 0)]);
  });

  testWidgets('dims unassigned pads to 30% opacity', (tester) async {
    await pumpPad(tester);
    final assignedOpacity = tester.widget<Opacity>(
      find.descendant(of: pad, matching: find.byType(Opacity)),
    );
    expect(assignedOpacity.opacity, 1.0);

    await pumpPad(tester, mapped: control.withActions(payload: null));
    final unassignedOpacity = tester.widget<Opacity>(
      find.descendant(of: pad, matching: find.byType(Opacity)),
    );
    expect(unassignedOpacity.opacity, 0.3);
  });
}

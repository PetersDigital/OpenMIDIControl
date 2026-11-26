// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:app/core/models/action_payload.dart';
import 'package:app/ui/midi_service.dart';
import 'package:app/ui/widgets/transport_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _TestMidiService implements MidiService {
  final events = <(ActionPayload, bool)>[];

  @override
  Map<String, dynamic> get currentState => const {};

  @override
  Stream<Map<String, dynamic>> get uiStateUpdates => const Stream.empty();

  @override
  void sendTransportButton(ActionPayload payload, {required bool pressed}) {
    events.add((payload, pressed));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _TestMidiService service;
  late ProviderContainer container;

  setUp(() {
    service = _TestMidiService();
    container = ProviderContainer(
      overrides: [midiServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
  });

  Widget testSurface({
    required ActionPayload? payload,
    bool isActive = true,
    TransportAction action = TransportAction.play,
  }) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 56,
            height: 48,
            child: TransportButton(
              action: action,
              payload: payload,
              isActive: isActive,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('dispatches a momentary CC and ignores a second pointer', (
    tester,
  ) async {
    const cc = CcPayload(channel: 4, cc: 21);
    await tester.pumpWidget(
      testSurface(payload: cc, action: TransportAction.cycle),
    );
    final button = find.byType(TransportButton);
    expect(find.text('CYCLE'), findsOneWidget);
    expect(find.byIcon(Icons.repeat), findsOneWidget);

    final first = await tester.startGesture(tester.getCenter(button));
    final second = await tester.startGesture(tester.getCenter(button));
    await second.up();
    expect(service.events, [(cc, true)]);
    await first.cancel();
    expect(service.events, [(cc, true), (cc, false)]);
  });

  testWidgets('shows on and off feedback for the configured address', (
    tester,
  ) async {
    const note = NotePayload(channel: 2, note: 60);
    await tester.pumpWidget(testSurface(payload: note));
    final button = find.byType(TransportButton);
    final notifier = container.read(controlStateProvider.notifier);
    bool selected() => tester
        .widget<Semantics>(
          find.descendant(of: button, matching: find.byType(Semantics)).first,
        )
        .properties
        .selected!;

    notifier.ingestIncomingUpdates({
      'buttons': {'note:2:61': true},
    });
    await tester.pump(const Duration(milliseconds: 32));
    expect(selected(), isFalse);

    notifier.ingestIncomingUpdates({
      'buttons': {'note:2:60': true},
    });
    await tester.pump(const Duration(milliseconds: 32));
    expect(selected(), isTrue);

    await tester.tap(button);
    expect(service.events, [(note, true), (note, false)]);
    await tester.pump();
    expect(selected(), isTrue);

    notifier.ingestIncomingUpdates({
      'buttons': {'note:2:60': false},
    });
    await tester.pump(const Duration(milliseconds: 32));
    expect(selected(), isFalse);
  });

  testWidgets('releases the original mapping when the page becomes inactive', (
    tester,
  ) async {
    const note = NotePayload(channel: 2, note: 60);
    await tester.pumpWidget(testSurface(payload: note));
    final button = find.byType(TransportButton);
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pumpWidget(testSurface(payload: note, isActive: false));
    await gesture.up();
    await tester.tap(button);
    expect(service.events, [(note, true), (note, false)]);
  });

  testWidgets(
    'an unassigned transport still shows its role without sending MIDI',
    (tester) async {
      await tester.pumpWidget(
        testSurface(payload: null, action: TransportAction.bankRight),
      );
      expect(find.text('BANK RIGHT'), findsOneWidget);
      await tester.tap(find.byType(TransportButton));
      expect(service.events, isEmpty);
    },
  );
}

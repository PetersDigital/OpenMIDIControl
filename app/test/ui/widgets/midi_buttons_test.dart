// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/ui/midi_service.dart';
import 'package:app/ui/widgets/midi_buttons.dart';

class FakeMidiService implements MidiService {
  int? lastNoteOn;
  int? lastVelocityOn;
  int? lastChannelOn;
  int? lastNoteOff;

  int? lastCc;
  int? lastCcValue;

  @override
  Future<void> sendNoteOn(
    int note,
    int velocity, {
    int channel = 9,
    bool isFinal = false,
  }) async {
    lastNoteOn = note;
    lastVelocityOn = velocity;
    lastChannelOn = channel;
  }

  @override
  Future<void> sendNoteOff(
    int note, {
    int channel = 9,
    bool isFinal = false,
  }) async {
    lastNoteOff = note;
  }

  @override
  Future<void> sendCC(
    int cc,
    int value, {
    int channel = 0,
    bool isFinal = false,
  }) async {
    lastCc = cc;
    lastCcValue = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('MidiButtons', () {
    late FakeMidiService fakeMidiService;

    setUp(() {
      fakeMidiService = FakeMidiService();
    });

    Widget createWidgetUnderTest(Widget child) {
      return ProviderScope(
        overrides: [midiServiceProvider.overrideWithValue(fakeMidiService)],
        child: MaterialApp(
          home: Scaffold(body: Center(child: child)),
        ),
      );
    }

    group('Trigger', () {
      testWidgets('sends NoteOn/Off correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            const Trigger(
              identifier: 36,
              channel: 9,
              mode: MidiButtonMode.note,
              label: 'TRIGGER NOTE',
            ),
          ),
        );

        expect(find.text('TRIGGER NOTE'), findsOneWidget);

        final btnFinder = find.byType(Trigger);
        final gesture = await tester.createGesture();

        await gesture.down(tester.getCenter(btnFinder));
        await tester.pump();

        expect(fakeMidiService.lastNoteOn, 36);
        expect(fakeMidiService.lastVelocityOn, 127);
        expect(fakeMidiService.lastChannelOn, 9);

        await gesture.up();
        await tester.pump();

        expect(fakeMidiService.lastNoteOff, 36);

        // Clear timers
        await tester.pump(const Duration(milliseconds: 601));
      });

      testWidgets('sends CC correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            const Trigger(identifier: 14, channel: 0, mode: MidiButtonMode.cc),
          ),
        );

        final btnFinder = find.byType(Trigger);
        final gesture = await tester.createGesture();

        await gesture.down(tester.getCenter(btnFinder));
        await tester.pump();

        expect(fakeMidiService.lastCc, 14);
        expect(fakeMidiService.lastCcValue, 127);

        await gesture.up();
        await tester.pump();

        expect(fakeMidiService.lastCc, 14);
        expect(fakeMidiService.lastCcValue, 0);

        // Clear timers
        await tester.pump(const Duration(milliseconds: 601));
      });
    });

    group('Toggle', () {
      testWidgets('toggles NoteOn/Off states sequentially', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            const Toggle(
              identifier: 64,
              channel: 2,
              mode: MidiButtonMode.note,
              label: 'TOGGLE NOTE',
            ),
          ),
        );

        expect(find.text('TOGGLE NOTE'), findsOneWidget);

        final btnFinder = find.byType(Toggle);

        // First tap: turns ON
        await tester.tap(btnFinder);
        await tester.pump();

        expect(fakeMidiService.lastNoteOn, 64);
        expect(fakeMidiService.lastVelocityOn, 127);

        // Reset spy manually for absolute confirmation
        fakeMidiService.lastNoteOff = null;

        // Second tap: turns OFF
        await tester.tap(btnFinder);
        await tester.pump();

        expect(fakeMidiService.lastNoteOff, 64);

        // Clear timers
        await tester.pump(const Duration(milliseconds: 601));
      });

      testWidgets('toggles CC states sequentially', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            const Toggle(identifier: 65, channel: 1, mode: MidiButtonMode.cc),
          ),
        );

        final btnFinder = find.byType(Toggle);

        // First tap: turns ON (127)
        await tester.tap(btnFinder);
        await tester.pump();

        expect(fakeMidiService.lastCc, 65);
        expect(fakeMidiService.lastCcValue, 127);

        // Second tap: turns OFF (0)
        await tester.tap(btnFinder);
        await tester.pump();

        expect(fakeMidiService.lastCc, 65);
        expect(fakeMidiService.lastCcValue, 0);

        // Clear timers
        await tester.pump(const Duration(milliseconds: 601));
      });
    });
  });
}

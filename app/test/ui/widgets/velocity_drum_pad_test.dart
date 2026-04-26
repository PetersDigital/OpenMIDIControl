// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/ui/midi_service.dart';
import 'package:app/ui/widgets/velocity_drum_pad.dart';

class FakeMidiService implements MidiService {
  int? lastNoteOn;
  int? lastVelocityOn;
  int? lastChannelOn;

  int? lastNoteOff;
  int? lastChannelOff;

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
    lastChannelOff = channel;
  }

  // Stub other methods from MidiService
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('VelocityDrumPad', () {
    late FakeMidiService fakeMidiService;

    setUp(() {
      fakeMidiService = FakeMidiService();
    });

    Widget createWidgetUnderTest() {
      return ProviderScope(
        overrides: [midiServiceProvider.overrideWithValue(fakeMidiService)],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 200,
                child: VelocityDrumPad(
                  id: "test_pad",
                  note: 36,
                  channel: 9,
                  label: 'KICK',
                  minVelocity: 30,
                  maxVelocity: 127,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('KICK'), findsOneWidget);
    });

    testWidgets('calculates maximum velocity at center', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final padFinder = find.byType(VelocityDrumPad);
      final center = tester.getCenter(padFinder);

      // Simulate a pointer down event at the center
      final gesture = await tester.createGesture();
      await gesture.down(center);
      await tester.pump();

      expect(fakeMidiService.lastNoteOn, 36);
      expect(fakeMidiService.lastVelocityOn, 127);
      expect(fakeMidiService.lastChannelOn, 9);

      // Release gesture
      await gesture.up();
      await tester.pump();

      expect(fakeMidiService.lastNoteOff, 36);
      expect(fakeMidiService.lastChannelOff, 9);
    });

    testWidgets('calculates lower velocity at edges', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final padFinder = find.byType(VelocityDrumPad);
      final topLeft = tester.getTopLeft(padFinder);

      // Simulate a pointer down event at the edge
      final gesture = await tester.createGesture();
      await gesture.down(topLeft);
      await tester.pump();

      expect(fakeMidiService.lastNoteOn, 36);
      // It should map to minimum velocity at the edge
      expect(fakeMidiService.lastVelocityOn, 30);
      expect(fakeMidiService.lastChannelOn, 9);

      // Release gesture
      await gesture.up();
      await tester.pump();

      expect(fakeMidiService.lastNoteOff, 36);
      expect(fakeMidiService.lastChannelOff, 9);
    });

    testWidgets('shows ghost velocity and visual update on press', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());

      final padFinder = find.byType(VelocityDrumPad);
      final center = tester.getCenter(padFinder);

      final gesture = await tester.createGesture();
      await gesture.down(center);
      await tester.pumpAndSettle();

      // The label "V: 127" should appear when pressed
      expect(find.text('V: 127'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();

      // Label disappears after release
      expect(find.text('V: 127'), findsNothing);
    });
  });
}

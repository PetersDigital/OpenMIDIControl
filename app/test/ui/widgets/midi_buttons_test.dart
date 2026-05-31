// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/ui/midi_service.dart';
import 'package:app/ui/widgets/midi_buttons.dart';
import 'package:app/ui/layout_state.dart';
import 'package:app/core/models/layout_models.dart';

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

class MockLayoutStateNotifier extends LayoutStateNotifier {
  final LayoutState initialState;
  MockLayoutStateNotifier(this.initialState);

  @override
  LayoutState build() => initialState;
}

void main() {
  group('MidiButtons', () {
    late FakeMidiService fakeMidiService;
    late LayoutState mockState;

    setUp(() {
      fakeMidiService = FakeMidiService();
      mockState = LayoutState(
        pages: [
          LayoutPage(id: 'p0', name: 'P1', controls: []),
          LayoutPage(id: 'p1', name: 'P2', controls: []),
          LayoutPage(id: 'p2', name: 'P3', controls: []),
          LayoutPage(
            id: 'p3',
            name: 'UTILITY',
            controls: [
              LayoutControl(
                id: 'trig_note',
                type: ControlType.trigger,
                defaultCc: 36,
                channel: 9,
                customName: 'TRIGGER NOTE',
              ),
              LayoutControl(
                id: 'trig_cc',
                type: ControlType.trigger,
                defaultCc: 14,
                channel: 0,
                customName: 'TRIGGER CC',
              ),
              LayoutControl(
                id: 'toggle_note',
                type: ControlType.toggle,
                defaultCc: 64,
                channel: 2,
                customName: 'TOGGLE NOTE',
              ),
              LayoutControl(
                id: 'toggle_cc',
                type: ControlType.toggle,
                defaultCc: 65,
                channel: 1,
                customName: 'TOGGLE CC',
              ),
            ],
          ),
        ],
        activePageIndex: 3,
        isPerformanceLocked: false,
      );
    });

    Widget createWidgetUnderTest(Widget child) {
      return ProviderScope(
        overrides: [
          midiServiceProvider.overrideWithValue(fakeMidiService),
          layoutStateProvider.overrideWith(
            () => MockLayoutStateNotifier(mockState),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(body: Center(child: child)),
        ),
      );
    }

    group('Trigger', () {
      testWidgets('sends NoteOn/Off correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            const Trigger(index: 0, mode: MidiButtonMode.note),
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
            const Trigger(index: 1, mode: MidiButtonMode.cc),
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
            const Toggle(index: 2, mode: MidiButtonMode.note),
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
            const Toggle(index: 3, mode: MidiButtonMode.cc),
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

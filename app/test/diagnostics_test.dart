// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/core/models/midi_event.dart';
import 'package:app/ui/diagnostics/diagnostics_logger.dart';
import 'package:app/ui/diagnostics/diagnostics_console.dart';
import 'package:app/ui/midi_service.dart';

class FakeMidiService extends MidiService {
  final StreamController<List<MidiEvent>> _midiController =
      StreamController<List<MidiEvent>>();

  FakeMidiService() : super();

  @override
  Stream<List<MidiEvent>> get midiEventsStream => _midiController.stream;

  void addEvents(List<MidiEvent> events) {
    _midiController.add(events);
  }

  void disposeController() {
    _midiController.close();
  }
}

void main() {
  group('DiagnosticLogEntry', () {
    test('lazily formats string correctly', () {
      final event = MidiEvent(
        (0x2 << 28) | (0xB0 << 16) | (7 << 8) | 127,
        123456789000000,
        isFinal: false,
      );

      final entry = DiagnosticLogEntry(rawEvent: event);

      // Verify it's null before requested
      expect(entry.formatted, isNull);

      final formatted = entry.getFormatted();

      // Verify it computed the exact expected format
      expect(formatted, contains('MIDI IN: Ch 1 | CC 7 | Val 127'));
      expect(entry.formatted, isNotNull);
    });
  });

  group('DiagnosticsLoggerNotifier', () {
    test('initial state is empty list', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(diagnosticsProvider), isEmpty);
    });

    test('clear resets state to empty list', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initial state is empty
      expect(container.read(diagnosticsProvider), isEmpty);

      // Clear is idempotent on empty state
      container.read(diagnosticsProvider.notifier).clear();
      expect(container.read(diagnosticsProvider), isEmpty);
    });

    testWidgets(
      'batches multiple midi events into a single diagnostics state update',
      (tester) async {
        final fakeService = FakeMidiService();
        final container = ProviderContainer(
          overrides: [midiServiceProvider.overrideWithValue(fakeService)],
        );
        addTearDown(() {
          fakeService.disposeController();
          container.dispose();
        });

        int updateCount = 0;
        container.listen<List<DiagnosticLogEntry>>(diagnosticsProvider, (
          previous,
          next,
        ) {
          updateCount++;
        }, fireImmediately: false);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SizedBox()),
          ),
        );

        expect(updateCount, 0);
        expect(container.read(diagnosticsProvider), isEmpty);

        final event1 = MidiEvent(
          (0x2 << 28) | (0xB0 << 16) | (7 << 8) | 10,
          1000,
          isFinal: false,
        );
        final event2 = MidiEvent(
          (0x2 << 28) | (0xB0 << 16) | (7 << 8) | 20,
          2000,
          isFinal: false,
        );
        final event3 = MidiEvent(
          (0x2 << 28) | (0xB0 << 16) | (7 << 8) | 30,
          3000,
          isFinal: false,
        );

        fakeService.addEvents([event1]);
        fakeService.addEvents([event2]);
        fakeService.addEvents([event3]);

        await tester.pump(const Duration(milliseconds: 150));

        expect(
          updateCount,
          1,
          reason:
              'Diagnostics provider state should update only once per frame',
        );
        expect(container.read(diagnosticsProvider), hasLength(3));
      },
    );

    testWidgets(
      'publishes a new diagnostics update for events in the next frame',
      (tester) async {
        final fakeService = FakeMidiService();
        final container = ProviderContainer(
          overrides: [midiServiceProvider.overrideWithValue(fakeService)],
        );
        addTearDown(() {
          fakeService.disposeController();
          container.dispose();
        });

        int updateCount = 0;
        container.listen<List<DiagnosticLogEntry>>(diagnosticsProvider, (
          previous,
          next,
        ) {
          updateCount++;
        }, fireImmediately: false);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SizedBox()),
          ),
        );

        final event1 = MidiEvent(
          (0x2 << 28) | (0xB0 << 16) | (7 << 8) | 10,
          1000,
          isFinal: false,
        );
        final event2 = MidiEvent(
          (0x2 << 28) | (0xB0 << 16) | (7 << 8) | 20,
          2000,
          isFinal: false,
        );

        fakeService.addEvents([event1]);
        await tester.pump(const Duration(milliseconds: 150));
        expect(updateCount, 1);
        expect(container.read(diagnosticsProvider), hasLength(1));

        fakeService.addEvents([event2]);
        await tester.pump(const Duration(milliseconds: 150));
        expect(updateCount, 2);
        expect(container.read(diagnosticsProvider), hasLength(2));
      },
    );

    testWidgets(
      'retains only the most recent maxLogs entries when buffer overflows',
      (tester) async {
        final fakeService = FakeMidiService();
        final container = ProviderContainer(
          overrides: [midiServiceProvider.overrideWithValue(fakeService)],
        );
        addTearDown(() {
          fakeService.disposeController();
          container.dispose();
        });

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SizedBox()),
          ),
        );

        int updateCount = 0;
        container.listen<List<DiagnosticLogEntry>>(
          diagnosticsProvider,
          (_, value) => updateCount++,
          fireImmediately: false,
        );

        expect(container.read(diagnosticsProvider), isEmpty);

        final events = List.generate(DiagnosticsLoggerNotifier.maxLogs + 5, (
          index,
        ) {
          return MidiEvent(
            (0x2 << 28) | (0xB0 << 16) | (7 << 8) | index,
            index * 1000,
            isFinal: false,
          );
        });

        fakeService.addEvents(events);
        await tester.pump(const Duration(milliseconds: 150));

        final state = container.read(diagnosticsProvider);
        expect(state, hasLength(DiagnosticsLoggerNotifier.maxLogs));
        expect(state.first.rawEvent, equals(events.last));
        expect(state.last.rawEvent, equals(events[5]));
      },
    );
  });

  group('DiagnosticsConsole', () {
    testWidgets('renders empty state when no logs', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: DiagnosticsConsole())),
        ),
      );

      expect(find.text('No MIDI events logged yet.'), findsOneWidget);
      expect(find.text('DIAGNOSTICS LOGGER'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('clear button calls clear on notifier', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: DiagnosticsConsole())),
        ),
      );

      // Button exists
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      // Tap it — should not throw
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      // Still shows empty state
      expect(find.text('No MIDI events logged yet.'), findsOneWidget);
    });

    testWidgets('renders with divider and header', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: DiagnosticsConsole())),
        ),
      );

      expect(find.byType(Divider), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });
  });
}

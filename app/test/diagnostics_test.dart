// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'dart:async';

import 'package:material_ui/material_ui.dart';
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

    test('formats millisecond monotonic timestamps accurately', () {
      const totalMs = (1 * 3600 + 1 * 60 + 1) * 1000 + 42;
      final entry = DiagnosticLogEntry(
        rawEvent: const MidiEvent(0x20B04A60, totalMs),
      );

      expect(
        entry.getFormatted(),
        equals('[01:01:01.042] MIDI IN: Ch 1 | CC 74 | Val 96'),
      );
    });

    test('formats MIDI 1.0 pitch bend messages cleanly', () {
      final centerPlusOne = DiagnosticLogEntry(
        rawEvent: const MidiEvent(0x20E00140, 1000, sourceId: 'android:1'),
      );
      final minBend = DiagnosticLogEntry(
        rawEvent: const MidiEvent(0x20E00000, 1000),
      );
      final maxBend = DiagnosticLogEntry(
        rawEvent: const MidiEvent(0x20E07F7F, 1000),
      );

      expect(
        centerPlusOne.getFormatted(),
        equals(
          '[00:00:01.000] MIDI IN: Port android:1 | Ch 1 | Pitch Bend 8193',
        ),
      );
      expect(minBend.getFormatted(), contains('Pitch Bend 0'));
      expect(maxBend.getFormatted(), contains('Pitch Bend 16383'));
    });

    test('formats two-word MT=0x4 zero and max payloads cleanly', () {
      final zeroEntry = DiagnosticLogEntry(
        rawEvent: const MidiEvent(0x40E00000, 500, umpWord1: 0x00000000),
      );
      final maxEntry = DiagnosticLogEntry(
        rawEvent: const MidiEvent(0x40E00000, 500, umpWord1: 0xFFFFFFFF),
      );

      expect(
        zeroEntry.getFormatted(),
        equals('[00:00:00.500] MIDI IN: UMP 40e00000 00000000'),
      );
      expect(
        maxEntry.getFormatted(),
        equals('[00:00:00.500] MIDI IN: UMP 40e00000 ffffffff'),
      );
    });
  });

  group('DiagnosticsLoggerNotifier', () {
    test('initial state is empty list', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(diagnosticsProvider).entries, isEmpty);
    });

    test('clear resets state to empty list', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initial state is empty
      expect(container.read(diagnosticsProvider).entries, isEmpty);

      // Clear is idempotent on empty state
      container.read(diagnosticsProvider.notifier).clear();
      expect(container.read(diagnosticsProvider).entries, isEmpty);
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
        container.listen<DiagnosticsState>(diagnosticsProvider, (
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
        expect(container.read(diagnosticsProvider).entries, isEmpty);

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
        expect(container.read(diagnosticsProvider).entries, hasLength(3));
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
        container.listen<DiagnosticsState>(diagnosticsProvider, (
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
        expect(container.read(diagnosticsProvider).entries, hasLength(1));

        fakeService.addEvents([event2]);
        await tester.pump(const Duration(milliseconds: 150));
        expect(updateCount, 2);
        expect(container.read(diagnosticsProvider).entries, hasLength(2));
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
        container.listen<DiagnosticsState>(
          diagnosticsProvider,
          (_, value) => updateCount++,
          fireImmediately: false,
        );

        expect(container.read(diagnosticsProvider).entries, isEmpty);

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

        final state = container.read(diagnosticsProvider).entries;
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

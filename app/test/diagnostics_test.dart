// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/core/models/midi_event.dart';
import 'package:app/ui/diagnostics/diagnostics_logger.dart';
import 'package:app/ui/diagnostics/diagnostics_console.dart';

void main() {
  group('DiagnosticLogEntry', () {
    test('lazily formats string correctly', () {
      final event = MidiEvent(
        (0x2 << 28) | (0xB0 << 16) | (7 << 8) | 127,
        123456789000000,
        isFinal: false,
      );

      final entry = DiagnosticLogEntry(
        timestamp: DateTime.now(),
        rawEvent: event,
      );

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

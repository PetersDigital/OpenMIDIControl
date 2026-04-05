// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/ui/midi_settings_screen.dart';
import 'package:app/ui/midi_service.dart';
import 'package:app/ui/midi_settings_state.dart';

/// Pumps MidiSettingsScreen with optional status override.
/// Uses `pump()` instead of `pumpAndSettle()` because the screen subscribes
/// to native MIDI event streams that never settle in a test environment.
Future<void> _pumpMidiSettings(
  WidgetTester tester, {
  MidiStatus? status,
}) async {
  final container = ProviderContainer(
    overrides: [
      if (status != null) midiStatusProvider.overrideWithValue(status),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: MidiSettingsScreen()),
    ),
  );
  // Single pump — streams never settle
  await tester.pump();
}

void main() {
  group('MidiSettingsScreen - Status Banner', () {
    testWidgets('shows USB active banner for usbActive status', (tester) async {
      await _pumpMidiSettings(tester, status: MidiStatus.usbActive);

      expect(find.text('USB PERIPHERAL MODE ACTIVE'), findsOneWidget);
      expect(find.textContaining('USB MIDI peripheral'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsNWidgets(1));
    });

    testWidgets('shows connected banner for connected status', (tester) async {
      await _pumpMidiSettings(tester, status: MidiStatus.connected);

      expect(find.text('CONNECTED'), findsOneWidget);
      expect(find.textContaining('Connected to a MIDI device'), findsOneWidget);
    });

    testWidgets('shows available banner for available status', (tester) async {
      await _pumpMidiSettings(tester, status: MidiStatus.available);

      expect(find.text('MIDI DEVICES AVAILABLE'), findsOneWidget);
      expect(find.textContaining('initialize connection'), findsOneWidget);
    });

    testWidgets('shows connection lost banner for connectionLost status', (
      tester,
    ) async {
      await _pumpMidiSettings(tester, status: MidiStatus.connectionLost);

      expect(find.text('CONNECTION LOST'), findsOneWidget);
      expect(find.textContaining('physically disconnected'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('shows no devices banner for disconnected status', (
      tester,
    ) async {
      await _pumpMidiSettings(tester, status: MidiStatus.disconnected);

      expect(find.text('NO MIDI DEVICES DETECTED'), findsOneWidget);
      expect(find.textContaining('plug in a USB MIDI device'), findsOneWidget);
      expect(find.byIcon(Icons.usb_off), findsOneWidget);
    });
  });

  group('MidiSettingsScreen - Controls', () {
    testWidgets('renders USB mode toggle', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MidiSettingsScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('USB PERIPHERAL MODE'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsAtLeastNWidgets(1));
    });

    testWidgets('default USB mode is peripheral', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MidiSettingsScreen()),
        ),
      );
      await tester.pump();

      expect(container.read(usbModeProvider), UsbMode.peripheral);
    });

    testWidgets('renders manual port selection toggle', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MidiSettingsScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('MANUAL PORT SELECTION'), findsOneWidget);
    });

    testWidgets('default manual port selection is false', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MidiSettingsScreen()),
        ),
      );
      await tester.pump();

      expect(container.read(manualPortSelectionProvider), isFalse);
    });

    testWidgets('renders diagnostics button in app bar', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MidiSettingsScreen()),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.bug_report), findsOneWidget);
    });

    testWidgets('renders Connections section header', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: MidiSettingsScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('CONNECTIONS'), findsOneWidget);
    });
  });
}

// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/ui/midi_service.dart';
import 'package:app/ui/midi_settings_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.petersdigital.openmidicontrol/midi');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'setUsbMode') {
            return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'restored MCU preference opens the route when the MIDI port reconnects',
    () async {
      SharedPreferences.setMockInitialValues({
        MidiProtocolModeNotifier.storageKey: 'mcu',
      });
      int? connectedGeneration;
      var nextGeneration = 40;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => switch (call.method) {
              'getMcuRouteGeneration' => connectedGeneration,
              'connectToDevice' => (connectedGeneration = ++nextGeneration) > 0,
              'disconnectDevice' => connectedGeneration = null,
              _ => null,
            },
          );
      final service = MidiService(useBackgroundWorker: false);
      addTearDown(service.dispose);
      final container = ProviderContainer(
        overrides: [midiServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(midiProtocolModeProvider.future),
        MidiProtocolMode.mcu,
      );
      expect(service.hasMcuRoute, isFalse);
      expect(await service.connectToDevice('usb'), isTrue);
      expect(service.hasMcuRoute, isTrue);
      await service.disconnectDevice();
      expect(service.hasMcuRoute, isFalse);
      expect(await service.connectToDevice('usb'), isTrue);
      expect(service.hasMcuRoute, isTrue);
    },
  );

  group('UsbModeNotifier', () {
    test('defaults to peripheral mode', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mode = container.read(usbModeProvider);

      expect(mode, UsbMode.peripheral);
    });

    test('updateMode changes the state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(usbModeProvider.notifier).updateMode(UsbMode.host);

      final mode = container.read(usbModeProvider);
      expect(mode, UsbMode.host);
    });

    test('updateMode to same value is idempotent', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(usbModeProvider.notifier).updateMode(UsbMode.peripheral);

      final mode = container.read(usbModeProvider);
      expect(mode, UsbMode.peripheral);
    });
  });

  group('ManualPortSelectionNotifier', () {
    test('defaults to false (disabled)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final enabled = container.read(manualPortSelectionProvider);

      expect(enabled, isFalse);
    });

    test('toggle flips from false to true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(manualPortSelectionProvider.notifier).toggle();

      final enabled = container.read(manualPortSelectionProvider);
      expect(enabled, isTrue);
    });

    test('toggle flips from true back to false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(manualPortSelectionProvider.notifier).toggle();
      container.read(manualPortSelectionProvider.notifier).toggle();

      final enabled = container.read(manualPortSelectionProvider);
      expect(enabled, isFalse);
    });
  });
}

// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/ui/midi_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EventChannel Multiplexing (Hotplug & Stream Integrations)', () {
    test('Stream correctly handles interleaved primitive arrays and legacy Maps without crashing', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Create a mocked stream controller to inject payloads into the REAL MidiService
      final streamController = StreamController<dynamic>();

      // Hook up the flutter test binary messenger to mock the EventChannel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        const EventChannel('com.petersdigital.openmidicontrol/midi_events'),
        MockStreamHandler.inline(
          onListen: (Object? arguments, MockStreamHandlerEventSink events) {
            streamController.stream.listen((event) {
              events.success(event);
            });
          },
        ),
      );

      final midiService = container.read(midiServiceProvider);

      // Track outputs
      final receivedMidi = [];
      final receivedSystem = <Map<dynamic, dynamic>>[];

      midiService.midiEventsStream.listen(receivedMidi.add);
      midiService.systemEventsStream.listen(receivedSystem.add);

      // Allow stream to initialize
      await Future.delayed(Duration.zero);

      // 1. Send High-Speed Batch 1
      streamController.add(Int64List.fromList([
        0x21BF0A7F, 1000, // CC 10 = 127
        0x21BF0B40, 1010  // CC 11 = 64
      ]));

      // 2. Send System Map (USB Disconnect)
      streamController.add({'type': 'usb_state', 'state': 'DISCONNECTED'});

      // 3. Send High-Speed Batch 2
      streamController.add(Int64List.fromList([
        0x21BF0A00, 1020 // CC 10 = 0
      ]));

      // Wait for all microtasks and streams to process
      await Future.delayed(const Duration(milliseconds: 100));

      expect(receivedMidi.length, 2);
      expect(receivedSystem.length, 1);

      // Verify batch 1 output (MidiEvent instances)
      expect(receivedMidi[0][0].data1, 10);
      expect(receivedMidi[0][0].data2, 127);
      expect(receivedMidi[0][1].data1, 11);
      expect(receivedMidi[0][1].data2, 64);

      // Verify System
      expect(receivedSystem[0]['state'], 'DISCONNECTED');

      // Verify batch 2
      expect(receivedMidi[1][0].data1, 10);
      expect(receivedMidi[1][0].data2, 0);

      streamController.close();
    });

    test('High-Frequency Sweep (State Stress Test) processes 10,000 updates correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Hook up the flutter test binary messenger to mock the EventChannel
      final streamController = StreamController<dynamic>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
        const EventChannel('com.petersdigital.openmidicontrol/midi_events'),
        MockStreamHandler.inline(
          onListen: (Object? arguments, MockStreamHandlerEventSink events) {
            streamController.stream.listen((event) {
              events.success(event);
            });
          },
        ),
      );

      // Force instantiation of providers that hook into the midi events stream
      container.read(connectedMidiDeviceProvider);

      // Create a large batch payload with 10000 events mimicking rapid ping-ponging CC values
      final largeBatch = Int64List(20000);
      for (int i = 0; i < 10000; i++) {
        final value = i % 128;
        // UMP representation: MT=2, Grp=0, Status=0xB0, CC=7, Value=value
        final umpInt = (0x2 << 28) | (0xB0 << 16) | (7 << 8) | value;
        largeBatch[i * 2] = umpInt;
        largeBatch[(i * 2) + 1] = i * 1000;
      }

      // Send the batch
      streamController.add(largeBatch);
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert the ControlState processed the batch updates correctly and reflects the final value
      final finalState = container.read(ccValuesProvider);
      expect(finalState.ccValues[7], 9999 % 128); // The last processed value

      streamController.close();
    });
  });
}

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
    test(
      'Stream correctly handles interleaved primitive arrays and legacy Maps without crashing',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Create a mocked stream controller to inject payloads into the REAL MidiService
        final streamController = StreamController<dynamic>();

        final systemStreamController = StreamController<dynamic>();

        // Hook up the flutter test binary messenger to mock the EventChannel
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockStreamHandler(
              const EventChannel(
                'com.petersdigital.openmidicontrol/midi_events',
              ),
              MockStreamHandler.inline(
                onListen:
                    (Object? arguments, MockStreamHandlerEventSink events) {
                      streamController.stream.listen((event) {
                        events.success(event);
                      });
                    },
              ),
            );

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockStreamHandler(
              const EventChannel(
                'com.petersdigital.openmidicontrol/system_events',
              ),
              MockStreamHandler.inline(
                onListen:
                    (Object? arguments, MockStreamHandlerEventSink events) {
                      systemStreamController.stream.listen((event) {
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
        streamController.add(
          Int64List.fromList([
            4, // used data longs
            0x21BF0A7F, 1000, // CC 10 = 127
            0x21BF0B40, 1010, // CC 11 = 64
          ]),
        );

        // 2. Send System Map (USB Disconnect)
        systemStreamController.add({
          'type': 'usb_state',
          'state': 'DISCONNECTED',
        });

        // 3. Send High-Speed Batch 2
        streamController.add(
          Int64List.fromList([
            2, // used data longs
            0x21BF0A00, 1020, // CC 10 = 0
          ]),
        );

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
        systemStreamController.close();
      },
    );

    test(
      'midiEventsStream shares parsed batch object across listeners',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final streamController = StreamController<dynamic>();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockStreamHandler(
              const EventChannel(
                'com.petersdigital.openmidicontrol/midi_events',
              ),
              MockStreamHandler.inline(
                onListen:
                    (Object? arguments, MockStreamHandlerEventSink events) {
                      streamController.stream.listen((event) {
                        events.success(event);
                      });
                    },
              ),
            );

        final midiService = container.read(midiServiceProvider);
        final receivedA = <List<dynamic>>[];
        final receivedB = <List<dynamic>>[];

        midiService.midiEventsStream.listen(receivedA.add);
        midiService.midiEventsStream.listen(receivedB.add);

        await Future.delayed(Duration.zero);

        streamController.add(Int64List.fromList([2, 0x21BF0A7F, 1000]));

        await Future.delayed(const Duration(milliseconds: 100));

        expect(receivedA, hasLength(1));
        expect(receivedB, hasLength(1));
        expect(
          identical(receivedA[0], receivedB[0]),
          isTrue,
          reason: 'Parsed batch should be shared by broadcast stream',
        );
        expect(receivedA[0][0].data1, 10);
        expect(receivedB[0][0].data2, 127);

        streamController.close();
      },
    );

    test(
      'High-Frequency Sweep (State Stress Test) processes 10,000 updates correctly',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Hook up the flutter test binary messenger to mock the EventChannel
        final streamController = StreamController<dynamic>();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockStreamHandler(
              const EventChannel(
                'com.petersdigital.openmidicontrol/midi_events',
              ),
              MockStreamHandler.inline(
                onListen:
                    (Object? arguments, MockStreamHandlerEventSink events) {
                      streamController.stream.listen((event) {
                        events.success(event);
                      });
                    },
              ),
            );

        // Force instantiation of providers that hook into the midi events stream
        container.read(connectedMidiDeviceProvider);
        container.read(ccValuesProvider); // Initialize CcNotifier listener

        // Create a large batch payload with 10000 events mimicking rapid ping-ponging CC values
        final largeBatch = Int64List(20001);
        largeBatch[0] = 20000; // used data longs
        for (int i = 0; i < 10000; i++) {
          final value = i % 128;
          // UMP representation: MT=2, Grp=0, Status=0xB0, CC=7, Value=value
          final umpInt = (0x2 << 28) | (0xB0 << 16) | (7 << 8) | value;
          largeBatch[(i * 2) + 1] = umpInt;
          largeBatch[(i * 2) + 2] = i * 1000;
        }

        // Send the batch
        streamController.add(largeBatch);
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert the ControlState processed the batch updates correctly and reflects the final value
        final finalState = container.read(ccValuesProvider);
        expect(finalState.ccValues[7], 9999 % 128); // The last processed value

        streamController.close();
      },
    );

    test('USB AVAILABLE auto-connects peripheral fingerprint target', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final systemStreamController = StreamController<dynamic>();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockStreamHandler(
            const EventChannel(
              'com.petersdigital.openmidicontrol/system_events',
            ),
            MockStreamHandler.inline(
              onListen: (Object? arguments, MockStreamHandlerEventSink events) {
                systemStreamController.stream.listen((event) {
                  events.success(event);
                });
              },
            ),
          );

      final methodCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('com.petersdigital.openmidicontrol/midi'),
            (call) async {
              methodCalls.add(call);

              if (call.method == 'getMidiDevices') {
                return [
                  {
                    'id': 'periph-1',
                    'name': 'Android USB Peripheral Port',
                    'manufacturer': 'PetersDigital',
                    'inputPorts': [
                      {'number': 0, 'name': 'In 0'},
                    ],
                    'outputPorts': [
                      {'number': 1, 'name': 'Out 1'},
                    ],
                  },
                ];
              }

              if (call.method == 'connectToDevice') {
                return true;
              }

              return null;
            },
          );

      // Initialize notifier listeners.
      container.read(connectedMidiDeviceProvider);

      // Trigger phase-2 path.
      systemStreamController.add({'type': 'usb_state', 'state': 'AVAILABLE'});
      await Future.delayed(const Duration(milliseconds: 700));

      final didScan = methodCalls.any((c) => c.method == 'getMidiDevices');
      final connectCall = methodCalls
          .where((c) => c.method == 'connectToDevice')
          .toList();

      expect(didScan, isTrue);
      expect(connectCall.length, 1);
      expect(connectCall.first.arguments['id'], 'periph-1');
      expect(connectCall.first.arguments['inputPort'], 0);
      expect(connectCall.first.arguments['outputPort'], 1);

      final connectionState = container.read(connectedMidiDeviceProvider);
      expect(connectionState.connectedDevice?.id, 'periph-1');

      systemStreamController.close();
    });
  });
}

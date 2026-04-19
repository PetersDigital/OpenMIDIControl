// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/midi_event.dart';
import 'package:app/core/router/nodes/native_transport_sink_node.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  int buildUmp({
    required int messageType,
    required int status,
    required int data1,
    required int data2,
  }) {
    return (messageType << 28) |
        (0x0 << 24) |
        (status << 16) |
        (data1 << 8) |
        data2;
  }

  group('NativeTransportSinkNode', () {
    late MethodChannel channel;
    late Int64List capturedEvents;
    late Completer<void> callCompleter;
    int methodCallCount = 0;

    setUp(() {
      channel = const MethodChannel('com.petersdigital.openmidicontrol/midi');
      capturedEvents = Int64List(0);
      callCompleter = Completer<void>();
      methodCallCount = 0;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'sendMidiCCBatch') {
              methodCallCount++;
              final events = (call.arguments as Map)['events'] as Int64List;
              capturedEvents = events;
              if (!callCompleter.isCompleted) {
                callCompleter.complete();
              }
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('buffers events and flushes on timer', () async {
      final node = NativeTransportSinkNode(channel: channel);

      final event1 = MidiEvent(
        buildUmp(messageType: 0x2, status: 0xB0, data1: 0, data2: 0),
        0,
        isFinal: false,
      );
      final event2 = MidiEvent(
        buildUmp(messageType: 0x2, status: 0xB0, data1: 1, data2: 10),
        0,
        isFinal: false,
      );
      final event3 = MidiEvent(
        buildUmp(messageType: 0x2, status: 0xB0, data1: 2, data2: 20),
        0,
        isFinal: true,
      );

      node.execute([event1]);
      node.execute([event2]);
      node.execute([event3]);

      expect(methodCallCount, 0);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(methodCallCount, 1);
      expect(capturedEvents.length, 6);

      node.dispose();
    });

    test('flushes single CC event using single-CC buffer', () async {
      final node = NativeTransportSinkNode(channel: channel);

      final event = MidiEvent(
        buildUmp(messageType: 0x2, status: 0xB0, data1: 4, data2: 42),
        0,
        isFinal: true,
      );

      node.execute([event]);

      expect(methodCallCount, 0);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(methodCallCount, 1);
      expect(capturedEvents.length, 2);
      expect(capturedEvents[0], event.ump);
      expect(capturedEvents[1], 1);

      node.dispose();
    });

    test(
      'repeated execute calls before timer flush still produce one batch',
      () async {
        final node = NativeTransportSinkNode(channel: channel);

        final event = MidiEvent(
          buildUmp(messageType: 0x2, status: 0xB0, data1: 0, data2: 0),
          0,
          isFinal: false,
        );

        node.execute([event]);
        node.execute([event]);
        node.execute([event]);

        expect(methodCallCount, 0);

        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(methodCallCount, 1);
        expect(capturedEvents.length, 6);

        node.dispose();
      },
    );

    test(
      'dispose cancels pending batch flush and frees timer resources',
      () async {
        final node = NativeTransportSinkNode(channel: channel);

        final event = MidiEvent(
          buildUmp(messageType: 0x2, status: 0xB0, data1: 0, data2: 0),
          0,
          isFinal: false,
        );

        node.execute([event]);
        node.dispose();

        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(methodCallCount, 0);
        expect(capturedEvents, isEmpty);
      },
    );

    test('flushes immediately when buffer max size is reached', () async {
      final node = NativeTransportSinkNode(channel: channel);

      // Max buffer size is 10
      for (int i = 0; i < 10; i++) {
        node.execute([
          MidiEvent(
            buildUmp(messageType: 0x2, status: 0xB0, data1: i, data2: i),
            0,
            isFinal: false,
          ),
        ]);
      }

      // Should be completed immediately without needing the timer
      expect(methodCallCount, 1);
      expect(capturedEvents.length, 20); // 10 events * 2 (ump, isFinal)

      node.dispose();
    });

    test('forwards isFinal values for CC events', () async {
      final node = NativeTransportSinkNode(channel: channel);

      final ccOff = MidiEvent(
        buildUmp(messageType: 0x2, status: 0xB0, data1: 0, data2: 0),
        0,
        isFinal: false,
      );
      final ccOn = MidiEvent(
        buildUmp(messageType: 0x2, status: 0xB0, data1: 0, data2: 1),
        0,
        isFinal: true,
      );

      node.execute([ccOff, ccOn]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(capturedEvents.length, 4);
      expect(capturedEvents[0], ccOff.ump);
      expect(capturedEvents[1], 0);
      expect(capturedEvents[2], ccOn.ump);
      expect(capturedEvents[3], 1);

      node.dispose();
    });

    test('forwards CC events from non-zero MIDI channels', () async {
      final node = NativeTransportSinkNode(channel: channel);

      final ccCh2 = MidiEvent(
        buildUmp(messageType: 0x2, status: 0xB2, data1: 7, data2: 100),
        0,
        isFinal: true,
      );
      final ccCh15 = MidiEvent(
        buildUmp(messageType: 0x2, status: 0xBF, data1: 8, data2: 101),
        0,
        isFinal: false,
      );

      node.execute([ccCh2, ccCh15]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(capturedEvents.length, 4);
      expect(capturedEvents[0], ccCh2.ump);
      expect(capturedEvents[2], ccCh15.ump);

      node.dispose();
    });

    test('ignores non-CC events', () async {
      final node = NativeTransportSinkNode(channel: channel);

      final nonCc = MidiEvent(
        buildUmp(messageType: 0x1, status: 0xF8, data1: 0, data2: 0),
        0,
        isFinal: true,
      );

      node.execute([nonCc]);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(capturedEvents, isEmpty);
      expect(methodCallCount, 0);

      node.dispose();
    });
  });
}

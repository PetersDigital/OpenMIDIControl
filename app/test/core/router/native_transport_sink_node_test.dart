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

    setUp(() {
      channel = const MethodChannel('com.petersdigital.openmidicontrol/midi');
      capturedEvents = Int64List(0);
      callCompleter = Completer<void>();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'sendMidiCCBatch') {
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
      await callCompleter.future;

      expect(capturedEvents.length, 4);
      expect(capturedEvents[0], ccOff.ump);
      expect(capturedEvents[1], 0);
      expect(capturedEvents[2], ccOn.ump);
      expect(capturedEvents[3], 1);
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
      await callCompleter.future;

      expect(capturedEvents.length, 4);
      expect(capturedEvents[0], ccCh2.ump);
      expect(capturedEvents[2], ccCh15.ump);
    });

    test('ignores non-CC events', () async {
      final node = NativeTransportSinkNode(channel: channel);

      final nonCc = MidiEvent(
        buildUmp(messageType: 0x1, status: 0xF8, data1: 0, data2: 0),
        0,
        isFinal: true,
      );

      node.execute([nonCc]);

      // Give the method channel a chance to be called if it was incorrectly triggered.
      await Future<void>.delayed(Duration.zero);
      expect(capturedEvents, isEmpty);
    });
  });
}

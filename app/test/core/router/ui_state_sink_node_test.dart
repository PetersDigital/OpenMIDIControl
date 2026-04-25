// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/midi_event.dart';
import 'package:app/core/router/nodes/ui_state_sink_node.dart';

void main() {
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

  group('UiStateSinkNode', () {
    test('does not emit updates for non-CC events', () {
      var updateCount = 0;
      final node = UiStateSinkNode(
        onStateUpdate: (_) {
          updateCount++;
        },
      );

      node.execute([
        MidiEvent(
          buildUmp(messageType: 0x1, status: 0xF8, data1: 0, data2: 0),
          0,
        ),
        MidiEvent(
          buildUmp(messageType: 0x2, status: 0x90, data1: 1, data2: 127),
          0,
        ),
      ]);

      expect(updateCount, 1);
    });

    test('emits a map of CC updates for CC events only', () {
      Map<String, dynamic>? received;
      final node = UiStateSinkNode(
        onStateUpdate: (updates) {
          received = updates;
        },
      );

      node.execute([
        MidiEvent(
          buildUmp(messageType: 0x2, status: 0xB0, data1: 7, data2: 64),
          0,
        ),
        MidiEvent(
          buildUmp(messageType: 0x2, status: 0xB0, data1: 10, data2: 127),
          0,
        ),
        MidiEvent(
          buildUmp(messageType: 0x2, status: 0x90, data1: 1, data2: 127),
          0,
        ),
      ]);

      expect(received, isNotNull);
      expect(received!["ccs"], equals({"0:7": 64, "0:10": 127}));
    });

    test('keeps last value for repeated CC keys within one batch', () {
      Map<String, dynamic>? received;
      final node = UiStateSinkNode(
        onStateUpdate: (updates) {
          received = updates;
        },
      );

      node.execute([
        MidiEvent(
          buildUmp(messageType: 0x2, status: 0xB0, data1: 7, data2: 10),
          0,
        ),
        MidiEvent(
          buildUmp(messageType: 0x2, status: 0xB0, data1: 7, data2: 99),
          0,
        ),
        MidiEvent(
          buildUmp(messageType: 0x2, status: 0xB0, data1: 10, data2: 127),
          0,
        ),
      ]);

      expect(received, isNotNull);
      expect(received!["ccs"], equals({"0:7": 99, "0:10": 127}));
    });

    test('emits isolated snapshots for executeSingle calls', () {
      final received = <Map<String, dynamic>>[];
      final node = UiStateSinkNode(
        onStateUpdate: (updates) {
          received.add(updates);
        },
      );

      node.executeSingle(
        MidiEvent(
          buildUmp(messageType: 0x2, status: 0xB0, data1: 7, data2: 64),
          0,
        ),
      );
      node.executeSingle(
        MidiEvent(
          buildUmp(messageType: 0x2, status: 0xB0, data1: 10, data2: 127),
          0,
        ),
      );

      expect(received, hasLength(2));
      expect(received[0]["ccs"], equals({"0:7": 64}));
      expect(received[1]["ccs"], equals({"0:10": 127}));
      expect(received[0], isNot(same(received[1])));
    });

    test('returns stable snapshots across multiple execute calls', () {
      final received = <Map<String, dynamic>>[];
      final node = UiStateSinkNode(
        onStateUpdate: (updates) {
          received.add(updates);
        },
      );

      node.execute([
        MidiEvent(
          buildUmp(messageType: 0x2, status: 0xB0, data1: 7, data2: 64),
          0,
        ),
      ]);
      node.execute([
        MidiEvent(
          buildUmp(messageType: 0x2, status: 0xB0, data1: 10, data2: 127),
          0,
        ),
      ]);

      expect(received, hasLength(2));
      expect(received[0]["ccs"], equals({"0:7": 64}));
      expect(received[1]["ccs"], equals({"0:10": 127}));
      expect(received[0], isNot(same(received[1])));
    });

    test(
      'published snapshots remain immutable after buffer reuse across generations',
      () {
        final received = <Map<String, dynamic>>[];
        final node = UiStateSinkNode(
          onStateUpdate: (updates) {
            received.add(updates);
          },
        );

        node.execute([
          MidiEvent(
            buildUmp(messageType: 0x2, status: 0xB0, data1: 7, data2: 64),
            0,
          ),
        ]);
        node.execute([
          MidiEvent(
            buildUmp(messageType: 0x2, status: 0xB0, data1: 10, data2: 127),
            0,
          ),
        ]);
        node.execute([
          MidiEvent(
            buildUmp(messageType: 0x2, status: 0xB0, data1: 11, data2: 32),
            0,
          ),
        ]);

        expect(received, hasLength(3));
        expect(received[0]["ccs"], equals({"0:7": 64}));
        expect(received[1]["ccs"], equals({"0:10": 127}));
        expect(received[2]["ccs"], equals({"0:11": 32}));
      },
    );
  });
}

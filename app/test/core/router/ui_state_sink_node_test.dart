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
        onUpdateCCs: (_) {
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

      expect(updateCount, 0);
    });

    test('emits a map of CC updates for CC events only', () {
      Map<int, int>? received;
      final node = UiStateSinkNode(
        onUpdateCCs: (updates) {
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
      expect(received, equals({7: 64, 10: 127}));
    });
  });
}

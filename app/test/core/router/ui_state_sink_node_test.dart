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
    test(
      'emits updates for state-changing events (CC, Note) but ignores system real-time',
      () {
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
      },
    );

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
      ]);

      expect(received, isNotNull);
      expect(received!["ccs"], equals({"0:7": 64, "0:10": 127}));
      expect(received, isNot(contains('notes')));
    });

    test('does not include notes when no note state has changed', () {
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
      ]);

      expect(received, isNotNull);
      expect(received!['ccs'], equals({'0:7': 64}));
      expect(received, isNot(contains('notes')));
      // Now includes buttons because CC 64 triggered a state change from null to true
      expect(received!['buttons'], containsPair('0:7', true));
    });

    test('includes buttons when note state changes', () {
      Map<String, dynamic>? received;
      final node = UiStateSinkNode(
        onStateUpdate: (updates) {
          received = updates;
        },
      );

      node.execute([
        MidiEvent(
          buildUmp(messageType: 0x2, status: 0x90, data1: 10, data2: 127),
          0,
        ),
      ]);

      expect(received, isNotNull);
      expect(received!['notes'], isNotNull);
      expect(received!['buttons'], containsPair('note:0:10', true));
    });

    test(
      'does not include buttons when button state has not changed (lazy update)',
      () async {
        final updates = <Map<String, dynamic>>[];
        final node = UiStateSinkNode(onStateUpdate: (u) => updates.add(u));

        // First event triggers change from null to true
        node.execute([
          MidiEvent(
            buildUmp(messageType: 0x2, status: 0xB0, data1: 7, data2: 127),
            0,
          ),
        ]);

        await Future.delayed(const Duration(milliseconds: 32));

        // Second event is different CC value but same button state, should NOT trigger a button update
        node.execute([
          MidiEvent(
            buildUmp(messageType: 0x2, status: 0xB0, data1: 7, data2: 65),
            0,
          ),
        ]);

        await Future.delayed(const Duration(milliseconds: 32));

        expect(updates, hasLength(2));
        expect(updates[0], contains('buttons'));
        // The second update should NOT contain 'buttons' because the state (true) didn't change
        expect(updates[1], isNot(contains('buttons')));
      },
    );

    test(
      'does not emit redundant updates for duplicate Note On events',
      () async {
        var updateCount = 0;
        final node = UiStateSinkNode(
          onStateUpdate: (_) {
            updateCount++;
          },
        );

        final event = MidiEvent(
          buildUmp(messageType: 0x2, status: 0x90, data1: 60, data2: 127),
          0,
        );

        node.executeSingle(event);
        node.executeSingle(event);

        await Future.delayed(const Duration(milliseconds: 32));

        expect(updateCount, 1);
      },
    );

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

    test(
      'emits isolated snapshots for executeSingle calls (throttled)',
      () async {
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

        await Future.delayed(const Duration(milliseconds: 32));

        node.executeSingle(
          MidiEvent(
            buildUmp(messageType: 0x2, status: 0xB0, data1: 10, data2: 127),
            0,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 32));

        expect(received, hasLength(2));
        expect(received[0]["ccs"], equals({"0:7": 64}));
        expect(received[1]["ccs"], equals({"0:10": 127}));
        expect(received[0], isNot(same(received[1])));
      },
    );

    test(
      'returns stable snapshots across multiple execute calls (throttled)',
      () async {
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

        await Future.delayed(const Duration(milliseconds: 32));

        node.execute([
          MidiEvent(
            buildUmp(messageType: 0x2, status: 0xB0, data1: 10, data2: 127),
            0,
          ),
        ]);

        await Future.delayed(const Duration(milliseconds: 32));

        expect(received, hasLength(2));
        expect(received[0]["ccs"], equals({"0:7": 64}));
        expect(received[1]["ccs"], equals({"0:10": 127}));
        expect(received[0], isNot(same(received[1])));
      },
    );

    test(
      'published snapshots remain immutable after buffer reuse across generations (throttled)',
      () async {
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

        await Future.delayed(const Duration(milliseconds: 32));

        node.execute([
          MidiEvent(
            buildUmp(messageType: 0x2, status: 0xB0, data1: 10, data2: 127),
            0,
          ),
        ]);

        await Future.delayed(const Duration(milliseconds: 32));

        node.execute([
          MidiEvent(
            buildUmp(messageType: 0x2, status: 0xB0, data1: 11, data2: 32),
            0,
          ),
        ]);

        await Future.delayed(const Duration(milliseconds: 32));

        expect(received, hasLength(3));
        expect(received[0]["ccs"], equals({"0:7": 64}));
        expect(received[1]["ccs"], equals({"0:10": 127}));
        expect(received[2]["ccs"], equals({"0:11": 32}));
      },
    );
  });
}

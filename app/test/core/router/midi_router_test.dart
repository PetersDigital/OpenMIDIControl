// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/midi_event.dart';
import 'package:app/core/router/midi_router.dart';
import 'package:app/core/router/nodes/filter_node.dart';
import 'package:app/core/router/nodes/remap_node.dart';
import 'package:app/core/router/nodes/split_node.dart';
import 'package:app/core/router/nodes/sink_node.dart';
import 'package:app/core/router/nodes/ui_state_sink_node.dart';

class _TestSinkNode extends SinkNode {
  final List<MidiEvent> receivedEvents = [];

  @override
  void execute(List<MidiEvent> events) {
    receivedEvents.addAll(events);
  }
}

void main() {
  group('MidiRouter DAG Logic', () {
    int createUmp(
      int messageType,
      int group,
      int status,
      int data1,
      int data2,
    ) {
      return (messageType << 28) |
          (group << 24) |
          (status << 16) |
          (data1 << 8) |
          data2;
    }

    test('Router adds and removes nodes correctly', () {
      final router = MidiRouter();
      router.addNode('source', SplitNode());
      expect(() => router.addNode('source', SplitNode()), throwsStateError);

      router.removeNode('source');
      // Should not throw since it's removed
      router.addNode('source', SplitNode());
    });

    test('Router processes events through multiple nodes successfully', () {
      final router = MidiRouter();
      final sink = _TestSinkNode();

      router.addNode('source', SplitNode());
      router.addNode('filter', FilterNode(allowedChannel: 0));
      router.addNode('sink', sink);

      router.addEdge('source', 'filter');
      router.addEdge('filter', 'sink');

      final events = [
        MidiEvent(createUmp(0x2, 0, 0xB0, 10, 127), 0), // ch 0
        MidiEvent(createUmp(0x2, 0, 0xB1, 11, 127), 0), // ch 1 (filtered)
      ];

      router.process('source', events);

      expect(sink.receivedEvents.length, 1);
      expect(sink.receivedEvents.first.channel, 0);
    });

    test('Router duplicates events at SplitNode dynamically', () {
      final router = MidiRouter();
      final sinkA = _TestSinkNode();
      final sinkB = _TestSinkNode();

      router.addNode('source', SplitNode());
      router.addNode('sinkA', sinkA);
      router.addNode('sinkB', sinkB);

      router.addEdge('source', 'sinkA');
      router.addEdge('source', 'sinkB');

      final events = [MidiEvent(createUmp(0x2, 0, 0xB0, 10, 127), 0)];

      router.process('source', events);

      expect(sinkA.receivedEvents.length, 1);
      expect(sinkB.receivedEvents.length, 1);
      expect(sinkA.receivedEvents.first, equals(sinkB.receivedEvents.first));
    });

    test('UiStateSinkNode skips allocation for non-CC events', () {
      bool called = false;
      final node = UiStateSinkNode(
        onUpdateCCs: (_) {
          called = true;
        },
      );

      final events = [
        MidiEvent(createUmp(0x2, 0, 0xF8, 0, 0), 0),
        MidiEvent(createUmp(0x2, 0, 0xF7, 0, 0), 0),
      ];

      node.execute(events);

      expect(called, isFalse);
    });

    test('UiStateSinkNode forwards CC updates only for CC events', () {
      final received = <Map<int, int>>[];
      final node = UiStateSinkNode(onUpdateCCs: received.add);

      final events = [
        MidiEvent(createUmp(0x2, 0, 0xB0, 10, 64), 0),
        MidiEvent(createUmp(0x2, 0, 0x90, 11, 127), 0),
      ];

      node.execute(events);

      expect(received, hasLength(1));
      expect(received.single, equals({10: 64}));
    });

    test('Cycle Detection prevents infinite loops on configuration', () {
      final router = MidiRouter();
      router.addNode('A', SplitNode());
      router.addNode('B', SplitNode());
      router.addNode('C', SplitNode());

      router.addEdge('A', 'B');
      router.addEdge('B', 'C');

      // Adding C -> A creates a cycle
      expect(() => router.addEdge('C', 'A'), throwsStateError);
    });

    test('Duplicate edges are ignored and do not cause double-processing', () {
      final router = MidiRouter();
      final sink = _TestSinkNode();

      router.addNode('source', SplitNode());
      router.addNode('sink', sink);

      // Add the same edge twice
      router.addEdge('source', 'sink');
      router.addEdge('source', 'sink');

      final events = [MidiEvent(createUmp(0x2, 0, 0xB0, 10, 127), 0)];
      router.process('source', events);

      // Should only receive once, not twice
      expect(sink.receivedEvents.length, 1);
    });

    test('Stress Test: Processes 10,000+ events without stack overflow', () {
      final router = MidiRouter();
      final sink = _TestSinkNode();

      router.addNode('source', SplitNode());
      router.addNode('remap1', RemapNode(sourceCc: 10, destCc: 11));
      router.addNode('remap2', RemapNode(sourceCc: 11, destCc: 12));
      router.addNode('sink', sink);

      // Deepish linear chain
      router.addEdge('source', 'remap1');
      router.addEdge('remap1', 'remap2');
      router.addEdge('remap2', 'sink');

      final hugeBatch = List.generate(
        15000,
        (i) => MidiEvent(createUmp(0x2, 0, 0xB0, 10, i % 128), 0),
      );

      router.process('source', hugeBatch);

      // Ensure all reached the sink and were transformed properly
      expect(sink.receivedEvents.length, 15000);
      expect(sink.receivedEvents.first.data1, 12);
      expect(sink.receivedEvents.last.data1, 12);
    });
  });
}

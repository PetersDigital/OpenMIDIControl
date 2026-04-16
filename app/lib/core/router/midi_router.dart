// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:collection';

import '../models/midi_event.dart';
import 'transformer_node.dart';

class _WorkItem {
  final String nodeId;
  final List<MidiEvent> events;

  _WorkItem(this.nodeId, this.events);
}

/// A centralized Directed Acyclic Graph (DAG) for routing, filtering,
/// and remapping MIDI events.
class MidiRouter {
  final Map<String, TransformerNode> _nodes = {};
  final Map<String, List<String>> _edges = {};

  /// Registers a new node in the graph.
  void addNode(String id, TransformerNode node) {
    if (_nodes.containsKey(id)) {
      throw StateError('Node with ID $id already exists.');
    }
    _nodes[id] = node;
  }

  /// Adds a directed edge from one node to another.
  /// Throws a [StateError] if adding the edge creates a cycle.
  void addEdge(String from, String to) {
    if (!_nodes.containsKey(from)) {
      throw StateError('Source node $from does not exist.');
    }
    if (!_nodes.containsKey(to)) {
      throw StateError('Destination node $to does not exist.');
    }

    _edges.putIfAbsent(from, () => []).add(to);

    if (_detectCycle()) {
      // Revert the edge addition if it causes a cycle
      _edges[from]!.removeLast();
      throw StateError('Adding edge from $from to $to creates a cycle.');
    }
  }

  /// Removes a node and all associated edges from the graph.
  void removeNode(String id) {
    _nodes.remove(id);
    _edges.remove(id);
    for (final edgeList in _edges.values) {
      edgeList.remove(id);
    }
  }

  /// Clears the entire routing graph.
  void clear() {
    _nodes.clear();
    _edges.clear();
  }

  /// Processes a batch of [MidiEvent]s starting at the specified source node.
  /// Uses a queue-based traversal to prevent deep recursion.
  void process(String sourceNodeId, List<MidiEvent> events) {
    if (events.isEmpty) return;
    if (!_nodes.containsKey(sourceNodeId)) {
      throw StateError('Source node $sourceNodeId does not exist.');
    }

    final queue = Queue<_WorkItem>();
    queue.add(_WorkItem(sourceNodeId, events));

    while (queue.isNotEmpty) {
      final item = queue.removeFirst();
      final nodeId = item.nodeId;
      final batch = item.events;

      final node = _nodes[nodeId]!;
      final processedBatch = node.process(batch);

      if (processedBatch.isNotEmpty) {
        final children = _edges[nodeId] ?? const [];
        for (final childId in children) {
          queue.add(_WorkItem(childId, processedBatch));
        }
      }
    }
  }

  /// Returns true if the graph contains a cycle.
  bool _detectCycle() {
    final visited = <String>{};
    final recStack = <String>{};

    for (final node in _nodes.keys) {
      if (_isCyclic(node, visited, recStack)) {
        return true;
      }
    }
    return false;
  }

  bool _isCyclic(String node, Set<String> visited, Set<String> recStack) {
    if (recStack.contains(node)) return true;
    if (visited.contains(node)) return false;

    visited.add(node);
    recStack.add(node);

    final children = _edges[node] ?? const [];
    for (final child in children) {
      if (_isCyclic(child, visited, recStack)) {
        return true;
      }
    }

    recStack.remove(node);
    return false;
  }
}

// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:collection';

import '../models/midi_event.dart';
import 'transformer_node.dart';

class _WorkItem {
  String nodeId;
  List<MidiEvent> events;

  _WorkItem(this.nodeId, this.events);
}

class _WorkItemSingle {
  String nodeId;
  MidiEvent event;

  _WorkItemSingle(this.nodeId, this.event);
}

/// A centralized Directed Acyclic Graph (DAG) for routing, filtering,
/// and remapping MIDI events.
class MidiRouter {
  final Map<String, TransformerNode> _nodes = {};
  final Map<String, List<String>> _edges = {};

  // Pre-allocated queue and object pool to reduce GC pressure during high-frequency routing
  final Queue<_WorkItem> _processQueue = Queue<_WorkItem>();
  final List<_WorkItem> _workItemPool = [];

  final Queue<_WorkItemSingle> _processSingleQueue = Queue<_WorkItemSingle>();
  final List<_WorkItemSingle> _workItemSinglePool = [];

  _WorkItem _getWorkItem(String nodeId, List<MidiEvent> events) {
    if (_workItemPool.isNotEmpty) {
      final item = _workItemPool.removeLast();
      item.nodeId = nodeId;
      item.events = events;
      return item;
    }
    return _WorkItem(nodeId, events);
  }

  void _releaseWorkItem(_WorkItem item) {
    item.events = const []; // Clear references
    _workItemPool.add(item);
  }

  _WorkItemSingle _getWorkItemSingle(String nodeId, MidiEvent event) {
    if (_workItemSinglePool.isNotEmpty) {
      final item = _workItemSinglePool.removeLast();
      item.nodeId = nodeId;
      item.event = event;
      return item;
    }
    return _WorkItemSingle(nodeId, event);
  }

  void _releaseWorkItemSingle(_WorkItemSingle item) {
    _workItemSinglePool.add(item);
  }

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

    final children = _edges.putIfAbsent(from, () => []);

    // Prevent duplicate edges to the same node
    if (children.contains(to)) {
      return;
    }

    // A cycle is created if 'to' can already reach 'from'
    if (_canReach(to, from)) {
      throw StateError('Adding edge from $from to $to creates a cycle.');
    }

    children.add(to);
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

    _processQueue.add(_getWorkItem(sourceNodeId, events));

    try {
      while (_processQueue.isNotEmpty) {
        final item = _processQueue.removeFirst();
        try {
          final nodeId = item.nodeId;
          final batch = item.events;

          final node = _nodes[nodeId]!;
          final processedBatch = node.process(batch);

          if (processedBatch.isNotEmpty) {
            final children = _edges[nodeId] ?? const [];
            for (final childId in children) {
              _processQueue.add(_getWorkItem(childId, processedBatch));
            }
          }
        } finally {
          _releaseWorkItem(item);
        }
      }
    } catch (_) {
      _clearProcessQueue();
      rethrow;
    }
  }

  void _clearProcessQueue() {
    while (_processQueue.isNotEmpty) {
      _releaseWorkItem(_processQueue.removeFirst());
    }
  }

  /// Fast-path for routing a single [MidiEvent] without creating intermediate lists.
  void processSingle(String sourceNodeId, MidiEvent event) {
    if (!_nodes.containsKey(sourceNodeId)) {
      throw StateError('Source node $sourceNodeId does not exist.');
    }

    _processSingleQueue.add(_getWorkItemSingle(sourceNodeId, event));

    try {
      while (_processSingleQueue.isNotEmpty) {
        final item = _processSingleQueue.removeFirst();
        try {
          final nodeId = item.nodeId;
          final ev = item.event;

          final node = _nodes[nodeId]!;
          final processedEvent = node.processSingle(ev);

          if (processedEvent != null) {
            final children = _edges[nodeId] ?? const [];
            for (final childId in children) {
              _processSingleQueue.add(
                _getWorkItemSingle(childId, processedEvent),
              );
            }
          }
        } finally {
          _releaseWorkItemSingle(item);
        }
      }
    } catch (_) {
      _clearProcessSingleQueue();
      rethrow;
    }
  }

  void _clearProcessSingleQueue() {
    while (_processSingleQueue.isNotEmpty) {
      _releaseWorkItemSingle(_processSingleQueue.removeFirst());
    }
  }

  /// Returns true if [start] node can reach [target] node.
  bool _canReach(String start, String target) {
    if (start == target) return true;

    // Use a simple DFS to check reachability.
    // This is faster than a full graph DFS because it only visits nodes reachable from 'start'.
    final visited = <String>{};
    return _dfsReach(start, target, visited);
  }

  bool _dfsReach(String current, String target, Set<String> visited) {
    if (current == target) return true;
    visited.add(current);

    final children = _edges[current] ?? const [];
    for (final child in children) {
      if (!visited.contains(child)) {
        if (_dfsReach(child, target, visited)) return true;
      }
    }
    return false;
  }
}

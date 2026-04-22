// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:collection';
import '../../models/midi_event.dart';
import 'sink_node.dart';

class _CcBatchContainer extends MapBase<int, int> {
  final List<int> _values = List<int>.filled(128, -1);
  final List<int> _keys = [];

  @override
  int? operator [](Object? key) {
    if (key is int && key >= 0 && key < 128) {
      final val = _values[key];
      if (val != -1) return val;
    }
    return null;
  }

  @override
  void operator []=(int key, int value) {
    if (key >= 0 && key < 128) {
      if (_values[key] == -1) {
        _keys.add(key);
      }
      _values[key] = value;
    }
  }

  @override
  void clear() {
    for (final k in _keys) {
      _values[k] = -1;
    }
    _keys.clear();
  }

  @override
  Iterable<int> get keys => _keys;

  @override
  int? remove(Object? key) {
    if (key is int && key >= 0 && key < 128) {
      final val = _values[key];
      if (val != -1) {
        _values[key] = -1;
        _keys.remove(key);
        return val;
      }
    }
    return null;
  }
}

class _CcSnapshotBuffer {
  final List<int> _values = List<int>.filled(128, -1);
  final List<int> _keys = [];
  _CcBatchSnapshot? _activeSnapshot;
  int _generation = 0;

  void freezeActiveSnapshot() {
    _activeSnapshot?._freezeFromBuffer();
  }

  void loadFrom(_CcBatchContainer source) {
    for (final key in _keys) {
      _values[key] = -1;
    }
    _keys.clear();

    for (final key in source._keys) {
      _keys.add(key);
      _values[key] = source._values[key];
    }
  }

  _CcBatchSnapshot publish(int generation) {
    _generation = generation;
    final snapshot = _CcBatchSnapshot._(
      this,
      generation,
      List<int>.of(_keys, growable: false),
    );
    _activeSnapshot = snapshot;
    return snapshot;
  }
}

class _CcBatchSnapshot extends MapBase<int, int> {
  final _CcSnapshotBuffer _buffer;
  final int _generation;
  final List<int> _keys;
  Map<int, int>? _frozenEntries;

  _CcBatchSnapshot._(this._buffer, this._generation, this._keys);

  void _freezeFromBuffer() {
    if (_frozenEntries != null) return;

    final frozen = <int, int>{};
    for (final key in _keys) {
      frozen[key] = _buffer._values[key];
    }
    _frozenEntries = Map.unmodifiable(frozen);
  }

  @override
  int? operator [](Object? key) {
    if (key is! int || key < 0 || key >= 128) {
      return null;
    }

    final frozen = _frozenEntries;
    if (frozen != null) {
      return frozen[key];
    }

    if (_buffer._generation != _generation) {
      return null;
    }

    final val = _buffer._values[key];
    if (val != -1) {
      return val;
    }

    return null;
  }

  @override
  void operator []=(int key, int value) {
    throw UnsupportedError('Snapshot is immutable');
  }

  @override
  void clear() {
    throw UnsupportedError('Snapshot is immutable');
  }

  @override
  Iterable<int> get keys => _frozenEntries?.keys ?? _keys;

  @override
  int? remove(Object? key) {
    throw UnsupportedError('Snapshot is immutable');
  }
}

class UiStateSinkNode extends SinkNode {
  final void Function(Map<int, int>) onUpdateCCs;
  final _CcBatchContainer _reusableBatch = _CcBatchContainer();
  final List<_CcSnapshotBuffer> _snapshotBuffers = [
    _CcSnapshotBuffer(),
    _CcSnapshotBuffer(),
  ];
  int _nextSnapshotBufferIndex = 0;
  int _snapshotGeneration = 0;

  UiStateSinkNode({required this.onUpdateCCs});

  void _emitSnapshot() {
    final buffer = _snapshotBuffers[_nextSnapshotBufferIndex];

    // Preserve immutability of a previously published snapshot before reusing
    // this backing buffer for a new generation.
    buffer.freezeActiveSnapshot();
    buffer.loadFrom(_reusableBatch);

    _snapshotGeneration++;
    final snapshot = buffer.publish(_snapshotGeneration);
    _nextSnapshotBufferIndex = (_nextSnapshotBufferIndex + 1) % 2;

    onUpdateCCs(snapshot);
  }

  @override
  void executeSingle(MidiEvent event) {
    if (event.legacyStatusByte >= 0xB0 && event.legacyStatusByte <= 0xBF) {
      _reusableBatch.clear();
      _reusableBatch[event.data1] = event.data2;
      _emitSnapshot();
    }
  }

  @override
  void execute(List<MidiEvent> events) {
    bool hasUpdates = false;

    for (var event in events) {
      if (event.legacyStatusByte >= 0xB0 && event.legacyStatusByte <= 0xBF) {
        if (!hasUpdates) {
          _reusableBatch.clear();
          hasUpdates = true;
        }
        _reusableBatch[event.data1] = event.data2;
      }
    }

    if (hasUpdates) {
      _emitSnapshot();
    }
  }
}

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

class UiStateSinkNode extends SinkNode {
  final void Function(Map<int, int>) onUpdateCCs;
  final _CcBatchContainer _reusableBatch = _CcBatchContainer();

  UiStateSinkNode({required this.onUpdateCCs});

  @override
  void executeSingle(MidiEvent event) {
    if (event.legacyStatusByte >= 0xB0 && event.legacyStatusByte <= 0xBF) {
      _reusableBatch.clear();
      _reusableBatch[event.data1] = event.data2;
      onUpdateCCs(_reusableBatch);
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
      onUpdateCCs(Map<int, int>.from(_reusableBatch));
    }
  }
}

// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:typed_data';
import '../../models/midi_event.dart';
import 'sink_node.dart';

class UiStateSinkNode extends SinkNode {
  static final List<String> _addressKeys = List<String>.generate(2048, (index) {
    final channel = index ~/ 128;
    final cc = index % 128;
    return '$channel:$cc';
  }, growable: false);

  final void Function(Map<String, dynamic>) onStateUpdate;

  // 16 channels * 128 CCs = 2048
  final Int32List _ccBuffer = Int32List(2048)..fillRange(0, 2048, -1);
  final Set<int> _dirtyCcIndices = {};

  // For discrete Note On/Off tracking and Button states
  final Map<int, Set<int>> _noteStates = {};
  final Map<String, bool> _buttonStates = {};

  bool _hasNoteUpdates = false;
  bool _hasButtonUpdates = false;

  UiStateSinkNode({required this.onStateUpdate});

  // Debounce timing
  DateTime? _lastEmitTime;
  static const int _throttleMs = 16;
  bool _hasPendingEmission = false;

  void _emitSnapshot() {
    final ccBatch = <String, int>{};
    for (final index in _dirtyCcIndices) {
      ccBatch[_addressKeys[index]] = _ccBuffer[index];
    }
    _dirtyCcIndices.clear();

    final payload = <String, dynamic>{'ccs': ccBatch};

    if (_hasNoteUpdates) {
      final noteBatch = <int, List<int>>{};
      for (final entry in _noteStates.entries) {
        noteBatch[entry.key] = entry.value.toList();
      }
      payload['notes'] = noteBatch;
      _hasNoteUpdates = false;
    }

    if (_hasButtonUpdates) {
      payload['buttons'] = Map<String, bool>.from(_buttonStates);
      _hasButtonUpdates = false;
    }

    onStateUpdate(payload);
    _lastEmitTime = DateTime.now();
  }

  void _throttledEmit() {
    if (_dirtyCcIndices.isEmpty && !_hasNoteUpdates && !_hasButtonUpdates) {
      return;
    }

    final now = DateTime.now();
    if (_lastEmitTime == null ||
        now.difference(_lastEmitTime!).inMilliseconds >= _throttleMs) {
      _emitSnapshot();
      _hasPendingEmission = false;
    } else if (!_hasPendingEmission) {
      _hasPendingEmission = true;
      Future.delayed(
        Duration(
          milliseconds:
              _throttleMs - now.difference(_lastEmitTime!).inMilliseconds,
        ),
        () {
          if (_hasPendingEmission) {
            _emitSnapshot();
            _hasPendingEmission = false;
          }
        },
      );
    }
  }

  void _processEvent(MidiEvent event) {
    if (event.legacyStatusByte >= 0xB0 && event.legacyStatusByte <= 0xBF) {
      // CC Event
      final channel = event.channel;
      final cc = event.data1;
      final value = event.data2;
      final index = (channel * 128) + cc;

      if (_ccBuffer[index] != value) {
        _ccBuffer[index] = value;
        _dirtyCcIndices.add(index);
      }
    } else if (event.legacyStatusByte >= 0x90 &&
        event.legacyStatusByte <= 0x9F) {
      // Note On Event
      final channel = event.channel;
      final note = event.data1;
      final velocity = event.data2;

      if (velocity > 0) {
        if (_noteStates.putIfAbsent(channel, () => {}).add(note)) {
          _hasNoteUpdates = true;
        }
      } else {
        // Note On with 0 velocity acts as Note Off
        if (_noteStates[channel]?.remove(note) ?? false) {
          _hasNoteUpdates = true;
        }
      }
    } else if (event.legacyStatusByte >= 0x80 &&
        event.legacyStatusByte <= 0x8F) {
      // Note Off Event
      final channel = event.channel;
      final note = event.data1;
      if (_noteStates[channel]?.remove(note) ?? false) {
        _hasNoteUpdates = true;
      }
    }
  }

  @override
  void executeSingle(MidiEvent event) {
    _processEvent(event);
    _throttledEmit();
  }

  @override
  void execute(List<MidiEvent> events) {
    for (final event in events) {
      _processEvent(event);
    }
    _throttledEmit();
  }
}

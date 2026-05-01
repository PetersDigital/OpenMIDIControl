// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/scheduler.dart';
import '../../models/midi_event.dart';
import 'sink_node.dart';

class UiStateSinkNode extends SinkNode {
  static final List<String> _addressKeys = List<String>.generate(2048, (index) {
    final channel = index ~/ 128;
    final cc = index % 128;
    return '$channel:$cc';
  }, growable: false);

  static final List<String> _noteAddressKeys = List<String>.generate(2048, (
    index,
  ) {
    final channel = index ~/ 128;
    final note = index % 128;
    return 'note:$channel:$note';
  }, growable: false);

  final void Function(Map<String, dynamic>) onStateUpdate;

  // 16 channels * 128 CCs = 2048
  final Int32List _ccBuffer = Int32List(2048)..fillRange(0, 2048, -1);
  final Set<int> _dirtyCcIndices = {};

  // For discrete Note On/Off tracking and Button states
  final Map<int, Set<int>> _noteStates = {};
  final Map<int, Set<int>> _buttonNoteStates = {};
  final Set<int> _activeCcButtons = {};

  bool _hasNoteUpdates = false;
  bool _hasButtonUpdates = false;

  UiStateSinkNode({required this.onStateUpdate});

  // Debounce timing
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
      final buttonMap = <String, bool>{};
      // Note buttons
      for (final entry in _buttonNoteStates.entries) {
        final channel = entry.key;
        for (final note in entry.value) {
          buttonMap[_noteAddressKeys[(channel * 128) + note]] = true;
        }
      }
      // CC buttons
      for (final index in _activeCcButtons) {
        buttonMap[_addressKeys[index]] = true;
      }
      payload['buttons'] = buttonMap;
      _hasButtonUpdates = false;
    }

    onStateUpdate(payload);
  }

  void _throttledEmit() {
    if (_dirtyCcIndices.isEmpty && !_hasNoteUpdates && !_hasButtonUpdates) {
      return;
    }

    if (!_hasPendingEmission) {
      _hasPendingEmission = true;

      // Sync emission with the hardware display refresh rate.
      // In headless unit tests, frames are never drawn, causing scheduleFrameCallback to hang.
      try {
        final isTest = io.Platform.environment.containsKey('FLUTTER_TEST');
        if (!isTest) {
          SchedulerBinding.instance.scheduleFrameCallback((_) {
            if (_hasPendingEmission) {
              _emitSnapshot();
              _hasPendingEmission = false;
            }
          });
          SchedulerBinding.instance.ensureVisualUpdate();
        } else {
          _emitSnapshot();
          _hasPendingEmission = false;
        }
      } catch (_) {
        // Fallback for isolated contexts
        _emitSnapshot();
        _hasPendingEmission = false;
      }
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

        // Update button state (>= 64 is active)
        if (value >= 64) {
          if (_activeCcButtons.add(index)) {
            _hasButtonUpdates = true;
          }
        } else {
          if (_activeCcButtons.remove(index)) {
            _hasButtonUpdates = true;
          }
        }
      }
    } else if (event.legacyStatusByte >= 0x90 &&
        event.legacyStatusByte <= 0x9F) {
      // Note On Event
      final channel = event.channel;
      final note = event.data1;
      final velocity = event.data2;

      if (velocity > 0) {
        if (_noteStates.putIfAbsent(channel, () => <int>{}).add(note)) {
          _hasNoteUpdates = true;
        }
        if (_buttonNoteStates.putIfAbsent(channel, () => <int>{}).add(note)) {
          _hasButtonUpdates = true;
        }
      } else {
        // Note On with 0 velocity acts as Note Off
        if (_noteStates[channel]?.remove(note) ?? false) {
          _hasNoteUpdates = true;
        }
        if (_buttonNoteStates[channel]?.remove(note) ?? false) {
          _hasButtonUpdates = true;
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
      if (_buttonNoteStates[channel]?.remove(note) ?? false) {
        _hasButtonUpdates = true;
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

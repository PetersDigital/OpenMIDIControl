// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/scheduler.dart';
import '../../models/midi_event.dart';
import 'sink_node.dart';

class UiStateSinkNode extends SinkNode {
  static const int _addressCount = 16 * 128;
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

  static final _controllerKeys = [
    for (var channel = 0; channel < 16; channel++) 'bend:$channel',
    for (final address in _addressKeys) 'cc32:$address',
  ];

  final _controllerValues = Int64List(16 + _addressCount)
    ..fillRange(0, 16 + _addressCount, -1);
  final _dirtyControllers = <int>{};

  final void Function(Map<String, dynamic>) onStateUpdate;
  final bool useTimerOnly;

  // 16 channels * 128 CCs = 2048
  final Int32List _ccBuffer = Int32List(2048)..fillRange(0, 2048, -1);
  final Set<int> _dirtyCcIndices = {};

  final Map<int, Set<int>> _noteStates = {};
  // CC addresses followed by note addresses. -1 means no state received yet.
  final Int8List _buttonBuffer = Int8List(_addressCount * 2)
    ..fillRange(0, _addressCount * 2, -1);
  final Set<int> _dirtyButtonIndices = {};

  bool _hasNoteUpdates = false;

  UiStateSinkNode({required this.onStateUpdate, this.useTimerOnly = false});

  // Debounce timing
  bool isPaused = false;
  bool _disposed = false;
  bool _hasPendingEmission = false;
  Timer? _fallbackTimer;

  void setPaused(bool paused) {
    isPaused = paused;
    if (!paused && !_disposed) {
      _throttledEmit();
    }
  }

  void _emitSnapshot() {
    final ccBatch = <String, int>{};
    for (final index in _dirtyCcIndices) {
      ccBatch[_addressKeys[index]] = _ccBuffer[index];
    }
    _dirtyCcIndices.clear();

    final payload = <String, dynamic>{'ccs': ccBatch};

    if (_dirtyControllers.isNotEmpty) {
      payload['controllers'] = <String, int>{
        for (final index in _dirtyControllers)
          _controllerKeys[index]: _controllerValues[index],
      };
      _dirtyControllers.clear();
    }

    if (_hasNoteUpdates) {
      final noteBatch = <int, List<int>>{};
      for (final entry in _noteStates.entries) {
        noteBatch[entry.key] = entry.value.toList();
      }
      payload['notes'] = noteBatch;
      _hasNoteUpdates = false;
    }

    if (_dirtyButtonIndices.isNotEmpty) {
      final buttonMap = <String, bool>{};
      for (final index in _dirtyButtonIndices) {
        final address = index < _addressCount
            ? _addressKeys[index]
            : _noteAddressKeys[index - _addressCount];
        buttonMap[address] = _buttonBuffer[index] == 1;
      }
      _dirtyButtonIndices.clear();
      payload['buttons'] = buttonMap;
    }

    onStateUpdate(payload);
  }

  void _throttledEmit() {
    if (_disposed) return;
    if (_dirtyCcIndices.isEmpty &&
        _dirtyControllers.isEmpty &&
        !_hasNoteUpdates &&
        _dirtyButtonIndices.isEmpty) {
      return;
    }

    if (!_hasPendingEmission) {
      _hasPendingEmission = true;

      if (isPaused) {
        _hasPendingEmission = false;
        return;
      }

      // Sync emission with the hardware display refresh rate.
      // In headless unit tests, frames are never drawn, causing scheduleFrameCallback to hang.
      final isTest = io.Platform.environment.containsKey('FLUTTER_TEST');
      if (isTest) {
        _emitSnapshot();
        _hasPendingEmission = false;
        return;
      }

      if (useTimerOnly) {
        _scheduleFallbackTimer();
        return;
      }

      try {
        SchedulerBinding.instance.scheduleFrameCallback((_) {
          if (_disposed || isPaused) {
            _hasPendingEmission = false;
            return;
          }
          if (_hasPendingEmission) {
            _emitSnapshot();
            _hasPendingEmission = false;
          }
        });
      } catch (_) {
        // Fallback for isolated contexts
        _scheduleFallbackTimer();
      }
    }
  }

  void _scheduleFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(milliseconds: 16), () {
      if (_disposed || isPaused) {
        _hasPendingEmission = false;
        return;
      }
      if (_hasPendingEmission) {
        _emitSnapshot();
        _hasPendingEmission = false;
      }
    });
  }

  void _updateButton(int index, bool isOn) {
    final value = isOn ? 1 : 0;
    if (_buttonBuffer[index] == value) return;
    _buttonBuffer[index] = value;
    _dirtyButtonIndices.add(index);
  }

  void _updateController(int index, int value) {
    if (_controllerValues[index] == value) return;
    _controllerValues[index] = value;
    _dirtyControllers.add(index);
  }

  void _processEvent(MidiEvent event) {
    final identifier = event.data1;
    if (identifier > 127) return;
    final channel = event.channel;
    final index = (channel * 128) + identifier;
    final status = event.status;
    final isMidi2 = event.messageType == 4;
    if (isMidi2 && event.group != 0) return;

    if (event.group == 0 && status == 0xE0) {
      final bend =
          event.pitchBend32 ??
          (((event.data2 << 7) | identifier) * 0xFFFFFFFF / 16383).round();
      _updateController(channel, bend);
      return;
    }
    if (event.group == 0 &&
        status == 0xB0 &&
        MidiEvent.isMidi2AbsoluteCc(identifier)) {
      final cc = event.ccValue32 ?? (event.data2 * 0xFFFFFFFF / 127).round();
      _updateController(16 + index, cc);
    }

    final value = switch (status) {
      0xB0 when isMidi2 => (event.ccValue32 ?? 0) >>> 25,
      0x80 || 0x90 when isMidi2 => event.noteVelocity16 ?? 0,
      _ => event.data2,
    };

    if (status == 0xB0) {
      if (_ccBuffer[index] != value) {
        _ccBuffer[index] = value;
        _dirtyCcIndices.add(index);
      }
      _updateButton(index, value >= 64);
    } else if (status == 0x90 || status == 0x80) {
      final isOn = status == 0x90 && value > 0;
      final changed = isOn
          ? _noteStates.putIfAbsent(channel, () => <int>{}).add(identifier)
          : (_noteStates[channel]?.remove(identifier) ?? false);
      if (changed) _hasNoteUpdates = true;
      _updateButton(_addressCount + index, isOn);
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

  void dispose() {
    _disposed = true;
    _hasPendingEmission = false;
    _fallbackTimer?.cancel();
  }
}

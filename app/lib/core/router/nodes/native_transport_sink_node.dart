// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/midi_event.dart';
import 'sink_node.dart';

import 'dart:async';

class NativeTransportSinkNode extends SinkNode {
  final MethodChannel channel;

  static const int _maxBufferSize = 10;
  static const Duration _flushInterval = Duration(milliseconds: 16);

  static final List<Int64List> _bufferPool = [Int64List(0)];

  @visibleForTesting
  static int get bufferPoolLength => _bufferPool.length;

  final List<MidiEvent> _eventBuffer = [];
  Timer? _flushTimer;

  NativeTransportSinkNode({required this.channel});

  @override
  void executeSingle(MidiEvent event) {
    // Filter out non-CC events
    if (event.messageType == 0x2 && (event.legacyStatusByte & 0xF0) == 0xB0) {
      _eventBuffer.add(event);

      if (_flushTimer == null || !_flushTimer!.isActive) {
        _flushTimer = Timer(_flushInterval, () => _flush());
      }

      if (_eventBuffer.length >= _maxBufferSize) {
        _flushTimer?.cancel();
        _flushTimer = null;
        _flush();
      }
    }
  }

  @override
  void execute(List<MidiEvent> events) {
    if (events.isEmpty) return;

    for (var event in events) {
      // Filter out non-CC events before buffering to save space
      if (event.messageType == 0x2 && (event.legacyStatusByte & 0xF0) == 0xB0) {
        _eventBuffer.add(event);
      }
    }

    if (_eventBuffer.isEmpty) return;

    if (_flushTimer == null || !_flushTimer!.isActive) {
      _flushTimer = Timer(_flushInterval, () => _flush());
    }

    if (_eventBuffer.length >= _maxBufferSize) {
      _flushTimer?.cancel();
      _flushTimer = null;
      _flush();
    }
  }

  void _flush() {
    _flushTimer?.cancel();
    _flushTimer = null;

    if (_eventBuffer.isEmpty) {
      return;
    }

    final int count = _eventBuffer.length;
    while (_bufferPool.length <= count) {
      _bufferPool.add(Int64List(_bufferPool.length * 2));
    }

    final batch = _bufferPool[count];

    for (int i = 0; i < count; i++) {
      batch[i * 2] = _eventBuffer[i].ump;
      batch[i * 2 + 1] = _eventBuffer[i].isFinal ? 1 : 0;
    }

    channel.invokeMethod('sendMidiCCBatch', {'events': batch}).catchError((e) {
      debugPrint('Failed to send MIDI CC batch: $e');
    });

    _eventBuffer.clear();
  }

  void dispose() {
    _flushTimer?.cancel();
    _eventBuffer.clear();
  }
}

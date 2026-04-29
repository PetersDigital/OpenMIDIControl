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

  static Int64List _sharedBuffer = Int64List(0);

  @visibleForTesting
  static int get sharedBufferCapacity => _sharedBuffer.length;

  final List<MidiEvent> _eventBuffer = [];
  Timer? _flushTimer;

  NativeTransportSinkNode({required this.channel});

  @override
  void executeSingle(MidiEvent event) {
    // Filter out non-MIDI 1.0 voice messages
    final statusNibble = event.legacyStatusByte & 0xF0;
    if (event.messageType == 0x2 &&
        (statusNibble == 0x80 ||
            statusNibble == 0x90 ||
            statusNibble == 0xB0 ||
            statusNibble == 0xE0)) {
      _eventBuffer.add(event);

      if (_flushTimer == null || !_flushTimer!.isActive) {
        _flushTimer = Timer(_flushInterval, () => _flush());
      }

      if (event.isFinal || _eventBuffer.length >= _maxBufferSize) {
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
      final statusNibble = event.legacyStatusByte & 0xF0;
      if (event.messageType == 0x2 &&
          (statusNibble == 0x80 ||
              statusNibble == 0x90 ||
              statusNibble == 0xB0 ||
              statusNibble == 0xE0)) {
        _eventBuffer.add(event);
      }
    }

    if (_eventBuffer.isEmpty) return;

    if (_flushTimer == null || !_flushTimer!.isActive) {
      _flushTimer = Timer(_flushInterval, () => _flush());
    }

    if (events.any((e) => e.isFinal) || _eventBuffer.length >= _maxBufferSize) {
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
    final int requiredCapacity = count * 2;

    if (_sharedBuffer.length < requiredCapacity) {
      _sharedBuffer = Int64List(requiredCapacity);
    }

    for (int i = 0; i < count; i++) {
      _sharedBuffer[i * 2] = _eventBuffer[i].ump;
      _sharedBuffer[i * 2 + 1] = _eventBuffer[i].isFinal ? 1 : 0;
    }

    final batch = Int64List.sublistView(_sharedBuffer, 0, requiredCapacity);

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

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

  static final Int64List _singleCcBuffer = Int64List(
    2,
  ); // Reusable pool for single CCs

  final List<MidiEvent> _eventBuffer = [];
  Timer? _flushTimer;

  NativeTransportSinkNode({required this.channel});

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
      _flushTimer = Timer(_flushInterval, _flush);
    }

    if (_eventBuffer.length >= _maxBufferSize) {
      _flush();
    }
  }

  void _flush() {
    if (_eventBuffer.isEmpty) return;

    if (_eventBuffer.length == 1) {
      _singleCcBuffer[0] = _eventBuffer[0].ump;
      _singleCcBuffer[1] = _eventBuffer[0].isFinal ? 1 : 0;
      channel
          .invokeMethod('sendMidiCCBatch', {'events': _singleCcBuffer})
          .catchError((e) {
            debugPrint('Failed to send MIDI CC batch: $e');
          });
    } else {
      final batch = Int64List(_eventBuffer.length * 2);
      for (int i = 0; i < _eventBuffer.length; i++) {
        batch[i * 2] = _eventBuffer[i].ump;
        batch[i * 2 + 1] = _eventBuffer[i].isFinal ? 1 : 0;
      }

      channel.invokeMethod('sendMidiCCBatch', {'events': batch}).catchError((
        e,
      ) {
        debugPrint('Failed to send MIDI CC batch: $e');
      });
    }

    _eventBuffer.clear();
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  void dispose() {
    _flushTimer?.cancel();
    _eventBuffer.clear();
  }
}

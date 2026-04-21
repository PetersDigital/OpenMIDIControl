// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:collection';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/midi_event.dart';
import '../midi_service.dart';

class _RingBufferList<T> extends ListBase<T> {
  final List<T?> _buffer;
  final int _head;
  final int _length;

  _RingBufferList(int capacity)
    : _buffer = List<T?>.filled(capacity, null, growable: false),
      _head = 0,
      _length = 0;

  _RingBufferList._(this._buffer, this._head, this._length);

  @override
  int get length => _length;

  @override
  set length(int newLength) =>
      throw UnsupportedError('Cannot resize _RingBufferList directly');

  @override
  T operator [](int index) {
    if (index < 0 || index >= _length) throw RangeError.index(index, this);
    return _buffer[(_head + index) % _buffer.length] as T;
  }

  @override
  void operator []=(int index, T value) {
    if (index < 0 || index >= _length) throw RangeError.index(index, this);
    _buffer[(_head + index) % _buffer.length] = value;
  }

  _RingBufferList<T> addFront(Iterable<T> elements) {
    var newHead = _head;
    var newLength = _length;
    for (final e in elements) {
      newHead = (newHead - 1) % _buffer.length;
      if (newHead < 0) newHead += _buffer.length;
      _buffer[newHead] = e;
      if (newLength < _buffer.length) newLength++;
    }
    return _RingBufferList<T>._(_buffer, newHead, newLength);
  }
}

class DiagnosticLogEntry {
  final MidiEvent rawEvent;
  String? formatted; // Lazy-computed

  DiagnosticLogEntry({required this.rawEvent, this.formatted});

  String getFormatted() {
    formatted ??= _formatMidiEvent(rawEvent);
    return formatted!;
  }

  static String _formatMidiEvent(MidiEvent event) {
    // utilizes actual event.timestamp (nanoseconds) provided by native layer
    final totalMs = event.timestamp ~/ 1000000;
    final h = (totalMs ~/ 3600000);
    final m = (totalMs ~/ 60000) % 60;
    final s = (totalMs ~/ 1000) % 60;
    final ms = totalMs % 1000;

    final timeStr =
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}.${ms.toString().padLeft(3, '0')}';

    // Add port ID or device ID if known in the future. Currently sourceId is default 'unknown'
    final portStr = event.sourceId != 'unknown'
        ? 'Port ${event.sourceId} | '
        : '';

    if (event.legacyStatusByte >= 0xB0 && event.legacyStatusByte <= 0xBF) {
      return '[$timeStr] MIDI IN: ${portStr}Ch ${event.channel + 1} | CC ${event.data1} | Val ${event.data2}';
    } else {
      return '[$timeStr] MIDI IN: ${portStr}Type 0x${event.messageType.toRadixString(16)} | Ch ${event.channel + 1} | D1 ${event.data1} | D2 ${event.data2}';
    }
  }
}

class DiagnosticsLoggerNotifier extends Notifier<List<DiagnosticLogEntry>> {
  static const int maxLogs = 200;
  final List<DiagnosticLogEntry> _pendingEvents = [];
  bool _pendingUpdate = false;
  bool _disposed = false;

  @override
  List<DiagnosticLogEntry> build() {
    final service = ref.watch(midiServiceProvider);

    final sub = service.midiEventsStream.listen((midiEvents) {
      if (midiEvents.isEmpty) return;

      for (var midiEvent in midiEvents) {
        _pendingEvents.add(DiagnosticLogEntry(rawEvent: midiEvent));
      }

      // Batch state updates to prevent excessive rebuilds from high-frequency MIDI events
      if (!_pendingUpdate) {
        _pendingUpdate = true;
        // Schedule state update for next frame (~16ms at 60Hz)
        SchedulerBinding.instance.scheduleFrameCallback((_) {
          if (_disposed) return;
          _pendingUpdate = false;
          if (_pendingEvents.isEmpty) return;

          // Publish minimal delta by sharing the underlying ring buffer array
          // and emitting a new wrapper. The sequential addition of events naturally
          // prepends them in reverse chronological order since we advance the head backwards.
          state = (state as _RingBufferList<DiagnosticLogEntry>).addFront(
            _pendingEvents,
          );
          _pendingEvents.clear();
        });
      }
    });

    ref.onDispose(() {
      _disposed = true;
      _pendingUpdate = false;
      sub.cancel();
      _pendingEvents.clear();
    });

    return _RingBufferList<DiagnosticLogEntry>(maxLogs);
  }

  void clear() {
    _pendingEvents.clear();
    state = _RingBufferList<DiagnosticLogEntry>(maxLogs);
  }
}

final diagnosticsProvider =
    NotifierProvider.autoDispose<
      DiagnosticsLoggerNotifier,
      List<DiagnosticLogEntry>
    >(DiagnosticsLoggerNotifier.new);

// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';
import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import '../../core/lifecycle/app_lifecycle_manager.dart';

import '../../core/models/midi_event.dart';
import '../midi_service.dart';
import '../../core/midi_utils.dart';

class _RingBufferList<T> extends ListBase<T> {
  final List<T?> _buffer;
  int _head;
  int _length;

  _RingBufferList(int capacity)
    : _buffer = List<T?>.filled(capacity, null, growable: false),
      _head = 0,
      _length = 0;

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

  void addFrontInPlace(Iterable<T> elements) {
    for (final e in elements) {
      _head = (_head - 1) % _buffer.length;
      if (_head < 0) _head += _buffer.length;
      _buffer[_head] = e;
      if (_length < _buffer.length) _length++;
    }
  }

  void clearInPlace() {
    _head = 0;
    _length = 0;
    _buffer.fillRange(0, _buffer.length, null);
  }
}

class DiagnosticsState {
  final List<DiagnosticLogEntry> entries;
  final int version;

  DiagnosticsState({required this.entries, required this.version});
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
    // utilizes actual event.timestamp (milliseconds) provided by native layer
    final totalMs = event.timestamp;
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

    final status = event.legacyStatusByte;
    if (status >= 0xB0 && status <= 0xBF) {
      return '[$timeStr] MIDI IN: ${portStr}Ch ${event.channel + 1} | CC ${event.data1} | Val ${event.data2}';
    } else if (status >= 0x90 && status <= 0x9F) {
      final noteName = MidiUtils.getNoteName(event.data1);
      return '[$timeStr] MIDI IN: ${portStr}Ch ${event.channel + 1} | Note On $noteName (${event.data1}) | Vel ${event.data2}';
    } else if (status >= 0x80 && status <= 0x8F) {
      final noteName = MidiUtils.getNoteName(event.data1);
      return '[$timeStr] MIDI IN: ${portStr}Ch ${event.channel + 1} | Note Off $noteName (${event.data1}) | Vel ${event.data2}';
    } else {
      return '[$timeStr] MIDI IN: ${portStr}Type 0x${event.messageType.toRadixString(16)} | Ch ${event.channel + 1} | D1 ${event.data1} | D2 ${event.data2}';
    }
  }
}

class DiagnosticsLoggerNotifier extends Notifier<DiagnosticsState> {
  static const int maxLogs = 500;
  static const Duration _publishCadence = Duration(milliseconds: 100);

  final Queue<DiagnosticLogEntry> _pendingEvents =
      ListQueue<DiagnosticLogEntry>();

  late final _RingBufferList<DiagnosticLogEntry> _buffer;
  int _version = 0;
  bool _pendingUpdate = false;
  bool _disposed = false;
  Timer? _publishTimer;

  bool _isPaused = false;

  @override
  DiagnosticsState build() {
    _buffer = _RingBufferList<DiagnosticLogEntry>(maxLogs);
    final service = ref.watch(midiServiceProvider);

    ref.listen(appLifecycleStateProvider, (previous, next) {
      _isPaused =
          (next == AppLifecycleState.paused ||
          next == AppLifecycleState.hidden);
    });

    final sub = service.midiEventsStream.listen((midiEvents) {
      if (_isPaused) return;
      if (midiEvents.isEmpty) return;

      // Prevent excessive instantiation by limiting the batch to maxLogs
      int startIndex = 0;
      if (midiEvents.length > DiagnosticsLoggerNotifier.maxLogs) {
        startIndex = midiEvents.length - DiagnosticsLoggerNotifier.maxLogs;
      }

      for (int i = startIndex; i < midiEvents.length; i++) {
        if (_pendingEvents.length >= DiagnosticsLoggerNotifier.maxLogs) {
          _pendingEvents.removeFirst();
        }
        _pendingEvents.add(DiagnosticLogEntry(rawEvent: midiEvents[i]));
      }

      // Batch state updates to prevent excessive rebuilds from high-frequency MIDI events.
      // Throttling to a fixed cadence instead of frame cadence reduces CPU load
      // significantly under sustained input.
      if (!_pendingUpdate) {
        _pendingUpdate = true;
        _publishTimer = Timer(_publishCadence, () {
          if (_disposed) return;
          _pendingUpdate = false;
          // Mutate in-place and update version ID to avoid List.of copies.
          // This ensures that high-density MIDI logging doesn't cause GC spikes.
          _buffer.addFrontInPlace(_pendingEvents);
          _pendingEvents.clear();

          _version++;
          state = DiagnosticsState(entries: _buffer, version: _version);
        });
      }
    });

    ref.onDispose(() {
      _disposed = true;
      _pendingUpdate = false;
      _publishTimer?.cancel();
      sub.cancel();
      _pendingEvents.clear();
    });

    return DiagnosticsState(entries: _buffer, version: 0);
  }

  void clear() {
    _pendingEvents.clear();
    _buffer.clearInPlace();
    _version++;
    state = DiagnosticsState(entries: _buffer, version: _version);
  }
}

final diagnosticsProvider =
    NotifierProvider.autoDispose<DiagnosticsLoggerNotifier, DiagnosticsState>(
      DiagnosticsLoggerNotifier.new,
    );

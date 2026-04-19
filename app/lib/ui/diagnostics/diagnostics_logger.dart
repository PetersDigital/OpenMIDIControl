// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'dart:collection';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/midi_event.dart';
import '../midi_service.dart';

class DiagnosticLogEntry {
  final DateTime timestamp;
  final MidiEvent rawEvent;
  String? formatted; // Lazy-computed

  DiagnosticLogEntry({
    required this.timestamp,
    required this.rawEvent,
    this.formatted,
  });

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
  final Queue<DiagnosticLogEntry> _logs = Queue<DiagnosticLogEntry>();
  bool _pendingUpdate = false;
  bool _disposed = false;

  @override
  List<DiagnosticLogEntry> build() {
    final service = ref.watch(midiServiceProvider);

    final sub = service.midiEventsStream.listen((midiEvents) {
      if (midiEvents.isEmpty) return;

      for (var midiEvent in midiEvents) {
        _logs.addFirst(
          DiagnosticLogEntry(timestamp: DateTime.now(), rawEvent: midiEvent),
        );
        if (_logs.length > maxLogs) {
          _logs.removeLast();
        }
      }

      // Batch state updates to prevent excessive rebuilds from high-frequency MIDI events
      if (!_pendingUpdate) {
        _pendingUpdate = true;
        // Schedule state update for next frame (~16ms at 60Hz)
        SchedulerBinding.instance.scheduleFrameCallback((_) {
          if (_disposed) return;
          _pendingUpdate = false;
          // Only convert to list when listeners exist (build is active)
          state = _logs.toList();
        });
      }
    });

    ref.onDispose(() {
      _disposed = true;
      _pendingUpdate = false;
      sub.cancel();
      _logs.clear();
    });

    return [];
  }

  void clear() {
    _logs.clear();
    state = [];
  }
}

final diagnosticsProvider =
    NotifierProvider.autoDispose<
      DiagnosticsLoggerNotifier,
      List<DiagnosticLogEntry>
    >(DiagnosticsLoggerNotifier.new);

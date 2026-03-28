import 'dart:collection';

import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/midi_event.dart';
import '../midi_service.dart';

class DiagnosticsLoggerNotifier extends Notifier<List<String>> {
  static const int maxLogs = 200;
  final Queue<String> _logs = Queue<String>();
  bool _pendingUpdate = false;

  @override
  List<String> build() {
    final service = ref.watch(midiServiceProvider);

    final sub = service.midiEventsStream.listen((midiEvents) {
      for (var midiEvent in midiEvents) {
        _addLog(_formatMidiEvent(midiEvent));
      }
    });

    ref.onDispose(() {
      sub.cancel();
    });

    return [];
  }

  String _formatMidiEvent(MidiEvent event) {
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

  void _addLog(String logMessage) {
    _logs.addFirst(logMessage);
    if (_logs.length > maxLogs) {
      _logs.removeLast();
    }
    // Batch state updates to prevent excessive rebuilds from high-frequency MIDI events
    if (!_pendingUpdate) {
      _pendingUpdate = true;
      // Schedule state update for next frame (~16ms at 60Hz)
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        _pendingUpdate = false;
        // Update state to trigger rebuilds only for listeners of this provider
        state = _logs.toList();
      });
    }
  }

  void clear() {
    _logs.clear();
    state = [];
  }
}

final diagnosticsProvider =
    NotifierProvider.autoDispose<DiagnosticsLoggerNotifier, List<String>>(
      DiagnosticsLoggerNotifier.new,
    );

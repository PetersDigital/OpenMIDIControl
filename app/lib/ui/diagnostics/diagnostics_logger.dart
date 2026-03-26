import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/midi_event.dart';
import '../midi_service.dart';

class DiagnosticsLoggerNotifier extends Notifier<List<String>> {
  static const int maxLogs = 200;
  final Queue<String> _logs = Queue<String>();

  @override
  List<String> build() {
    final service = ref.watch(midiServiceProvider);

    final sub = service.midiEventsStream.listen((event) {
      if (event is Map) {
        final type = event['type'];
        if (type == 'batch') {
          final rawEvents = event['events'];
          if (rawEvents is List) {
            final midiEvents = rawEvents
                .whereType<Map<dynamic, dynamic>>()
                .map((e) => MidiEvent.fromMap(e))
                .toList();

            for (var midiEvent in midiEvents) {
              _addLog(_formatMidiEvent(midiEvent));
            }
          }
        } else if (type == 'cc') {
          final midiEvent = MidiEvent.fromMap(event);
          _addLog(_formatMidiEvent(midiEvent));
        }
      }
    });

    ref.onDispose(() {
      sub.cancel();
    });

    return [];
  }

  String _formatMidiEvent(MidiEvent event) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';

    // Add port ID or device ID if known in the future. Currently sourceId is default 'unknown'
    final portStr = event.sourceId != 'unknown' ? 'Port ${event.sourceId} | ' : '';

    if (event.messageType == 0xB0) {
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
    // Update state to trigger rebuilds only for listeners of this provider
    state = _logs.toList();
  }

  void clear() {
    _logs.clear();
    state = [];
  }
}

final diagnosticsProvider = NotifierProvider.autoDispose<DiagnosticsLoggerNotifier, List<String>>(DiagnosticsLoggerNotifier.new);

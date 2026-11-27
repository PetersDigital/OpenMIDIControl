// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import '../../models/midi_event.dart';
import '../../router/nodes/sink_node.dart';
import 'mcu_codec.dart';

/// Decodes feedback from one port generation and one UMP group.
final class McuProtocolNode extends SinkNode {
  McuProtocolNode({
    required this.sourceId,
    required this.group,
    required this.onFeedback,
    required this.onGenericEvents,
  });

  final String sourceId;
  final int group;
  final void Function(McuFeedback) onFeedback;
  final void Function(List<MidiEvent>) onGenericEvents;

  @override
  void execute(List<MidiEvent> events) {
    List<MidiEvent>? genericEvents;
    for (final event in events) {
      final feedback = event.sourceId == sourceId && event.group == group
          ? McuCodec.decode(event)
          : null;
      if (feedback != null) {
        onFeedback(feedback);
      } else {
        (genericEvents ??= []).add(event);
      }
    }
    if (genericEvents != null) onGenericEvents(genericEvents);
  }
}

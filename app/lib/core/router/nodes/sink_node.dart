// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import '../../models/midi_event.dart';
import '../transformer_node.dart';

/// Abstract base class for sink nodes that trigger side effects
/// at the end of a routing branch.
abstract class SinkNode extends TransformerNode {
  /// Defines the side effect to be executed when events reach this sink.
  void execute(List<MidiEvent> events);

  /// Single event fast-path fallback. Subclasses can override this to avoid list allocation.
  void executeSingle(MidiEvent event) {
    execute([event]);
  }

  @override
  MidiEvent? processSingle(MidiEvent event) {
    executeSingle(event);
    return null;
  }

  @override
  List<MidiEvent> process(List<MidiEvent> events) {
    if (events.isNotEmpty) {
      execute(events);
    }
    // Sinks are terminal; they return an empty list to stop traversal.
    return const [];
  }
}

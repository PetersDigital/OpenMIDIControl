// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
// Utility class to check MIDI support at runtime
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MidiSupportChecker {
  static const MethodChannel _channel = MethodChannel(
    'com.petersdigital.openmidicontrol/midi',
  );

  static Future<bool> isMidiSupported() async {
    try {
      final bool? result = await _channel.invokeMethod('isMidiSupported');
      return result ?? false;
    } catch (e) {
      // If the method isn't implemented (older version), assume true for safety
      // but log the issue for debugging
      debugPrint('MIDI support check failed: $e');
      return true; // Assume supported to avoid breaking existing functionality
    }
  }

  static Stream<bool> midiSupportStream() async* {
    // Initial check
    bool isSupported = await isMidiSupported();
    yield isSupported;

    // Note: We don't have a real-time stream for MIDI support changes
    // as it's generally a static device property
    // But we could re-check periodically if needed
  }
}

final midiSupportProvider = FutureProvider<bool>((ref) async {
  return await MidiSupportChecker.isMidiSupported();
});

final midiSupportStreamProvider = StreamProvider<bool>((ref) {
  return MidiSupportChecker.midiSupportStream().asBroadcastStream();
});

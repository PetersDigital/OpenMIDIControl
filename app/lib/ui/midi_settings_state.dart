// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/protocol/mcu/mcu_codec.dart';
import 'midi_service.dart';

enum MidiProtocolMode { generic, mcu }

final midiProtocolModeProvider =
    AsyncNotifierProvider<MidiProtocolModeNotifier, MidiProtocolMode>(
      MidiProtocolModeNotifier.new,
    );

class MidiProtocolModeNotifier extends AsyncNotifier<MidiProtocolMode> {
  static const storageKey = 'midi_protocol_mode_v1';
  Future<void> _writes = Future<void>.value();

  @override
  Future<MidiProtocolMode> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.get(storageKey) == MidiProtocolMode.mcu.name && ref.mounted) {
        await ref.read(midiServiceProvider).setMcuMode(true);
        return MidiProtocolMode.mcu;
      }
    } on Exception {
      // A missing or unreadable preference defaults to Generic MIDI.
    }
    return MidiProtocolMode.generic;
  }

  Future<void> setMode(MidiProtocolMode mode) {
    final write = _writes.then((_) async {
      if (await future == mode || !ref.mounted) return;
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      if (!await prefs.setString(storageKey, mode.name)) {
        throw StateError('Failed to save the MIDI protocol mode.');
      }
      if (!ref.mounted) return;
      final applyMode = ref
          .read(midiServiceProvider)
          .setMcuMode(mode == MidiProtocolMode.mcu);
      state = AsyncData(mode);
      await applyMode;
    });
    _writes = write.catchError((Object _) {});
    return write;
  }
}

final mcuRouteActiveProvider = StreamProvider.autoDispose<bool>((ref) {
  return ref.watch(midiServiceProvider).mcuRouteChanges;
});

final mcuLampProvider = StreamProvider.autoDispose.family<McuLampState?, int>((
  ref,
  note,
) {
  final service = ref.watch(midiServiceProvider);
  return Stream.multi((listener) {
    final subscription = service.mcuFeedback.listen((event) {
      if (event case McuLampFeedback(
        note: final address,
        :final state,
      ) when address == note) {
        listener.addSync(state);
      }
    }, onDone: listener.closeSync);
    final routes = service.mcuRouteChanges.listen((active) {
      if (!active) listener.addSync(null);
    });
    listener.onCancel = () async {
      await subscription.cancel();
      await routes.cancel();
    };
    listener.addSync(service.mcuLampState(note));
  });
});

// ---------------------------------------------------------------------------
// State: USB Peripheral/Host Mode
// ---------------------------------------------------------------------------
enum UsbMode { peripheral, host }

class UsbModeNotifier extends Notifier<UsbMode> {
  @override
  UsbMode build() => UsbMode.peripheral;

  void updateMode(UsbMode mode) {
    state = mode;
    // Tell native layer to update peripheral service state
    ref.read(midiServiceProvider).setUsbMode(mode.name);
  }
}

final usbModeProvider = NotifierProvider<UsbModeNotifier, UsbMode>(
  UsbModeNotifier.new,
);

// ---------------------------------------------------------------------------
// State: Manual Port Selection (Hide/Show PeterDigital ports)
// ---------------------------------------------------------------------------
class ManualPortSelectionNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final manualPortSelectionProvider =
    NotifierProvider<ManualPortSelectionNotifier, bool>(
      ManualPortSelectionNotifier.new,
    );

// ---------------------------------------------------------------------------
// State: Safety Hold Duration (seconds)
// ---------------------------------------------------------------------------
class SafetyHoldDurationNotifier extends Notifier<double> {
  @override
  double build() => 1.0;

  void update(double value) => state = value;
}

final safetyHoldDurationProvider =
    NotifierProvider<SafetyHoldDurationNotifier, double>(
      SafetyHoldDurationNotifier.new,
    );

// ---------------------------------------------------------------------------
// State: Config Interaction Mode
// ---------------------------------------------------------------------------
enum ConfigGestureMode {
  tapHold, // Tap then Hold
  doubleTapHold, // Tap, Tap then Hold
}

class ConfigGestureModeNotifier extends Notifier<ConfigGestureMode> {
  @override
  ConfigGestureMode build() => ConfigGestureMode.doubleTapHold;

  void update(ConfigGestureMode mode) => state = mode;
}

final configGestureModeProvider =
    NotifierProvider<ConfigGestureModeNotifier, ConfigGestureMode>(
      ConfigGestureModeNotifier.new,
    );

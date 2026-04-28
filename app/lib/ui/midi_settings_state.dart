// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'midi_service.dart';

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

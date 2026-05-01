// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import '../../ui/layout_state.dart' show DrumPadConfig, XYPadConfig;
import 'control_state.dart';

class PresetSnapshot {
  final ControlState controlState;
  final Map<String, DrumPadConfig> drumPadConfigs;
  final Map<String, XYPadConfig> xyPadConfigs;

  PresetSnapshot({
    required this.controlState,
    required this.drumPadConfigs,
    required this.xyPadConfigs,
  });

  Map<String, dynamic> toJson() {
    return {
      'controlState': controlState.toJson(),
      'drumPadConfigs': drumPadConfigs.map((k, v) => MapEntry(k, v.toJson())),
      'xyPadConfigs': xyPadConfigs.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  factory PresetSnapshot.fromJson(Map<String, dynamic> json) {
    return PresetSnapshot(
      controlState: ControlState.fromJson(
        json['controlState'] as Map<String, dynamic>,
      ),
      drumPadConfigs:
          (json['drumPadConfigs'] as Map<String, dynamic>?)?.map(
            (k, v) =>
                MapEntry(k, DrumPadConfig.fromJson(v as Map<String, dynamic>)),
          ) ??
          {},
      xyPadConfigs:
          (json['xyPadConfigs'] as Map<String, dynamic>?)?.map(
            (k, v) =>
                MapEntry(k, XYPadConfig.fromJson(v as Map<String, dynamic>)),
          ) ??
          {},
    );
  }
}

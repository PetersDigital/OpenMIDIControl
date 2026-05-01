// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'control_state.dart';

class PresetSnapshot {
  final ControlState controlState;

  PresetSnapshot({
    required this.controlState,
  });

  Map<String, dynamic> toJson() {
    return {
      'controlState': controlState.toJson(),
    };
  }

  factory PresetSnapshot.fromJson(Map<String, dynamic> json) {
    return PresetSnapshot(
      controlState: ControlState.fromJson(
        json['controlState'] as Map<String, dynamic>,
      ),
    );
  }
}

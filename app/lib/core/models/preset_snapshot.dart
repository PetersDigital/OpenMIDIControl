// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'control_state.dart';
import 'layout_models.dart';

class PresetSnapshot {
  final ControlState controlState;
  final List<LayoutPage> pages;

  PresetSnapshot({required this.controlState, required this.pages});

  Map<String, dynamic> toJson() {
    return {
      'controlState': controlState.toJson(),
      'pages': pages.map((p) => p.toJson()).toList(),
    };
  }

  factory PresetSnapshot.fromJson(Map<String, dynamic> json) {
    return PresetSnapshot(
      controlState: ControlState.fromJson(
        json['controlState'] as Map<String, dynamic>,
      ),
      pages:
          (json['pages'] as List<dynamic>?)
              ?.map((p) => LayoutPage.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

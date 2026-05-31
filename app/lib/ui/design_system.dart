// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';

/// Centralized design tokens for OpenMIDIControl "The Console" aesthetic.
class AppText {
  static const String performanceFont = 'Space Grotesk';
  static const String systemFont = 'Inter';

  /// Styles for performance-critical labels (Knob values, Pad names, Fader CCs, etc.)
  static TextStyle performance({
    double? fontSize,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: performanceFont,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// Styles for instructional or system UI (Settings, Dialogs, Metadata)
  static TextStyle system({
    double? fontSize,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: systemFont,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }
}

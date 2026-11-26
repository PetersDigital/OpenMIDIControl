// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

/// A named high-contrast accent swatch aligned with the Console palette.
class WidgetPaletteSwatch {
  final String name;
  final String hex;
  final int colorValue;

  const WidgetPaletteSwatch({
    required this.name,
    required this.hex,
    required this.colorValue,
  });
}

/// Immutable per-widget visual customization attached to a control.
class WidgetStyle {
  static const List<String> supportedFonts = [
    'Inter',
    'Space Grotesk',
    'DSEG7Modern',
  ];

  static const List<WidgetPaletteSwatch> curatedPalette = [
    WidgetPaletteSwatch(
      name: 'Ice Blue',
      hex: '#A6C9F8',
      colorValue: 0xFFA6C9F8,
    ),
    WidgetPaletteSwatch(
      name: 'Mint Teal',
      hex: '#A1CFCE',
      colorValue: 0xFFA1CFCE,
    ),
    WidgetPaletteSwatch(
      name: 'Warm Amber',
      hex: '#E9C46A',
      colorValue: 0xFFE9C46A,
    ),
    WidgetPaletteSwatch(
      name: 'Coral Peach',
      hex: '#FFB59E',
      colorValue: 0xFFFFB59E,
    ),
    WidgetPaletteSwatch(
      name: 'Studio Cyan',
      hex: '#80CBC4',
      colorValue: 0xFF80CBC4,
    ),
    WidgetPaletteSwatch(
      name: 'Signal Green',
      hex: '#81C784',
      colorValue: 0xFF81C784,
    ),
    WidgetPaletteSwatch(
      name: 'Synth Violet',
      hex: '#CE93D8',
      colorValue: 0xFFCE93D8,
    ),
    WidgetPaletteSwatch(
      name: 'Rose Pink',
      hex: '#F48FB1',
      colorValue: 0xFFF48FB1,
    ),
    WidgetPaletteSwatch(
      name: 'Tangerine',
      hex: '#FF8A65',
      colorValue: 0xFFFF8A65,
    ),
    WidgetPaletteSwatch(
      name: 'Record Red',
      hex: '#EF5350',
      colorValue: 0xFFEF5350,
    ),
    WidgetPaletteSwatch(
      name: 'Solar Gold',
      hex: '#FFD54F',
      colorValue: 0xFFFFD54F,
    ),
    WidgetPaletteSwatch(
      name: 'Console Silver',
      hex: '#E0E3E7',
      colorValue: 0xFFE0E3E7,
    ),
  ];

  static final RegExp _hexPattern = RegExp(r'^#?[0-9A-Fa-f]{6}$');

  static const WidgetStyle defaults = WidgetStyle();

  final String? accentColorHex;
  final String? fontFamily;
  final bool showLabel;
  final bool showNumericReadout;

  const WidgetStyle({
    this.accentColorHex,
    this.fontFamily,
    this.showLabel = true,
    this.showNumericReadout = true,
  });

  /// Returns an ARGB integer (`0xFFRRGGBB`) for [accentColorHex], or `null`.
  int? get accentColorValue {
    final hex = accentColorHex;
    if (hex == null) return null;
    final digits = hex.startsWith('#') ? hex.substring(1) : hex;
    return int.parse('FF$digits', radix: 16);
  }

  /// True when all fields match factory visual defaults.
  bool get isDefault =>
      accentColorHex == null &&
      fontFamily == null &&
      showLabel &&
      showNumericReadout;

  /// Normalizes a 6-digit RGB hex color string into `#RRGGBB`.
  static String? normalizeHex(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    if (!_hexPattern.hasMatch(trimmed)) {
      throw FormatException('Invalid hex color: $raw');
    }
    final upper = trimmed.toUpperCase();
    return upper.startsWith('#') ? upper : '#$upper';
  }

  /// Validates that [raw] is one of [supportedFonts] (or null/empty).
  static String? validateFontFamily(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    for (final font in supportedFonts) {
      if (font == trimmed) return font;
    }
    throw FormatException('Unsupported font family: $raw');
  }

  WidgetStyle copyWith({
    String? accentColorHex,
    bool clearAccentColor = false,
    String? fontFamily,
    bool clearFontFamily = false,
    bool? showLabel,
    bool? showNumericReadout,
  }) {
    return WidgetStyle(
      accentColorHex: clearAccentColor
          ? null
          : normalizeHex(accentColorHex ?? this.accentColorHex),
      fontFamily: clearFontFamily
          ? null
          : validateFontFamily(fontFamily ?? this.fontFamily),
      showLabel: showLabel ?? this.showLabel,
      showNumericReadout: showNumericReadout ?? this.showNumericReadout,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (accentColorHex != null) 'accentColorHex': accentColorHex,
      if (fontFamily != null) 'fontFamily': fontFamily,
      if (!showLabel) 'showLabel': false,
      if (!showNumericReadout) 'showNumericReadout': false,
    };
  }

  factory WidgetStyle.fromJson(Map<String, dynamic> json) {
    final rawHex = json['accentColorHex'];
    if (rawHex != null && rawHex is! String) {
      throw const FormatException('accentColorHex must be a string.');
    }
    final rawFont = json['fontFamily'];
    if (rawFont != null && rawFont is! String) {
      throw const FormatException('fontFamily must be a string.');
    }
    final showLabel = json['showLabel'];
    if (showLabel != null && showLabel is! bool) {
      throw const FormatException('showLabel must be a boolean.');
    }
    final showNumericReadout = json['showNumericReadout'];
    if (showNumericReadout != null && showNumericReadout is! bool) {
      throw const FormatException('showNumericReadout must be a boolean.');
    }
    return WidgetStyle(
      accentColorHex: normalizeHex(rawHex as String?),
      fontFamily: validateFontFamily(rawFont as String?),
      showLabel: showLabel as bool? ?? true,
      showNumericReadout: showNumericReadout as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WidgetStyle &&
        other.accentColorHex == accentColorHex &&
        other.fontFamily == fontFamily &&
        other.showLabel == showLabel &&
        other.showNumericReadout == showNumericReadout;
  }

  @override
  int get hashCode =>
      Object.hash(accentColorHex, fontFamily, showLabel, showNumericReadout);

  @override
  String toString() =>
      'WidgetStyle(accentColorHex: $accentColorHex, fontFamily: $fontFamily, showLabel: $showLabel, showNumericReadout: $showNumericReadout)';
}

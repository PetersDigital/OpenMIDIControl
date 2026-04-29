// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

/// Enumeration of supported control types in the layout schema.
enum ControlType { fader, xyPad, drumPad, encoder, trigger, toggle }

/// Represents a single control within a layout page.
///
/// Fields:
/// - [id]: Unique identifier for the control (e.g., "fader_0", "drum_pad_1")
/// - [type]: The type of control (fader, xyPad, drumPad, encoder, button)
/// - [defaultCc]: Default MIDI CC number (1-127)
/// - [channel]: MIDI channel (0-15, where 9 is typically drums)
/// - [customName]: Optional custom display name; if empty/null, uses "CC $defaultCc"
class LayoutControl {
  final String id;
  final ControlType type;
  final int defaultCc;
  final int channel;
  final String? customName;

  LayoutControl({
    required this.id,
    required this.type,
    required this.defaultCc,
    required this.channel,
    this.customName,
  }) : assert(defaultCc >= 0 && defaultCc <= 127, 'CC must be 0-127'),
       assert(channel >= 0 && channel <= 15, 'Channel must be 0-15');

  /// Display name: uses customName if provided and non-empty, else "CC $defaultCc".
  String get displayName {
    if (customName != null && customName!.trim().isNotEmpty) {
      return customName!;
    }
    return 'CC $defaultCc';
  }

  /// Create a copy with optional field overrides.
  LayoutControl copyWith({
    String? id,
    ControlType? type,
    int? defaultCc,
    int? channel,
    String? customName,
  }) {
    return LayoutControl(
      id: id ?? this.id,
      type: type ?? this.type,
      defaultCc: defaultCc ?? this.defaultCc,
      channel: channel ?? this.channel,
      customName: customName ?? this.customName,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'defaultCc': defaultCc,
      'channel': channel,
      'customName': customName,
    };
  }

  /// Deserialize from JSON.
  factory LayoutControl.fromJson(Map<String, dynamic> json) {
    return LayoutControl(
      id: json['id'] as String,
      type: ControlType.values.byName(json['type'] as String),
      defaultCc: json['defaultCc'] as int,
      channel: json['channel'] as int,
      customName: json['customName'] as String?,
    );
  }

  @override
  String toString() =>
      'LayoutControl(id: $id, type: ${type.name}, cc: $defaultCc, channel: $channel)';
}

/// Represents a single page in the layout (e.g., FADER, XY, PADS, UTILITY).
///
/// Fields:
/// - [id]: Unique identifier (e.g., "page_0", "page_faders")
/// - [name]: Display name (e.g., "FADER", "XY", "PADS", "UTILITY")
/// - [controls]: List of controls on this page
class LayoutPage {
  final String id;
  final String name;
  final List<LayoutControl> controls;

  LayoutPage({required this.id, required this.name, required this.controls});

  /// Create a copy with optional field overrides.
  LayoutPage copyWith({
    String? id,
    String? name,
    List<LayoutControl>? controls,
  }) {
    return LayoutPage(
      id: id ?? this.id,
      name: name ?? this.name,
      controls: controls ?? this.controls,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'controls': controls.map((c) => c.toJson()).toList(),
    };
  }

  /// Deserialize from JSON.
  factory LayoutPage.fromJson(Map<String, dynamic> json) {
    return LayoutPage(
      id: json['id'] as String,
      name: json['name'] as String,
      controls: (json['controls'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(LayoutControl.fromJson)
          .toList(),
    );
  }

  @override
  String toString() =>
      'LayoutPage(id: $id, name: $name, controlCount: ${controls.length})';
}

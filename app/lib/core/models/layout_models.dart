// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:collection/collection.dart';
import '../midi_utils.dart';

/// Enumeration of supported control types in the layout schema.
enum ControlType { fader, xyPad, drumPad, encoder, trigger, toggle }

/// Enumeration of supported page types in the layout schema.
enum PageType { fader, xyPad, drumPad, utility }

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

  /// Secondary MIDI identifier (e.g., CC for Y-axis in XY pads).
  final int? secondaryCc;

  /// Whether to invert the primary value (X-axis for XY pads).
  final bool invertX;

  /// Whether to invert the secondary value (Y-axis for XY pads).
  final bool invertY;

  final int x;
  final int y;
  final int width;
  final int height;

  LayoutControl({
    required this.id,
    required this.type,
    required this.defaultCc,
    required this.channel,
    this.customName,
    this.secondaryCc,
    this.invertX = false,
    this.invertY = false,
    this.x = 0,
    this.y = 0,
    this.width = 1,
    this.height = 1,
  }) : assert(defaultCc >= -1 && defaultCc <= 127, 'CC must be -1 to 127'),
       assert(channel >= -1 && channel <= 15, 'Channel must be -1 to 15');

  /// Display name: uses customName if provided and non-empty, else "CC $defaultCc".
  /// For drum pads, uses the note name (e.g., "C1").
  String get displayName {
    if (customName != null && customName!.trim().isNotEmpty) {
      return customName!;
    }
    if (defaultCc == -1) {
      return 'UNASSIGNED';
    }
    if (type == ControlType.drumPad) {
      return MidiUtils.getNoteName(defaultCc);
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
    int? secondaryCc,
    bool? invertX,
    bool? invertY,
    int? x,
    int? y,
    int? width,
    int? height,
  }) {
    return LayoutControl(
      id: id ?? this.id,
      type: type ?? this.type,
      defaultCc: defaultCc ?? this.defaultCc,
      channel: channel ?? this.channel,
      customName: customName ?? this.customName,
      secondaryCc: secondaryCc ?? this.secondaryCc,
      invertX: invertX ?? this.invertX,
      invertY: invertY ?? this.invertY,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
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
      'secondaryCc': secondaryCc,
      'invertX': invertX,
      'invertY': invertY,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
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
      secondaryCc: json['secondaryCc'] as int?,
      invertX: json['invertX'] as bool? ?? false,
      invertY: json['invertY'] as bool? ?? false,
      x: json['x'] as int? ?? 0,
      y: json['y'] as int? ?? 0,
      width: json['width'] as int? ?? 1,
      height: json['height'] as int? ?? 1,
    );
  }

  @override
  String toString() =>
      'LayoutControl(id: $id, type: ${type.name}, cc: $defaultCc, channel: $channel, secondaryCc: $secondaryCc, invertX: $invertX, invertY: $invertY, x: $x, y: $y, width: $width, height: $height)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LayoutControl &&
        other.id == id &&
        other.type == type &&
        other.defaultCc == defaultCc &&
        other.channel == channel &&
        other.customName == customName &&
        other.secondaryCc == secondaryCc &&
        other.invertX == invertX &&
        other.invertY == invertY &&
        other.x == x &&
        other.y == y &&
        other.width == width &&
        other.height == height;
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    defaultCc,
    channel,
    customName,
    secondaryCc,
    invertX,
    invertY,
    x,
    y,
    width,
    height,
  );
}

/// Represents a single page in the layout (e.g., FADER, XY, PADS, UTILITY).
///
/// Fields:
/// - [id]: Unique identifier (e.g., "page_0", "page_faders")
/// - [type]: The type of the page (e.g., fader, xyPad, drumPad, utility)
/// - [name]: Display name (e.g., "FADER", "XY", "PADS", "UTILITY")
/// - [controls]: List of controls on this page
class LayoutPage {
  final String id;
  final PageType type;
  final String name;
  final List<LayoutControl> controls;
  final int gridColumns;
  final int gridRows;

  LayoutPage({
    required this.id,
    required this.type,
    required this.name,
    required this.controls,
    this.gridColumns = 8,
    this.gridRows = 4,
  });

  /// Create a copy with optional field overrides.
  LayoutPage copyWith({
    String? id,
    PageType? type,
    String? name,
    List<LayoutControl>? controls,
    int? gridColumns,
    int? gridRows,
  }) {
    return LayoutPage(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      controls: controls ?? this.controls,
      gridColumns: gridColumns ?? this.gridColumns,
      gridRows: gridRows ?? this.gridRows,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'name': name,
      'controls': controls.map((c) => c.toJson()).toList(),
      'gridColumns': gridColumns,
      'gridRows': gridRows,
    };
  }

  /// Deserialize from JSON.
  factory LayoutPage.fromJson(Map<String, dynamic> json) {
    return LayoutPage(
      id: json['id'] as String,
      type:
          PageType.values.firstWhereOrNull((e) => e.name == json['type']) ??
          PageType.utility,
      name: json['name'] as String,
      controls: (json['controls'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(LayoutControl.fromJson)
          .toList(),
      gridColumns: json['gridColumns'] as int? ?? 8,
      gridRows: json['gridRows'] as int? ?? 4,
    );
  }

  @override
  String toString() =>
      'LayoutPage(id: $id, type: ${type.name}, name: $name, controlCount: ${controls.length}, grid: ${gridColumns}x$gridRows)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LayoutPage &&
        other.id == id &&
        other.type == type &&
        other.name == name &&
        other.gridColumns == gridColumns &&
        other.gridRows == gridRows &&
        const ListEquality().equals(other.controls, controls);
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    name,
    gridColumns,
    gridRows,
    const ListEquality().hash(controls),
  );
}

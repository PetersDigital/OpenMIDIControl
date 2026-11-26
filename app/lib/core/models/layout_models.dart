// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:collection/collection.dart';

import '../midi_utils.dart';
import 'action_payload.dart';

/// Enumeration of supported control types in the layout schema.
enum ControlType { fader, xyPad, drumPad, encoder, trigger, toggle }

/// Enumeration of supported page types in the layout schema.
enum PageType { fader, xyPad, drumPad, utility }

/// Represents a single control within a layout page.
///
/// Fields:
/// - [id]: Unique identifier for the control (e.g., "fader_0", "drum_pad_1")
/// - [type]: The type of control (fader, xyPad, drumPad, encoder, button)
/// - [defaultCc]: Legacy CC or note number (0-127, or -1 if unassigned)
/// - [channel]: MIDI channel (0-15, where 9 is typically drums)
/// - [customName]: Optional custom display name; if empty/null, uses "CC $defaultCc"
class LayoutControl {
  static const defaultXySecondaryCc = 11;

  final String id;
  final ControlType type;
  final int defaultCc;
  final int channel;
  final String? customName;

  /// Secondary MIDI identifier (e.g., CC for Y-axis in XY pads).
  final int? secondaryCc;

  final ActionPayload? payload;

  /// Action assignment for the Y-axis of an XY pad.
  final ActionPayload? secondaryPayload;

  /// Resolves the implicit CC assignment used by older XY pads with no Y ID.
  ///
  /// Reading this leaves the stored assignment and legacy fields intact.
  ActionPayload? get effectiveSecondaryPayload {
    if (secondaryPayload != null) return secondaryPayload;
    if (type != ControlType.xyPad || secondaryCc != null) return null;
    return _legacyPayload(type, channel, defaultXySecondaryCc);
  }

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
    ActionPayload? payload,
    ActionPayload? secondaryPayload,
    this.invertX = false,
    this.invertY = false,
    this.x = 0,
    this.y = 0,
    this.width = 1,
    this.height = 1,
  }) : assert(defaultCc >= -1 && defaultCc <= 127, 'CC must be -1 to 127'),
       assert(channel >= -1 && channel <= 15, 'Channel must be -1 to 15'),
       payload = payload ?? _legacyPayload(type, channel, defaultCc),
       secondaryPayload =
           secondaryPayload ??
           (type == ControlType.xyPad
               ? _legacyPayload(type, channel, secondaryCc)
               : null);

  static ActionPayload? _legacyPayload(
    ControlType type,
    int channel,
    int? identifier,
  ) {
    if (identifier == null ||
        identifier < 0 ||
        identifier > 127 ||
        channel < 0 ||
        channel > 15) {
      return null;
    }
    if (type == ControlType.drumPad) {
      return NotePayload(
        channel: channel,
        note: identifier,
        velocityMode: NoteVelocityMode.touchPosition,
        velocityCurve: NoteVelocityCurve.drumPad,
      );
    }
    return CcPayload(channel: channel, cc: identifier);
  }

  /// Display name: uses customName if provided and non-empty, else "CC $defaultCc".
  /// For drum pads, uses the note name (e.g., "C1").
  String get displayName {
    if (customName != null && customName!.trim().isNotEmpty) {
      return customName!;
    }
    if (payload case final action?) return action.displayLabel;
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
    ActionPayload? payload,
    ActionPayload? secondaryPayload,
    bool? invertX,
    bool? invertY,
    int? x,
    int? y,
    int? width,
    int? height,
  }) {
    final controlType = type ?? this.type;
    final midiChannel = channel ?? this.channel;
    final primaryCc = defaultCc ?? this.defaultCc;
    final axisCc = secondaryCc ?? this.secondaryCc;
    final mappingChanged =
        controlType != this.type || midiChannel != this.channel;

    return LayoutControl(
      id: id ?? this.id,
      type: controlType,
      defaultCc: primaryCc,
      channel: midiChannel,
      customName: customName ?? this.customName,
      secondaryCc: axisCc,
      // Legacy assignment edits replace the payload for the affected axis.
      payload:
          payload ??
          (mappingChanged || primaryCc != this.defaultCc ? null : this.payload),
      secondaryPayload:
          secondaryPayload ??
          (mappingChanged || axisCc != this.secondaryCc
              ? null
              : this.secondaryPayload),
      invertX: invertX ?? this.invertX,
      invertY: invertY ?? this.invertY,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  /// Replaces the primary assignment and optionally edits the XY Y-axis.
  ///
  /// A null [payload] clears the primary assignment. Omit [secondaryPayload]
  /// to retain the Y-axis assignment, or pass [clearSecondary] to clear it.
  LayoutControl withActions({
    required ActionPayload? payload,
    ActionPayload? secondaryPayload,
    bool clearSecondary = false,
    String? customName,
    bool? invertX,
    bool? invertY,
  }) {
    assert(!clearSecondary || secondaryPayload == null);
    assert(secondaryPayload == null || type == ControlType.xyPad);
    final yAction = clearSecondary
        ? null
        : secondaryPayload ?? effectiveSecondaryPayload;
    return LayoutControl(
      id: id,
      type: type,
      defaultCc: _legacyIdentifier(payload),
      channel: payload?.midiChannel ?? yAction?.midiChannel ?? -1,
      customName: customName ?? this.customName,
      secondaryCc: type == ControlType.xyPad || clearSecondary
          ? _legacyIdentifier(yAction)
          : secondaryCc,
      payload: payload,
      secondaryPayload: yAction,
      invertX: invertX ?? this.invertX,
      invertY: invertY ?? this.invertY,
      x: x,
      y: y,
      width: width,
      height: height,
    );
  }

  static int _legacyIdentifier(ActionPayload? payload) => switch (payload) {
    CcPayload(:final cc) || RelativeCcPayload(:final cc) => cc,
    NotePayload(:final note) => note,
    _ => -1,
  };

  /// Serialize to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'defaultCc': defaultCc,
      'channel': channel,
      'customName': customName,
      'secondaryCc': secondaryCc,
      if (payload != null) 'payload': payload!.toJson(),
      if (secondaryPayload != null)
        'secondaryPayload': secondaryPayload!.toJson(),
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
      payload: _readPayload(json['payload']),
      secondaryPayload: _readPayload(json['secondaryPayload']),
      invertX: json['invertX'] as bool? ?? false,
      invertY: json['invertY'] as bool? ?? false,
      x: json['x'] as int? ?? 0,
      y: json['y'] as int? ?? 0,
      width: json['width'] as int? ?? 1,
      height: json['height'] as int? ?? 1,
    );
  }

  static ActionPayload? _readPayload(Object? json) {
    if (json == null) return null;
    if (json is Map<String, dynamic>) return ActionPayload.fromJson(json);
    throw const FormatException('Action payload must be a JSON object.');
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
        other.payload == payload &&
        other.secondaryPayload == secondaryPayload &&
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
    payload,
    secondaryPayload,
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
          .where((control) => control['type'] != 'transportButton')
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

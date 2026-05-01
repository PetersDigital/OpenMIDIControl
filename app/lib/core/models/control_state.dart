// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:collection/collection.dart';

class ControlState {
  final Map<String, int> ccValues;
  final Map<int, Set<int>> noteStates;
  final Map<String, bool> buttonStates;

  ControlState({
    required Map<String, int> ccValues,
    required Map<int, Set<int>> noteStates,
    required Map<String, bool> buttonStates,
  }) : ccValues = Map.unmodifiable(ccValues),
       noteStates = Map.unmodifiable(
         noteStates.map((k, v) => MapEntry(k, Set.unmodifiable(v))),
       ),
       buttonStates = Map.unmodifiable(buttonStates);

  /// Fast-path constructor that skips defensive copying.
  const ControlState.raw({
    required this.ccValues,
    required this.noteStates,
    required this.buttonStates,
  });

  ControlState copyWith({
    Map<String, int>? ccValues,
    Map<int, Set<int>>? noteStates,
    Map<String, bool>? buttonStates,
  }) {
    return ControlState(
      ccValues: ccValues ?? this.ccValues,
      noteStates: noteStates ?? this.noteStates,
      buttonStates: buttonStates ?? this.buttonStates,
    );
  }

  /// Parses a "channel:id" string into a tuple (channel, id).
  static (int, int) parseAddress(String address) {
    final parts = address.split(':');
    if (parts.length != 2) return (0, 0);
    return (int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
  }

  /// Formats channel and id into "channel:id".
  static String formatAddress(int channel, int id) {
    return '$channel:$id';
  }

  Map<String, dynamic> toJson() {
    return {
      'ccValues': ccValues,
      'noteStates': noteStates.map(
        (k, v) => MapEntry(k.toString(), v.toList()),
      ),
      'buttonStates': buttonStates,
    };
  }

  factory ControlState.fromJson(Map<String, dynamic> json) {
    final ccValuesMap = json['ccValues'] as Map<String, dynamic>? ?? {};
    final noteStatesMap = json['noteStates'] as Map<String, dynamic>? ?? {};
    final buttonStatesMap = json['buttonStates'] as Map<String, dynamic>? ?? {};

    return ControlState(
      ccValues: ccValuesMap.map((k, v) => MapEntry(k, v as int)),
      noteStates: noteStatesMap.map(
        (k, v) => MapEntry(
          int.parse(k),
          (v as List<dynamic>).map((e) => e as int).toSet(),
        ),
      ),
      buttonStates: buttonStatesMap.map((k, v) => MapEntry(k, v as bool)),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ControlState &&
        const DeepCollectionEquality().equals(other.ccValues, ccValues) &&
        const DeepCollectionEquality().equals(other.noteStates, noteStates) &&
        const DeepCollectionEquality().equals(other.buttonStates, buttonStates);
  }

  @override
  int get hashCode => Object.hash(
    const DeepCollectionEquality().hash(ccValues),
    const DeepCollectionEquality().hash(noteStates),
    const DeepCollectionEquality().hash(buttonStates),
  );
}

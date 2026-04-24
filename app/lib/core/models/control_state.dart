// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'dart:collection';

class ControlState {
  final Map<int, int> ccValues;
  // Ready for v0.3.0:
  // final Map<int, bool> buttonStates;

  ControlState({required Map<int, int> ccValues})
    : ccValues = Map.unmodifiable(ccValues);

  /// Fast-path constructor that skips defensive copying.
  const ControlState.raw({required this.ccValues});

  ControlState copyWith({Map<int, int>? ccValues}) {
    if (ccValues == null) return ControlState.raw(ccValues: this.ccValues);
    return ControlState(ccValues: ccValues);
  }

  ControlState copyWithCC(int cc, int val) {
    if (ccValues[cc] == val) return this;
    final newValues = Map<int, int>.of(ccValues);
    newValues[cc] = val;
    return ControlState.raw(ccValues: UnmodifiableMapView(newValues));
  }
}

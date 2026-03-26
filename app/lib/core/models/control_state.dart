class ControlState {
  final Map<int, int> ccValues;
  // Ready for v0.3.0:
  // final Map<int, bool> buttonStates;

  ControlState({required this.ccValues});

  ControlState copyWith({
    Map<int, int>? ccValues,
  }) {
    return ControlState(
      ccValues: ccValues ?? this.ccValues,
    );
  }

  ControlState copyWithCC(int cc, int val) {
    final newValues = Map<int, int>.from(ccValues);
    newValues[cc] = val;
    return ControlState(ccValues: newValues);
  }
}

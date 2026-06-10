// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_riverpod/flutter_riverpod.dart';

class EditorModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }
}

final editorModeProvider = NotifierProvider<EditorModeNotifier, bool>(() {
  return EditorModeNotifier();
});

class SelectedControlNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? controlId) {
    state = controlId;
  }
}

final selectedControlProvider =
    NotifierProvider<SelectedControlNotifier, String?>(() {
      return SelectedControlNotifier();
    });

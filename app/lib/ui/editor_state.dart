// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum EditorOverlay { none, palette, pageSettings }

class EditorOverlayNotifier extends Notifier<EditorOverlay> {
  @override
  EditorOverlay build() => EditorOverlay.none;

  void toggle(EditorOverlay overlay) {
    if (state == overlay) {
      state = EditorOverlay.none;
    } else {
      state = overlay;
    }
  }

  void hide() {
    state = EditorOverlay.none;
  }
}

final editorOverlayProvider =
    NotifierProvider<EditorOverlayNotifier, EditorOverlay>(
      () => EditorOverlayNotifier(),
    );

class EditorModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
    if (!state) {
      ref.read(editorOverlayProvider.notifier).hide();
    }
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

// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SidePanelType { none, appSettings, midiSettings }

enum SidePanelSide { left, right }

class SidePanelState {
  final SidePanelType type;
  final SidePanelSide side;

  const SidePanelState({
    this.type = SidePanelType.none,
    this.side = SidePanelSide.right,
  });

  SidePanelState copyWith({SidePanelType? type, SidePanelSide? side}) {
    return SidePanelState(type: type ?? this.type, side: side ?? this.side);
  }
}

class SidePanelNotifier extends Notifier<SidePanelState> {
  @override
  SidePanelState build() => const SidePanelState();

  void show(SidePanelType type) => state = state.copyWith(type: type);
  void hide() => state = state.copyWith(type: SidePanelType.none);
  void setSide(SidePanelSide side) => state = state.copyWith(side: side);

  void toggle(SidePanelType type) {
    if (state.type == type) {
      hide();
    } else {
      show(type);
    }
  }
}

final sidePanelProvider = NotifierProvider<SidePanelNotifier, SidePanelState>(
  SidePanelNotifier.new,
);

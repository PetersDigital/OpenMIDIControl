// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/layout_models.dart';
import '../hybrid_touch_fader.dart';
import 'hybrid_xy_pad.dart';
import '../widgets/velocity_drum_pad.dart';
import '../widgets/endless_encoder.dart';
import '../widgets/midi_buttons.dart';
import '../open_midi_screen.dart'; // For faderBehaviorProvider

class ControlWidgetFactory {
  static Widget buildControl(
    LayoutControl control,
    String pageId,
    bool isActive,
    bool isMobile,
    WidgetRef ref,
  ) {
    final key = ValueKey(control.id);

    switch (control.type) {
      case ControlType.fader:
        final bool isEvenColumn = control.x % 2 == 0;
        return HybridTouchFader(
          key: key,
          controlId: control.id,
          ccNumber: control.defaultCc,
          displayName: control.displayName,
          activeColor: isEvenColumn
              ? const Color(0xFFA6C9F8)
              : const Color(0xFFA1CFCE),
          labelColor: isEvenColumn
              ? const Color(0xFF033258)
              : const Color(0xFF013737),
          initialValue: isEvenColumn ? 1.0 : 64 / 127.0,
          isMobile: isMobile,
          behavior: ref.watch(faderBehaviorProvider),
          isActive: isActive,
        );

      case ControlType.xyPad:
        return Padding(
          key: key,
          padding: const EdgeInsets.all(16),
          child: HybridXYPad(
            id: control.id,
            ccX: control.defaultCc,
            ccY: control.secondaryCc ?? 11,
            isActive: isActive,
          ),
        );

      case ControlType.drumPad:
        // Assuming we map individual drumPad controls to VelocityDrumPad
        // extracting an index from the id if possible, otherwise defaulting to 0
        int index = 0;
        final match = RegExp(r'_(\d+)$').firstMatch(control.id);
        if (match != null) {
          index = int.parse(match.group(1)!);
        }
        return VelocityDrumPad(
          key: key,
          pageId: pageId,
          index: index,
          isActive: isActive,
        );

      case ControlType.encoder:
        return EndlessEncoderWidget(
          key: key,
          cc: control.defaultCc,
          channel: control.channel == -1 ? 0 : control.channel,
        );

      case ControlType.trigger:
        int triggerIndex = 0;
        final triggerMatch = RegExp(r'_(\d+)$').firstMatch(control.id);
        if (triggerMatch != null) {
          triggerIndex = int.parse(triggerMatch.group(1)!);
        }
        return Trigger(
          key: key,
          index: triggerIndex,
          pageId: pageId,
          mode: MidiButtonMode.cc,
        );

      case ControlType.toggle:
        int toggleIndex = 0;
        final toggleMatch = RegExp(r'_(\d+)$').firstMatch(control.id);
        if (toggleMatch != null) {
          toggleIndex = int.parse(toggleMatch.group(1)!);
        }
        return Toggle(
          key: key,
          index: toggleIndex,
          pageId: pageId,
          mode: MidiButtonMode.cc,
        );
    }
  }
}

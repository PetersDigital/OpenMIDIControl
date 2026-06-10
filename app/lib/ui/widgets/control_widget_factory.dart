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
import '../design_system.dart';
import 'control_config_modal.dart';
import 'config_gesture_wrapper.dart';
import '../layout_state.dart';

class ControlWidgetFactory {
  static Widget buildControl(
    BuildContext context,
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
        return VelocityDrumPad(
          key: key,
          pageId: pageId,
          controlId: control.id,
          isActive: isActive,
        );

      case ControlType.encoder:
        final cc = control.defaultCc;
        final isUnassigned = cc == -1;
        final isLocked = ref.watch(
          layoutStateProvider.select((s) => s.isPerformanceLocked),
        );
        return Container(
          key: key,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: const Color(0xFF111318).withValues(alpha: 0.5),
              width: 1.0,
            ),
          ),
          child: Opacity(
            opacity: isUnassigned ? 0.3 : 1.0,
            child: Stack(
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: EndlessEncoderWidget(
                      channel: control.channel == -1 ? 0 : control.channel,
                      cc: isUnassigned ? 0 : cc,
                      showChannelLabel: false,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  child: ConfigGestureWrapper(
                    id: 'encoder_${control.id}',
                    onConfigRequested: isLocked
                        ? null
                        : () => showDialog(
                            context: context,
                            builder: (context) => ControlConfigModal(
                              controlId: control.id,
                              identifierLabel: 'CC Number (0-127)',
                              displayNameLabel: 'Encoder Name',
                            ),
                          ),
                    child: Container(
                      padding: const EdgeInsets.only(
                        top: 4,
                        left: 6,
                        bottom: 20,
                        right: 20,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 64,
                        minHeight: 60,
                      ),
                      alignment: Alignment.topLeft,
                      child: Text(
                        isUnassigned ? 'UNASSIGNED' : 'CC $cc',
                        style: AppText.performance(
                          color: const Color(0xFFC3C7CA).withValues(alpha: 0.3),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                // Display name / Channel at the bottom
                Positioned(
                  bottom: 4,
                  left: 4,
                  right: 4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          control.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            color: const Color(
                              0xFFC3C7CA,
                            ).withValues(alpha: 0.3),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!isUnassigned)
                        Text(
                          'CH${control.channel + 1}',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            color: const Color(
                              0xFFC3C7CA,
                            ).withValues(alpha: 0.3),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      case ControlType.trigger:
        return Trigger(
          key: key,
          controlId: control.id,
          pageId: pageId,
          mode: MidiButtonMode.cc,
        );

      case ControlType.toggle:
        return Toggle(
          key: key,
          controlId: control.id,
          pageId: pageId,
          mode: MidiButtonMode.cc,
        );
    }
  }
}

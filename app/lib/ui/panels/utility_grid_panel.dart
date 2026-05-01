// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/endless_encoder.dart';
import '../widgets/midi_buttons.dart';
import '../widgets/delayed_menu_trigger.dart';
import '../widgets/config_gesture_wrapper.dart';
import '../design_system.dart';
import '../layout_state.dart';
import '../../core/models/layout_models.dart';

class UtilityGridConfig {
  final int channel;
  final int cc;

  const UtilityGridConfig({required this.channel, required this.cc});

  Map<String, dynamic> toJson() => {'channel': channel, 'cc': cc};

  factory UtilityGridConfig.fromJson(Map<String, dynamic> json) {
    return UtilityGridConfig(
      channel: json['channel'] as int,
      cc: json['cc'] as int,
    );
  }

  UtilityGridConfig copyWith({int? channel, int? cc}) {
    return UtilityGridConfig(
      channel: channel ?? this.channel,
      cc: cc ?? this.cc,
    );
  }
}

class UtilityGridConfigManager
    extends Notifier<Map<String, UtilityGridConfig>> {
  @override
  Map<String, UtilityGridConfig> build() => const {};

  void setConfig(String id, UtilityGridConfig config) {
    state = {...state, id: config};
  }

  void removeConfig(String id) {
    final newState = Map<String, UtilityGridConfig>.from(state);
    newState.remove(id);
    state = Map.unmodifiable(newState);
  }

  void setAllConfigs(Map<String, UtilityGridConfig> configs) {
    state = Map.unmodifiable(configs);
  }
}

final utilityGridConfigProvider =
    NotifierProvider<UtilityGridConfigManager, Map<String, UtilityGridConfig>>(
      UtilityGridConfigManager.new,
    );

class UtilityGridPanel extends ConsumerWidget {
  const UtilityGridPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layoutState = ref.watch(layoutStateProvider);
    final controlCount = layoutState.pages.length > 3
        ? layoutState.pages[3].controls.length
        : 0;

    final isLocked = layoutState.isPerformanceLocked;
    final configs = ref.watch(utilityGridConfigProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        const int crossAxisCount = 2;
        final int rows = (controlCount / crossAxisCount).ceil();
        const double mainAxisSpacing = 2.0;
        const double crossAxisSpacing = 2.0;

        final double availableWidth = constraints.maxWidth - crossAxisSpacing;
        final double itemWidth = availableWidth / crossAxisCount;

        final double totalMainAxisSpacing = rows > 1
            ? (rows - 1) * mainAxisSpacing
            : 0.0;
        final double availableHeight =
            constraints.maxHeight - totalMainAxisSpacing;
        final double itemHeight = rows > 0 ? availableHeight / rows : 1.0;
        final double safeItemHeight = itemHeight > 0 ? itemHeight : 1.0;
        final double aspectRatio = itemWidth / safeItemHeight;

        return Stack(
          children: [
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: aspectRatio,
                crossAxisSpacing: crossAxisSpacing,
                mainAxisSpacing: mainAxisSpacing,
              ),
              itemCount: controlCount,
              itemBuilder: (context, index) {
                final control = layoutState.pages[3].controls[index];
                final config = configs[control.id];
                final channel = config?.channel ?? control.channel;
                final cc = config?.cc ?? control.defaultCc;
                final displayName = control.displayName;

                final bool isUnassigned = cc == -1;

                switch (control.type) {
                  case ControlType.encoder:
                    return Opacity(
                      opacity: isUnassigned ? 0.3 : 1.0,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Knob area fills all available height;
                          // CC label overlays the top-left without consuming height
                          Expanded(
                            child: Stack(
                              children: [
                                // Knob — fills the expanded area
                                Center(
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: EndlessEncoderWidget(
                                        key: ValueKey('encoder_$index'),
                                        channel: channel,
                                        cc: isUnassigned ? 0 : cc,
                                        showChannelLabel: false,
                                      ),
                                    ),
                                  ),
                                ),
                                // CC number — overlaid top-left, ONLY this triggers config
                                Positioned(
                                  top: 0,
                                  left: 0,
                                  child: ConfigGestureWrapper(
                                    key: ValueKey(
                                      'config_wrapper_encoder_${control.id}',
                                    ),
                                    id: 'encoder_${control.id}',
                                    onConfigRequested: isLocked
                                        ? null
                                        : () => showUtilityConfigModal(
                                            context,
                                            ref,
                                            control.id,
                                          ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: 4,
                                        left: 6,
                                        right: 16,
                                        bottom: 8,
                                      ),
                                      child: Text(
                                        isUnassigned ? 'UNASSIGNED' : 'CC $cc',
                                        style: AppText.performance(
                                          color: const Color(
                                            0xFFC3C7CA,
                                          ).withValues(alpha: 0.3),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Bottom row — fixed height, always below the knob
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 2,
                              bottom: 4,
                              left: 4,
                              right: 4,
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Text(
                                  displayName,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    color: const Color(
                                      0xFFC3C7CA,
                                    ).withValues(alpha: 0.3),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (!isUnassigned)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'CH${channel + 1}',
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
                              ],
                            ),
                          ),
                        ],
                      ),
                    );

                  case ControlType.toggle:
                    return Toggle(
                      key: ValueKey('toggle_$index'),
                      index: index,
                      mode: MidiButtonMode.cc,
                    );

                  case ControlType.trigger:
                    return Trigger(
                      key: ValueKey('trigger_$index'),
                      index: index,
                      mode: MidiButtonMode.cc,
                    );

                  default:
                    return const SizedBox.shrink();
                }
              },
            ),

            // Settings icon — top-right, overlaid on grid
            if (!isLocked)
              Positioned(
                top: 8,
                right: 8,
                child: Builder(
                  builder: (menuContext) => DelayedMenuTrigger(
                    id: 'utility_grid_settings',
                    onTrigger: () => _showUtilityPresetMenu(menuContext, ref),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.settings_outlined,
                        color: Colors.white24,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showUtilityPresetMenu(BuildContext context, WidgetRef ref) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF1E2024),
      items: [
        const PopupMenuItem(
          value: 'reset',
          child: Text(
            'Reset All Assignments',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ).then((choice) {
      if (choice == 'reset') {
        ref.read(utilityGridConfigProvider.notifier).setAllConfigs({});
      }
    });
  }
}

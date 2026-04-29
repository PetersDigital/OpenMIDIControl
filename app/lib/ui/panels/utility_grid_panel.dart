// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/endless_encoder.dart';
import '../design_system.dart';
import '../widgets/midi_buttons.dart';
import '../widgets/control_config_modal.dart';
import '../widgets/delayed_menu_trigger.dart';
import '../widgets/config_gesture_wrapper.dart';
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

  Future<void> _showConfigModal(
    BuildContext context,
    WidgetRef ref,
    String id,
    int currentChannel,
    int currentCc,
    String currentName,
  ) async {
    final result = await showDialog<ControlConfigResult>(
      context: context,
      builder: (context) => ControlConfigModal(
        initialChannel: currentChannel,
        initialIdentifier: currentCc,
        identifierLabel: 'CC Number',
        initialDisplayName: currentName,
        displayNameLabel: 'Control Name',
      ),
    );

    if (result != null) {
      final trimmedName = (result.displayName ?? '').trim();
      ref
          .read(utilityGridConfigProvider.notifier)
          .setConfig(
            id,
            UtilityGridConfig(channel: result.channel, cc: result.identifier),
          );

      if (trimmedName.isNotEmpty) {
        ref
            .read(layoutStateProvider.notifier)
            .updateControlLabel(id, trimmedName);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layoutState = ref.watch(layoutStateProvider);
    final configs = ref.watch(utilityGridConfigProvider);

    // Get UTILITY page (index 3)
    final utilityControls = layoutState.pages.length > 3
        ? layoutState.pages[3].controls
        : <LayoutControl>[];

    return LayoutBuilder(
      builder: (context, constraints) {
        final padWidth = constraints.maxWidth / 2;
        final padHeight = constraints.maxHeight / 4;
        final aspectRatio = padWidth / padHeight;

        Widget buildEncoderFromControl(LayoutControl control) {
          final id = control.id;
          final config = configs[id];
          final channel = config?.channel ?? control.channel;
          final cc = config?.cc ?? control.defaultCc;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 4,
                    right: 4,
                    top: 4,
                    bottom: 0,
                  ),
                  child: EndlessEncoderWidget(channel: channel, cc: cc),
                ),
              ),
              ConfigGestureWrapper(
                key: ValueKey('config_wrapper_$id'),
                id: id,
                onConfigRequested: () => _showConfigModal(
                  context,
                  ref,
                  id,
                  channel,
                  cc,
                  control.displayName,
                ),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 80),
                  padding: const EdgeInsets.only(
                    top: 2,
                    bottom: 16,
                    left: 4,
                    right: 4,
                  ),
                  color: Colors.transparent, // Hit target expansion
                  child: Text(
                    '${control.displayName} | CC $cc',
                    textAlign: TextAlign.center,
                    style: AppText.performance(
                      color: const Color(0xFFC3C7CA),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        Widget buildButtonFromControl(LayoutControl control) {
          final id = control.id;
          final config = configs[id];
          final channel = config?.channel ?? control.channel;
          final cc = config?.cc ?? control.defaultCc;

          return MomentaryButton(
            identifier: cc,
            channel: channel,
            mode: MidiButtonMode.cc,
            label: control.displayName,
            onConfigRequested: () => _showConfigModal(
              context,
              ref,
              id,
              channel,
              cc,
              control.displayName,
            ),
          );
        }

        return Stack(
          children: [
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8.0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: aspectRatio,
                crossAxisSpacing: 2.0,
                mainAxisSpacing: 2.0,
              ),
              itemCount: utilityControls.length,
              itemBuilder: (context, index) {
                final control = utilityControls[index];
                if (control.type == ControlType.encoder) {
                  return buildEncoderFromControl(control);
                } else {
                  return buildButtonFromControl(control);
                }
              },
            ),

            // Utility Settings/Presets
            if (!layoutState.isPerformanceLocked)
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
            'Reset to Factory CCs',
            style: TextStyle(color: Colors.white),
          ),
        ),
        const PopupMenuItem(
          value: 'clear',
          child: Text(
            'Clear All Assignments',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      ],
    ).then((choice) {
      if (choice == 'reset' || choice == 'clear') {
        ref.read(utilityGridConfigProvider.notifier).setAllConfigs({});
      }
    });
  }
}

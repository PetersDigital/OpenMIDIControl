// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/endless_encoder.dart';
import '../widgets/midi_buttons.dart';
import '../widgets/control_config_modal.dart';
import '../widgets/delayed_menu_trigger.dart';

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
  ) async {
    final result = await showDialog<ControlConfigResult>(
      context: context,
      builder: (context) => ControlConfigModal(
        initialChannel: currentChannel,
        initialIdentifier: currentCc,
        identifierLabel: 'CC Number',
      ),
    );

    if (result != null) {
      ref
          .read(utilityGridConfigProvider.notifier)
          .setConfig(
            id,
            UtilityGridConfig(channel: result.channel, cc: result.identifier),
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = ref.watch(utilityGridConfigProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final padWidth = constraints.maxWidth / 2;
        final padHeight = constraints.maxHeight / 4;
        final aspectRatio = padWidth / padHeight;

        Widget buildEncoder(int index) {
          final id = 'encoder_$index';
          final defaultCc = 20 + index;
          final config = configs[id];
          final channel = config?.channel ?? 0;
          final cc = config?.cc ?? defaultCc;

          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: EndlessEncoderWidget(
                    channel: channel,
                    cc: cc,
                    onLongPress: () =>
                        _showConfigModal(context, ref, id, channel, cc),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ENC $cc',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFFC3C7CA),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
            ],
          );
        }

        Widget buildToggle(int index) {
          final id = 'toggle_$index';
          final defaultCc = 24 + index;
          final config = configs[id];
          final channel = config?.channel ?? 0;
          final cc = config?.cc ?? defaultCc;

          return ToggleButton(
            identifier: cc,
            channel: channel,
            mode: MidiButtonMode.cc,
            label: 'TOGGLE',
            onLongPress: () => _showConfigModal(context, ref, id, channel, cc),
          );
        }

        Widget buildMomentary(int index) {
          final id = 'momentary_$index';
          final defaultCc = 28 + index;
          final config = configs[id];
          final channel = config?.channel ?? 0;
          final cc = config?.cc ?? defaultCc;

          return MomentaryButton(
            identifier: cc,
            channel: channel,
            mode: MidiButtonMode.cc,
            label: 'MOMENT',
            onLongPress: () => _showConfigModal(context, ref, id, channel, cc),
          );
        }

        return Stack(
          children: [
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: aspectRatio,
                crossAxisSpacing: 2.0,
                mainAxisSpacing: 2.0,
              ),
              itemCount: 8,
              itemBuilder: (context, index) {
                if (index < 2) return buildEncoder(index);
                if (index < 4) return buildToggle(index - 2);
                return buildMomentary(index - 4);
              },
            ),

            // Utility Settings/Presets
            Positioned(
              top: 8,
              right: 8,
              child: Builder(
                builder: (menuContext) => DelayedMenuTrigger(
                  onTrigger: () => _showUtilityPresetMenu(menuContext, ref),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.settings_outlined, color: Colors.white24),
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

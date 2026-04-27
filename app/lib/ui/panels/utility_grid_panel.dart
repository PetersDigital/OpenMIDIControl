// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/endless_encoder.dart';
import '../widgets/midi_buttons.dart';
import '../widgets/control_config_modal.dart';

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

    Widget buildEncoder(int index) {
      final id = 'encoder_$index';
      final defaultCc = 20 + index;
      final config = configs[id];
      final channel = config?.channel ?? 0;
      final cc = config?.cc ?? defaultCc;

      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Expanded(
                child: EndlessEncoderWidget(
                  channel: channel,
                  cc: cc,
                  onLongPress: () =>
                      _showConfigModal(context, ref, id, channel, cc),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'CC $cc',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFFC3C7CA),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildToggle(int index) {
      final id = 'toggle_$index';
      final defaultCc = 24 + index;
      final config = configs[id];
      final channel = config?.channel ?? 0;
      final cc = config?.cc ?? defaultCc;

      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ToggleButton(
            identifier: cc,
            channel: channel,
            mode: MidiButtonMode.cc,
            label: 'TOGGLE\nCC $cc',
            onLongPress: () => _showConfigModal(context, ref, id, channel, cc),
          ),
        ),
      );
    }

    Widget buildMomentary(int index) {
      final id = 'momentary_$index';
      final defaultCc = 28 + index;
      final config = configs[id];
      final channel = config?.channel ?? 0;
      final cc = config?.cc ?? defaultCc;

      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: MomentaryButton(
            identifier: cc,
            channel: channel,
            mode: MidiButtonMode.cc,
            label: 'MOMENT\nCC $cc',
            onLongPress: () => _showConfigModal(context, ref, id, channel, cc),
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Row(
            children: List.generate(4, (index) => buildEncoder(index)),
          ),
        ),
        Expanded(
          child: Row(children: List.generate(4, (index) => buildToggle(index))),
        ),
        Expanded(
          child: Row(
            children: List.generate(4, (index) => buildMomentary(index)),
          ),
        ),
      ],
    );
  }
}

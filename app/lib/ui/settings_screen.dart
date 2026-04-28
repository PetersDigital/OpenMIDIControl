// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:package_info_plus/package_info_plus.dart';

import 'open_midi_screen.dart';
import '../core/managers/snapshot_manager.dart';
import '../core/models/preset_snapshot.dart';
import 'midi_service.dart';
import 'widgets/velocity_drum_pad.dart';
import 'widgets/hybrid_xy_pad.dart';
import 'midi_settings_state.dart';
import 'design_system.dart';

final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentBehavior = ref.watch(faderBehaviorProvider);
    final packageInfoAsync = ref.watch(packageInfoProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        title: Text(
          'Settings',
          style: AppText.system(
            color: const Color(0xFFC3C7CA),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.primaryContainer,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Preset',
            onPressed: () => _handleSavePreset(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Load Preset',
            onPressed: () => _handleLoadPreset(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // App Info Header — centred, compact
          Center(
            child: Column(
              children: [
                const Icon(
                  Icons.settings_input_component,
                  color: Color(0xFFA6C9F8),
                  size: 40,
                ),
                const SizedBox(height: 8),
                Text(
                  'OpenMIDIControl',
                  style: AppText.performance(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                packageInfoAsync.when(
                  data: (info) => Text(
                    'v${info.version}',
                    style: AppText.system(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  loading: () => const SizedBox(height: 14),
                  error: (_, _) => const SizedBox(height: 14),
                ),
                Text(
                  '© PetersDigital',
                  style: AppText.system(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          // Fader Behavior Section
          Text(
            'FADER CONFIGURATION',
            style: AppText.system(
              color: const Color(0xFFC3C7CA),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 8),
          ...FaderBehavior.values.map((behavior) {
            final isSelected = currentBehavior == behavior;
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 0,
              ),
              title: Text(
                behavior.name.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                _getBehaviorDescription(behavior),
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              leading: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 22,
              ),
              onTap: () {
                ref
                    .read(faderBehaviorProvider.notifier)
                    .updateBehavior(behavior);
              },
            );
          }),

          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          // Layout Section
          Text(
            'LAYOUT',
            style: AppText.system(
              color: const Color(0xFFC3C7CA),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 4),
          Builder(
            builder: (ctx) {
              final hand = ref.watch(layoutHandProvider);
              final faderOnRight = hand == LayoutHand.faderOnRight;
              return SwitchListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(
                  faderOnRight ? 'FADER ON RIGHT' : 'FADER ON LEFT',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  faderOnRight
                      ? 'Controls on left — slide faders with right hand.'
                      : 'Controls on right — slide faders with left hand.',
                  style: AppText.system(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                value: faderOnRight,
                activeThumbColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer,
                onChanged: (_) =>
                    ref.read(layoutHandProvider.notifier).toggle(),
              );
            },
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          // Safety Hold Section
          Text(
            'SAFETY HOLD DURATION',
            style: AppText.system(
              color: const Color(0xFFC3C7CA),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, _) {
              final duration = ref.watch(safetyHoldDurationProvider);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${duration.toStringAsFixed(1)} SECONDS',
                        style: AppText.performance(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (duration >= 5.0 || duration <= 1.0)
                        Text(
                          duration >= 5.0 ? 'MAX' : 'MIN',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                    ),
                    child: Slider(
                      value: duration,
                      min: 1.0,
                      max: 5.0,
                      divisions: 40,
                      activeColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      inactiveColor: Colors.white10,
                      onChanged: (val) => ref
                          .read(safetyHoldDurationProvider.notifier)
                          .update(val),
                    ),
                  ),
                  Text(
                    'Adjust the time required to hold a control to enter configuration mode.',
                    style: AppText.system(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          // Configuration Gesture Section
          Text(
            'CONFIGURATION GESTURE',
            style: AppText.system(
              color: const Color(0xFFC3C7CA),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, _) {
              final mode = ref.watch(configGestureModeProvider);
              return Column(
                children: [
                  _buildGestureOption(
                    context,
                    ref,
                    'TAP-THEN-HOLD',
                    'Hold on the second touch',
                    mode == ConfigGestureMode.tapHold,
                    () => ref
                        .read(configGestureModeProvider.notifier)
                        .update(ConfigGestureMode.tapHold),
                  ),
                  const SizedBox(height: 8),
                  _buildGestureOption(
                    context,
                    ref,
                    'DOUBLE-TAP-THEN-HOLD',
                    'Hold on the third touch (Safest)',
                    mode == ConfigGestureMode.doubleTapHold,
                    () => ref
                        .read(configGestureModeProvider.notifier)
                        .update(ConfigGestureMode.doubleTapHold),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          Text(
            'ADVANCED (COMING SOON)',
            style: TextStyle(
              fontFamily: 'Inter',
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSavePreset(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2024),
        title: const Text('Save Preset', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Preset Name',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFA6C9F8)),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text(
              'SAVE',
              style: TextStyle(color: Color(0xFFA6C9F8)),
            ),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final controlState = ref.read(controlStateProvider);
    final drumPads = ref.read(drumPadConfigProvider);
    final xyPads = ref.read(xyPadConfigProvider);

    final snapshot = PresetSnapshot(
      controlState: controlState,
      drumPadConfigs: drumPads,
      xyPadConfigs: xyPads,
    );

    await ref.read(snapshotManagerProvider).savePreset(name, snapshot);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved preset "$name"')));
    }
  }

  Future<void> _handleLoadPreset(BuildContext context, WidgetRef ref) async {
    final manager = ref.read(snapshotManagerProvider);
    final presets = await manager.listPresets();

    if (!context.mounted) return;

    if (presets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No presets found.')));
      return;
    }

    final currentPresets = List<String>.of(presets);

    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E2024),
              title: const Text(
                'Load Preset',
                style: TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: currentPresets.isEmpty
                    ? const Center(
                        child: Text(
                          'No presets available.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: currentPresets.length,
                        itemBuilder: (context, index) {
                          final name = currentPresets[index];
                          return ListTile(
                            title: Text(
                              name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            onTap: () => Navigator.pop(context, name),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.white38,
                              ),
                              onPressed: () async {
                                await manager.deletePreset(name);
                                setState(() {
                                  currentPresets.removeAt(index);
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Deleted preset "$name"'),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected == null) return;

    final snapshot = await manager.loadPreset(selected);
    if (snapshot == null) return;

    // Inject state into providers
    ref.read(controlStateProvider.notifier).injectState(snapshot.controlState);
    ref
        .read(drumPadConfigProvider.notifier)
        .setAllConfigs(snapshot.drumPadConfigs);
    ref.read(xyPadConfigProvider.notifier).setAllConfigs(snapshot.xyPadConfigs);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Loaded preset "$selected"')));
    }
  }

  String _getBehaviorDescription(FaderBehavior behavior) {
    switch (behavior) {
      case FaderBehavior.hybrid:
        return 'Touch anywhere to grab, slide for relative changes.';
      case FaderBehavior.jump:
        return 'Fader snaps instantly to your exact physical touch location.';
      case FaderBehavior.catchUp:
        return 'Touch is ignored until you cross the physical ribbon barrier.';
    }
  }

  Widget _buildGestureOption(
    BuildContext context,
    WidgetRef ref,
    String title,
    String subtitle,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : Colors.white12,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      color: isSelected ? Colors.white : Colors.white60,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primaryContainer,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:package_info_plus/package_info_plus.dart';

import 'open_midi_screen.dart';
import '../core/managers/snapshot_manager.dart';
import 'layout_state.dart';
import 'midi_settings_state.dart';
import 'design_system.dart';
import 'side_panel_state.dart';
import 'widgets/preset_management.dart';

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
        automaticallyImplyLeading: false,
        leading: MediaQuery.of(context).orientation == Orientation.landscape
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => ref.read(sidePanelProvider.notifier).hide(),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          'Settings',
          style: AppText.system(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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

          // Panel Position Section
          Text(
            'PANEL POSITION',
            style: AppText.system(
              color: const Color(0xFFC3C7CA),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              final panelSide = ref.watch(sidePanelProvider).side;
              final isLeft = panelSide == SidePanelSide.left;
              return SwitchListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(
                  isLeft ? 'DOCK ON LEFT' : 'DOCK ON RIGHT',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  'Choose which side the settings panel appears in landscape.',
                  style: AppText.system(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                value: isLeft,
                activeThumbColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer,
                onChanged: (val) {
                  ref
                      .read(sidePanelProvider.notifier)
                      .setSide(val ? SidePanelSide.left : SidePanelSide.right);
                },
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
          const Text(
            'ADVANCED',
            style: TextStyle(
              fontFamily: 'Inter',
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text(
              'EXPORT ACTIVE PAGE (.OMC)',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            subtitle: const Text(
              'Share your current page mapping with other devices.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            trailing: const Icon(
              Icons.ios_share,
              color: Colors.white54,
              size: 20,
            ),
            onTap: () {
              final activePage = ref.read(layoutStateProvider).activePage;
              ref.read(snapshotManagerProvider).exportActiveLayout(activePage);
            },
          ),
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text(
              'IMPORT PAGE (.OMC)',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            subtitle: const Text(
              'Load a single page mapping from an external file.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            trailing: const Icon(
              Icons.file_open_outlined,
              color: Colors.white54,
              size: 20,
            ),
            onTap: () async {
              final newPage = await ref
                  .read(snapshotManagerProvider)
                  .importLayout();
              if (newPage != null) {
                ref
                    .read(layoutStateProvider.notifier)
                    .overwriteActivePage(newPage);
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleSavePreset(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const SavePresetDialog(),
    );

    if (result != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Preset "$result" saved.')));
    }
  }

  Future<void> _handleLoadPreset(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => const LoadPresetDialog(),
    );

    if (result != null && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Loaded preset "$result".')));
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

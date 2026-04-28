// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/velocity_drum_pad.dart';
import '../widgets/delayed_menu_trigger.dart';

class DrumGridPanel extends ConsumerWidget {
  final int startingNote;
  final int channel;

  const DrumGridPanel({
    super.key,
    this.startingNote = 36, // Standard General MIDI Kick Drum
    this.channel = 9,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padWidth = constraints.maxWidth / 2;
        final padHeight = constraints.maxHeight / 4;
        final aspectRatio = padWidth / padHeight;

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
                final noteLabels = {
                  36: 'KICK 1',
                  37: 'SNARE 1',
                  38: 'SNARE 2',
                  39: 'CLAP',
                  40: 'SNARE 3',
                  41: 'TOM 1',
                  42: 'HAT C',
                  43: 'TOM 2',
                  44: 'PEDAL',
                  45: 'TOM 3',
                  46: 'HAT O',
                  47: 'TOM 4',
                  48: 'TOM 5',
                  49: 'CRASH',
                };

                final currentNote = startingNote + index;
                final label = noteLabels[currentNote] ?? 'PAD $currentNote';

                return VelocityDrumPad(
                  id: 'drum_pad_$index',
                  note: currentNote,
                  channel: channel,
                  label: label,
                );
              },
            ),

            // Preset Menu Trigger
            Positioned(
              top: 8,
              right: 8,
              child: Builder(
                builder: (menuContext) => DelayedMenuTrigger(
                  onTrigger: () => _showPresetMenu(menuContext, ref),
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

  void _showPresetMenu(BuildContext context, WidgetRef ref) {
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

    showMenu<List<int>>(
      context: context,
      position: position,
      color: const Color(0xFF1E2024),
      items: [
        const PopupMenuItem(
          value: [36, 38, 42, 46, 37, 39, 41, 45],
          child: Text('General MIDI', style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuItem(
          value: [37, 36, 42, 44, 38, 40, 46, 48],
          child: Text('MPC Classic', style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuItem(
          value: [36, 37, 38, 39, 40, 41, 42, 43],
          child: Text(
            'Ableton Drum Rack',
            style: TextStyle(color: Colors.white),
          ),
        ),
        const PopupMenuItem(
          value: null,
          child: Text(
            'Reset to Default',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      ],
    ).then((notes) {
      if (notes != null) {
        final Map<String, DrumPadConfig> newConfigs = {};
        for (int i = 0; i < 8; i++) {
          newConfigs['drum_pad_$i'] = DrumPadConfig(
            note: notes[i],
            channel: channel,
          );
        }
        ref.read(drumPadConfigProvider.notifier).setAllConfigs(newConfigs);
      } else if (notes == null) {
        // Reset logic could go here if needed, or just clear.
        ref.read(drumPadConfigProvider.notifier).setAllConfigs({});
      }
    });
  }
}

// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import '../widgets/velocity_drum_pad.dart';

class DrumGridPanel extends StatelessWidget {
  final int startingNote;
  final int channel;

  const DrumGridPanel({
    super.key,
    this.startingNote = 36, // Standard General MIDI Kick Drum
    this.channel = 9,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the aspect ratio to fit 2 columns and 4 rows exactly
        // Pad width = totalWidth / 2
        // Pad height = totalHeight / 4
        // AspectRatio = width / height
        final padWidth = constraints.maxWidth / 2;
        final padHeight = constraints.maxHeight / 4;
        final aspectRatio = padWidth / padHeight;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: aspectRatio,
            crossAxisSpacing: 2.0, // Tighter spacing for industrial look
            mainAxisSpacing: 2.0,
          ),
          itemCount: 8,
          itemBuilder: (context, index) {
            // General MIDI drum labels mapping (simplified for typical 2x4)
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
        );
      },
    );
  }
}

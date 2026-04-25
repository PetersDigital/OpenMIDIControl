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
        final isLandscape = constraints.maxWidth > constraints.maxHeight;

        int crossAxisCount;
        int totalPads;

        if (isLandscape) {
          // In landscape, we want 2 rows.
          // Since we want square pads, the pad height should be max constraints.maxHeight / 2.
          // So the pad width is also constraints.maxHeight / 2.
          // How many fit in maxWidth?
          final padSize = constraints.maxHeight / 2.0;
          crossAxisCount = (constraints.maxWidth / padSize).floor();

          // Ensure we have at least a 2x4 grid to match requirements if space allows
          if (crossAxisCount < 4) {
            crossAxisCount = 4;
          }

          totalPads = crossAxisCount * 2;
        } else {
          // Portrait: Classic MPC 3x3 layout
          crossAxisCount = 3;
          totalPads = 9;
        }

        return GridView.builder(
          physics:
              const NeverScrollableScrollPhysics(), // Usually pads are fixed
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.0, // Square pads
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
          ),
          itemCount: totalPads,
          itemBuilder: (context, index) {
            // General MIDI drum labels mapping (simplified for typical 3x3 / 2x4)
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

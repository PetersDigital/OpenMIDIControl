// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/velocity_drum_pad.dart';
import '../layout_state.dart';
import '../../core/models/layout_models.dart';

class DrumGridPanel extends ConsumerWidget {
  const DrumGridPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layoutState = ref.watch(layoutStateProvider);
    // Get PADS page (index 2)
    final padControls = layoutState.pages.length > 2
        ? layoutState.pages[2].controls
        : <LayoutControl>[];

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
              itemCount: padControls.length,
              itemBuilder: (context, index) {
                final control = padControls[index];

                return VelocityDrumPad(
                  id: control.id,
                  note: control.defaultCc,
                  channel: control.channel,
                  displayName: control.displayName,
                );
              },
            ),
          ],
        );
      },
    );
  }
}

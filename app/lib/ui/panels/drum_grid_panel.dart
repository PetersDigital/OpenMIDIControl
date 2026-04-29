// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/velocity_drum_pad.dart';
import '../widgets/delayed_menu_trigger.dart';
import '../layout_state.dart';
import '../../core/models/layout_models.dart';

class DrumGridPanel extends ConsumerWidget {
  const DrumGridPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padControls = ref.watch(
      layoutStateProvider.select(
        (s) =>
            s.pages.length > 2 ? s.pages[2].controls : const <LayoutControl>[],
      ),
    );
    final isLocked = ref.watch(
      layoutStateProvider.select((s) => s.isPerformanceLocked),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const int crossAxisCount = 2;
        final int rows = (padControls.length / crossAxisCount).ceil();
        const double mainAxisSpacing = 2.0;
        const double crossAxisSpacing = 2.0;

        final double availableWidth = constraints.maxWidth - crossAxisSpacing;
        final double padWidth = availableWidth / crossAxisCount;

        final double totalMainAxisSpacing = rows > 1
            ? (rows - 1) * mainAxisSpacing
            : 0.0;
        final double availableHeight =
            constraints.maxHeight - totalMainAxisSpacing;
        final double padHeight = rows > 0 ? availableHeight / rows : 1.0;

        final double safePadHeight = padHeight > 0 ? padHeight : 1.0;
        final double aspectRatio = padWidth / safePadHeight;

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
            // Layout Settings Icon
            if (!isLocked)
              Positioned(
                top: 8,
                right: 8,
                child: Builder(
                  builder: (menuContext) => DelayedMenuTrigger(
                    id: 'drum_grid_settings',
                    onTrigger: () => _showPresetMenu(menuContext, ref),
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

    showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF1E2024),
      items: [
        const PopupMenuItem(
          value: 'MPC',
          child: Text(
            'MPC Layout',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        const PopupMenuItem(
          value: 'Ableton',
          child: Text(
            'Ableton Layout',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    ).then((choice) {
      if (choice != null) {
        ref.read(layoutStateProvider.notifier).applyDrumPreset(choice);
      }
    });
  }
}

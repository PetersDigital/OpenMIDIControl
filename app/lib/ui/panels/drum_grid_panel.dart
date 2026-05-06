// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/velocity_drum_pad.dart';
import '../widgets/delayed_menu_trigger.dart';
import '../layout_state.dart';

class DrumGridPanel extends ConsumerWidget {
  final bool isActive;
  const DrumGridPanel({super.key, this.isActive = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padCount = ref.watch(
      layoutStateProvider.select(
        (s) => s.pages.length > 2 ? s.pages[2].controls.length : 0,
      ),
    );
    final isLocked = ref.watch(
      layoutStateProvider.select((s) => s.isPerformanceLocked),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        const int crossAxisCount = 2;
        final int rows = (padCount / crossAxisCount).ceil();
        const double mainAxisSpacing = 0.0;
        const double crossAxisSpacing = 0.0;

        final double availableWidth = (constraints.maxWidth - crossAxisSpacing)
            .clamp(1.0, double.infinity);
        final double padWidth = availableWidth / crossAxisCount;

        final double totalMainAxisSpacing = rows > 1
            ? (rows - 1) * mainAxisSpacing
            : 0.0;
        final double availableHeight =
            (constraints.maxHeight - totalMainAxisSpacing).clamp(
              1.0,
              double.infinity,
            );
        final double padHeight = rows > 0 ? availableHeight / rows : 1.0;

        final double safePadHeight = padHeight.clamp(1.0, double.infinity);
        final double aspectRatio = (padWidth / safePadHeight).clamp(
          0.01,
          double.infinity,
        );

        return Stack(
          children: [
            GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: aspectRatio,
                crossAxisSpacing: 0.0,
                mainAxisSpacing: 0.0,
              ),
              itemCount: padCount,
              itemBuilder: (context, index) {
                return VelocityDrumPad(
                  key: ValueKey('drum_pad_$index'),
                  index: index,
                  isActive: isActive,
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
        const PopupMenuDivider(height: 1),
        const PopupMenuItem(
          value: 'reset',
          child: Text(
            'Reset to Default',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        const PopupMenuItem(
          value: 'clear',
          child: Text(
            'Clear Assignments',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
      ],
    ).then((choice) {
      if (choice == 'MPC' || choice == 'Ableton') {
        ref.read(layoutStateProvider.notifier).applyDrumPreset(choice!);
      } else if (choice == 'reset') {
        ref.read(layoutStateProvider.notifier).resetPage(2);
      } else if (choice == 'clear') {
        ref.read(layoutStateProvider.notifier).clearPage(2);
      }
    });
  }
}

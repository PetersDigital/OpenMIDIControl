// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import '../../core/models/layout_models.dart';
import '../layout_state.dart';
import '../editor_state.dart';
import 'control_widget_factory.dart';
import 'editor_control_wrapper.dart';

class DynamicGridRenderer extends ConsumerWidget {
  final List<LayoutControl> controls;
  final String pageId;
  final bool isActive;
  final bool isMobile;

  const DynamicGridRenderer({
    super.key,
    required this.controls,
    required this.pageId,
    required this.isActive,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditorMode = ref.watch(editorModeProvider);
    final page = ref.watch(
      layoutStateProvider.select(
        (s) => s.pages.firstWhereOrNull((p) => p.id == pageId),
      ),
    );
    final cols = page?.gridColumns ?? 8;
    final rows = page?.gridRows ?? 4;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double cellWidth = constraints.maxWidth / cols;
        final double cellHeight = constraints.maxHeight / rows;

        return Stack(
          children: [
            // Background Grid (only visible in Editor Mode)
            if (isEditorMode)
              Positioned.fill(
                child: _buildBackgroundGrid(
                  cellWidth,
                  cellHeight,
                  cols,
                  rows,
                  ref,
                ),
              ),

            // Controls Rendered on the Grid
            ...controls.map((control) {
              Widget child = ControlWidgetFactory.buildControl(
                context,
                control,
                pageId,
                isActive,
                isMobile,
                ref,
              );

              if (isEditorMode) {
                child = EditorControlWrapper(
                  control: control,
                  pageId: pageId,
                  cellWidth: cellWidth,
                  cellHeight: cellHeight,
                  child: child,
                );
              }

              return Positioned(
                key: ValueKey(control.id),
                left: control.x * cellWidth,
                top: control.y * cellHeight,
                width: control.width * cellWidth,
                height: control.height * cellHeight,
                child: child,
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildBackgroundGrid(
    double cellWidth,
    double cellHeight,
    int cols,
    int rows,
    WidgetRef ref,
  ) {
    return Stack(
      children: [
        for (int row = 0; row < rows; row++)
          for (int col = 0; col < cols; col++)
            Positioned(
              left: col * cellWidth,
              top: row * cellHeight,
              width: cellWidth,
              height: cellHeight,
              child: DragTarget<ControlType>(
                onAcceptWithDetails: (details) {
                  ref
                      .read(layoutStateProvider.notifier)
                      .addControlToActivePage(details.data, x: col, y: row);
                },
                builder: (context, candidateData, rejectedData) {
                  return Container(
                    decoration: BoxDecoration(
                      color: candidateData.isNotEmpty
                          ? const Color(0xFFA6C9F8).withValues(alpha: 0.2)
                          : null,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1.0,
                      ),
                    ),
                  );
                },
              ),
            ),
      ],
    );
  }
}

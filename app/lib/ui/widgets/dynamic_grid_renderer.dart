// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/layout_models.dart';
import '../editor_state.dart';
import 'control_widget_factory.dart';
import 'editor_control_wrapper.dart';

class DynamicGridRenderer extends ConsumerWidget {
  final List<LayoutControl> controls;
  final String pageId;
  final bool isActive;
  final bool isMobile;

  // For now, these are fixed values per instructions
  static const int defaultColumns = 8;
  static const int defaultRows = 4;

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final double cellWidth = constraints.maxWidth / defaultColumns;
        final double cellHeight = constraints.maxHeight / defaultRows;

        return Stack(
          children: [
            // Background Grid (only visible in Editor Mode)
            if (isEditorMode)
              Positioned.fill(
                child: _buildBackgroundGrid(cellWidth, cellHeight),
              ),

            // Controls Rendered on the Grid
            ...controls.map((control) {
              Widget child = ControlWidgetFactory.buildControl(
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

  Widget _buildBackgroundGrid(double cellWidth, double cellHeight) {
    return Stack(
      children: [
        for (int row = 0; row < defaultRows; row++)
          for (int col = 0; col < defaultColumns; col++)
            Positioned(
              left: col * cellWidth,
              top: row * cellHeight,
              width: cellWidth,
              height: cellHeight,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1.0,
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

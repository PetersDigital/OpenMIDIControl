// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/layout_models.dart';
import '../editor_state.dart';
import '../layout_state.dart';

class EditorControlWrapper extends ConsumerStatefulWidget {
  final Widget child;
  final LayoutControl control;
  final String pageId;
  final double cellWidth;
  final double cellHeight;

  const EditorControlWrapper({
    super.key,
    required this.child,
    required this.control,
    required this.pageId,
    required this.cellWidth,
    required this.cellHeight,
  });

  @override
  ConsumerState<EditorControlWrapper> createState() =>
      _EditorControlWrapperState();
}

class _EditorControlWrapperState extends ConsumerState<EditorControlWrapper> {
  Offset _dragDelta = Offset.zero;
  Offset _resizeDelta = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final isSelected = ref.watch(selectedControlProvider) == widget.control.id;

    return Stack(
      children: [
        // The main control container (drag target)
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              ref
                  .read(selectedControlProvider.notifier)
                  .select(widget.control.id);
            },
            onPanStart: (details) {
              ref
                  .read(selectedControlProvider.notifier)
                  .select(widget.control.id);
              _dragDelta = Offset.zero;
            },
            onPanUpdate: (details) {
              _dragDelta += details.delta;

              final dxCells = (_dragDelta.dx / widget.cellWidth).round();
              final dyCells = (_dragDelta.dy / widget.cellHeight).round();

              if (dxCells != 0 || dyCells != 0) {
                ref
                    .read(layoutStateProvider.notifier)
                    .updateControlSpatialData(
                      widget.pageId,
                      widget.control.id,
                      x: widget.control.x + dxCells,
                      y: widget.control.y + dyCells,
                    );
                // Reset delta by the amount we consumed
                _dragDelta -= Offset(
                  dxCells * widget.cellWidth,
                  dyCells * widget.cellHeight,
                );
              }
            },
            child: AbsorbPointer(
              absorbing: true,
              child: Container(
                decoration: BoxDecoration(
                  border: isSelected
                      ? Border.all(color: const Color(0xFFA6C9F8), width: 2.0)
                      : null,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),

        // Resize Handle (bottom right)
        if (isSelected)
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (details) {
                _resizeDelta = Offset.zero;
              },
              onPanUpdate: (details) {
                _resizeDelta += details.delta;

                final dwCells = (_resizeDelta.dx / widget.cellWidth).round();
                final dhCells = (_resizeDelta.dy / widget.cellHeight).round();

                if (dwCells != 0 || dhCells != 0) {
                  ref
                      .read(layoutStateProvider.notifier)
                      .updateControlSpatialData(
                        widget.pageId,
                        widget.control.id,
                        width: widget.control.width + dwCells,
                        height: widget.control.height + dhCells,
                      );
                  // Reset delta by the amount we consumed
                  _resizeDelta -= Offset(
                    dwCells * widget.cellWidth,
                    dhCells * widget.cellHeight,
                  );
                }
              },
              child: Container(
                width: 16,
                height: 16,
                color: const Color(0xFFA6C9F8),
              ),
            ),
          ),
      ],
    );
  }
}

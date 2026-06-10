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

    final bool isCompact =
        widget.control.type == ControlType.drumPad ||
        widget.control.type == ControlType.encoder ||
        widget.control.type == ControlType.trigger ||
        widget.control.type == ControlType.toggle;
    final double handleSize = isCompact ? 36.0 : 60.0;
    final double innerPadding = isCompact ? 5.0 : 8.0;
    final double iconSize = isCompact ? 12.0 : 20.0;
    final double handleOffset = isCompact ? 5.0 : 5.0;

    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Stack(
        clipBehavior: Clip.none,
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
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AbsorbPointer(absorbing: true, child: widget.child),
                  ),
                  // Darken locked controls in edit mode
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: isSelected
                              ? Border.all(
                                  color: const Color(0xFFA6C9F8),
                                  width: 2.0,
                                )
                              : Border.all(
                                  color: const Color(
                                    0xFFA6C9F8,
                                  ).withValues(alpha: 0.3),
                                  width: 1.0,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Resize Handle (bottom right, offset slightly outward with touch area)
          if (isSelected)
            Positioned(
              right: handleOffset,
              bottom: handleOffset,
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
                  width: handleSize,
                  height: handleSize,
                  padding: EdgeInsets.all(innerPadding),
                  color: Colors.transparent, // transparent touch area
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFA6C9F8),
                      borderRadius: BorderRadius.circular(isCompact ? 4 : 6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: isCompact ? 3 : 4,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.zoom_out_map,
                        size: iconSize,
                        color: const Color(0xFF1E2024),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Delete Handle (top right, offset slightly outward with touch area)
          if (isSelected)
            Positioned(
              right: handleOffset,
              top: handleOffset,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  ref
                      .read(layoutStateProvider.notifier)
                      .deleteControl(widget.pageId, widget.control.id);
                  ref.read(selectedControlProvider.notifier).select(null);
                },
                child: Container(
                  width: handleSize,
                  height: handleSize,
                  padding: EdgeInsets.all(innerPadding),
                  color: Colors.transparent, // transparent touch area
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE57373), // Soft premium red
                      borderRadius: BorderRadius.circular(isCompact ? 4 : 6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: isCompact ? 3 : 4,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.delete,
                        size: iconSize,
                        color: const Color(0xFF1E2024),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

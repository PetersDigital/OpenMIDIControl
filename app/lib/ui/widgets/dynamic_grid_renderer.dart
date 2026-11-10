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

class DynamicGridRenderer extends ConsumerStatefulWidget {
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
  ConsumerState<DynamicGridRenderer> createState() =>
      _DynamicGridRendererState();
}

class _DynamicGridRendererState extends ConsumerState<DynamicGridRenderer> {
  int? _hoverCol;
  int? _hoverRow;

  @override
  Widget build(BuildContext context) {
    final isEditorMode = ref.watch(editorModeProvider.select((v) => v));
    final page = ref.watch(
      layoutStateProvider.select(
        (s) => s.pages.firstWhereOrNull((p) => p.id == widget.pageId),
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
                  constraints.maxWidth,
                  constraints.maxHeight,
                ),
              ),

            // Controls Rendered on the Grid
            ...widget.controls.map((control) {
              Widget child = ControlWidgetFactory.buildControl(
                context,
                control,
                widget.pageId,
                widget.isActive,
                widget.isMobile,
                ref,
              );

              if (isEditorMode) {
                child = EditorControlWrapper(
                  control: control,
                  pageId: widget.pageId,
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
    double totalWidth,
    double totalHeight,
  ) {
    return DragTarget<ControlType>(
      onWillAcceptWithDetails: (details) {
        final RenderBox? box = context.findRenderObject() as RenderBox?;
        if (box != null &&
            box.hasSize &&
            box.size.width > 0 &&
            box.size.height > 0) {
          final local = box.globalToLocal(details.offset);
          final c = (local.dx / cellWidth).floor().clamp(0, cols - 1);
          final r = (local.dy / cellHeight).floor().clamp(0, rows - 1);
          if (_hoverCol != c || _hoverRow != r) {
            setState(() {
              _hoverCol = c;
              _hoverRow = r;
            });
          }
        }
        return true;
      },
      onMove: (details) {
        final RenderBox? box = context.findRenderObject() as RenderBox?;
        if (box != null &&
            box.hasSize &&
            box.size.width > 0 &&
            box.size.height > 0) {
          final local = box.globalToLocal(details.offset);
          final c = (local.dx / cellWidth).floor().clamp(0, cols - 1);
          final r = (local.dy / cellHeight).floor().clamp(0, rows - 1);
          if (_hoverCol != c || _hoverRow != r) {
            setState(() {
              _hoverCol = c;
              _hoverRow = r;
            });
          }
        }
      },
      onLeave: (_) {
        if (_hoverCol != null || _hoverRow != null) {
          setState(() {
            _hoverCol = null;
            _hoverRow = null;
          });
        }
      },
      onAcceptWithDetails: (details) {
        final RenderBox? box = context.findRenderObject() as RenderBox?;
        int targetCol = 0;
        int targetRow = 0;
        if (box != null &&
            box.hasSize &&
            box.size.width > 0 &&
            box.size.height > 0) {
          final local = box.globalToLocal(details.offset);
          targetCol = (local.dx / cellWidth).floor().clamp(0, cols - 1);
          targetRow = (local.dy / cellHeight).floor().clamp(0, rows - 1);
        } else if (_hoverCol != null && _hoverRow != null) {
          targetCol = _hoverCol!;
          targetRow = _hoverRow!;
        }

        setState(() {
          _hoverCol = null;
          _hoverRow = null;
        });

        ref
            .read(layoutStateProvider.notifier)
            .addControlToActivePage(details.data, x: targetCol, y: targetRow);
      },
      builder: (context, candidateData, rejectedData) {
        return CustomPaint(
          size: Size(totalWidth, totalHeight),
          painter: _GridPainter(
            cols: cols,
            rows: rows,
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            hoverCol: candidateData.isNotEmpty ? _hoverCol : null,
            hoverRow: candidateData.isNotEmpty ? _hoverRow : null,
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  final int cols;
  final int rows;
  final double cellWidth;
  final double cellHeight;
  final int? hoverCol;
  final int? hoverRow;

  _GridPainter({
    required this.cols,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
    this.hoverCol,
    this.hoverRow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw grid lines
    for (int col = 0; col <= cols; col++) {
      final double x = col * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (int row = 0; row <= rows; row++) {
      final double y = row * cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Highlight hover cell if candidate is dragging over
    if (hoverCol != null && hoverRow != null) {
      final highlightPaint = Paint()
        ..color = const Color(0xFFA6C9F8).withValues(alpha: 0.2)
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTWH(
          hoverCol! * cellWidth,
          hoverRow! * cellHeight,
          cellWidth,
          cellHeight,
        ),
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.cols != cols ||
        oldDelegate.rows != rows ||
        oldDelegate.cellWidth != cellWidth ||
        oldDelegate.cellHeight != cellHeight ||
        oldDelegate.hoverCol != hoverCol ||
        oldDelegate.hoverRow != hoverRow;
  }
}

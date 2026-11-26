// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:material_ui/material_ui.dart';

/// Scales the grid around its original layout and local pointer coordinates.
class PerformanceGridViewport extends StatefulWidget {
  const PerformanceGridViewport({
    super.key,
    required this.scale,
    required this.panEnabled,
    required this.child,
  });

  final double scale;
  final bool panEnabled;
  final Widget child;

  @override
  State<PerformanceGridViewport> createState() =>
      _PerformanceGridViewportState();
}

class _PerformanceGridViewportState extends State<PerformanceGridViewport> {
  // Store the scroll position as a fraction so it stays in bounds on rotation.
  Offset _panFraction = Offset.zero;
  final Set<int> _gridPointers = {};

  @override
  void didUpdateWidget(PerformanceGridViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scale <= 1) _panFraction = Offset.zero;
  }

  void _pan(Offset delta, Offset overflow) {
    // Finish any gestures already captured by the grid before moving it.
    if (_gridPointers.isNotEmpty) return;
    final next = Offset(
      overflow.dx == 0
          ? 0
          : (_panFraction.dx - delta.dx / overflow.dx).clamp(0.0, 1.0),
      overflow.dy == 0
          ? 0
          : (_panFraction.dy - delta.dy / overflow.dy).clamp(0.0, 1.0),
    );
    if (next != _panFraction) setState(() => _panFraction = next);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        final scaled = viewport * widget.scale;
        final overflow = Offset(
          scaled.width - viewport.width,
          scaled.height - viewport.height,
        );
        final zoomedIn = widget.scale > 1;
        final panning = zoomedIn && widget.panEnabled;
        final origin = zoomedIn
            ? Offset(
                -overflow.dx * _panFraction.dx,
                -overflow.dy * _panFraction.dy,
              )
            : -overflow / 2;

        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: origin.dx,
                top: origin.dy,
                width: scaled.width,
                height: scaled.height,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox.fromSize(
                    size: viewport,
                    child: Listener(
                      onPointerDown: (event) =>
                          _gridPointers.add(event.pointer),
                      onPointerUp: (event) =>
                          _gridPointers.remove(event.pointer),
                      onPointerCancel: (event) =>
                          _gridPointers.remove(event.pointer),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
              if (panning)
                Positioned.fill(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (event) => _pan(event.delta, overflow),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.fromBorderSide(
                            BorderSide(color: Color(0xFFA6C9F8)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

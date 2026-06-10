// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/layout_models.dart';
import '../layout_state.dart';
import '../design_system.dart';

const _kAccent = Color(0xFFA6C9F8);
const _kSurface = Color(0xFF1E2024);
const _kCardBg = Color(0xFF1A1C20);
const _kBorderNormal = Color(0x14FFFFFF);

class WidgetPalettePanel extends ConsumerWidget {
  const WidgetPalettePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: _kSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(-8, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.dashboard_customize,
                    color: _kAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'WIDGET PALETTE',
                    style: AppText.system(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Instructions
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Tap to add or drag onto the grid.',
              style: AppText.system(color: Colors.white38, fontSize: 11),
            ),
          ),

          // Palette List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: const [
                _PaletteItem(
                  type: ControlType.fader,
                  icon: Icons.tune,
                  label: 'Fader',
                  subtitle: 'Linear continuous control',
                ),
                _PaletteItem(
                  type: ControlType.xyPad,
                  icon: Icons.gamepad,
                  label: 'XY Pad',
                  subtitle: '2D continuous control',
                ),
                _PaletteItem(
                  type: ControlType.drumPad,
                  icon: Icons.grid_on,
                  label: 'Drum Pad',
                  subtitle: 'Velocity sensitive pad',
                ),
                _PaletteItem(
                  type: ControlType.encoder,
                  icon: Icons.data_usage,
                  label: 'Encoder',
                  subtitle: 'Endless rotary knob',
                ),
                _PaletteItem(
                  type: ControlType.trigger,
                  icon: Icons.radio_button_checked,
                  label: 'Trigger',
                  subtitle: 'Momentary button',
                ),
                _PaletteItem(
                  type: ControlType.toggle,
                  icon: Icons.toggle_on,
                  label: 'Toggle',
                  subtitle: 'On/Off switch',
                ),
                SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteItem extends ConsumerStatefulWidget {
  final ControlType type;
  final IconData icon;
  final String label;
  final String subtitle;

  const _PaletteItem({
    required this.type,
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  @override
  ConsumerState<_PaletteItem> createState() => _PaletteItemState();
}

class _PaletteItemState extends ConsumerState<_PaletteItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final itemWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: _isHovering ? _kAccent.withValues(alpha: 0.08) : _kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isHovering ? _kAccent.withValues(alpha: 0.3) : _kBorderNormal,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              color: _isHovering ? _kAccent : Colors.white70,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.subtitle,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.drag_indicator, color: Colors.white24, size: 20),
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Draggable<ControlType>(
        data: widget.type,
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.9,
            child: SizedBox(width: 240, child: itemWidget),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.4, child: itemWidget),
        child: GestureDetector(
          onTap: () {
            ref
                .read(layoutStateProvider.notifier)
                .addControlToActivePage(widget.type);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Added ${widget.label} to active page'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: itemWidget,
        ),
      ),
    );
  }
}

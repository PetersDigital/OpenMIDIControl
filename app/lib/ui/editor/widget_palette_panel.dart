// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/layout_models.dart';
import '../layout_state.dart';

class WidgetPalettePanel extends ConsumerWidget {
  const WidgetPalettePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: 250,
      color: const Color(0xFF1A1C20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF111318),
            child: const Text(
              'Add Widget',
              style: TextStyle(
                color: Color(0xFFA6C9F8),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                _PaletteItem(
                  type: ControlType.fader,
                  icon: Icons.tune,
                  label: 'Fader',
                ),
                _PaletteItem(
                  type: ControlType.xyPad,
                  icon: Icons.gamepad,
                  label: 'XY Pad',
                ),
                _PaletteItem(
                  type: ControlType.drumPad,
                  icon: Icons.grid_on,
                  label: 'Drum Pad',
                ),
                _PaletteItem(
                  type: ControlType.encoder,
                  icon: Icons.data_usage,
                  label: 'Encoder',
                ),
                _PaletteItem(
                  type: ControlType.trigger,
                  icon: Icons.radio_button_checked,
                  label: 'Trigger',
                ),
                _PaletteItem(
                  type: ControlType.toggle,
                  icon: Icons.toggle_on,
                  label: 'Toggle',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteItem extends ConsumerWidget {
  final ControlType type;
  final IconData icon;
  final String label;

  const _PaletteItem({
    required this.type,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemWidget = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF282A2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFA6C9F8), size: 24),
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    return Draggable<ControlType>(
      data: type,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.8,
          child: SizedBox(width: 200, child: itemWidget),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: itemWidget),
      child: GestureDetector(
        onTap: () {
          ref.read(layoutStateProvider.notifier).addControlToActivePage(type);
        },
        child: itemWidget,
      ),
    );
  }
}

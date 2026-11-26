// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/layout_models.dart';
import '../../core/models/page_templates.dart';
import '../layout_state.dart';
import '../design_system.dart';

const _kAccent = Color(0xFFA6C9F8);
const _kSurface = Color(0xFF1E2024);
const _kCardBg = Color(0xFF1A1C20);
const _kBorderNormal = Color(0x14FFFFFF);

enum _PaletteTab { controls, templates }

class WidgetPalettePanel extends ConsumerStatefulWidget {
  const WidgetPalettePanel({super.key});

  @override
  ConsumerState<WidgetPalettePanel> createState() => _WidgetPalettePanelState();
}

class _WidgetPalettePanelState extends ConsumerState<WidgetPalettePanel> {
  _PaletteTab _activeTab = _PaletteTab.controls;

  @override
  Widget build(BuildContext context) {
    final isTemplates = _activeTab == _PaletteTab.templates;
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
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
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

          // Tab switcher
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kBorderNormal),
              ),
              child: Row(
                children: [
                  _PaletteTabButton(
                    key: const ValueKey('palette_tab_controls'),
                    label: 'CONTROLS',
                    selected: !isTemplates,
                    onTap: () =>
                        setState(() => _activeTab = _PaletteTab.controls),
                  ),
                  _PaletteTabButton(
                    key: const ValueKey('palette_tab_templates'),
                    label: 'TEMPLATES',
                    selected: isTemplates,
                    onTap: () =>
                        setState(() => _activeTab = _PaletteTab.templates),
                  ),
                ],
              ),
            ),
          ),

          // Instructions
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              isTemplates
                  ? 'Stamp as a new page or onto open grid space.'
                  : 'Tap to add or drag onto the grid.',
              style: AppText.system(color: Colors.white38, fontSize: 11),
            ),
          ),

          // Palette List
          Expanded(
            child: isTemplates
                ? ListView(
                    key: const ValueKey('palette_templates_list'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    children: [
                      for (final template in FactoryPageTemplates.all)
                        _TemplateItem(template: template),
                      const SizedBox(height: 24),
                    ],
                  )
                : ListView(
                    key: const ValueKey('palette_controls_list'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
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
                      _PaletteItem(
                        type: ControlType.aftertouchPad,
                        icon: Icons.touch_app,
                        label: 'Aftertouch Pad',
                        subtitle: 'Note pad with vertical CC expression',
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

class _PaletteTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteTabButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? _kAccent.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppText.system(
              color: selected ? _kAccent : Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateItem extends ConsumerWidget {
  final PageTemplate template;

  const _TemplateItem({required this.template});

  IconData _iconForTemplate(PageTemplateId id) {
    return switch (id) {
      PageTemplateId.factoryFaderBank => Icons.tune,
      PageTemplateId.drumGrid4x4 => Icons.grid_view_rounded,
      PageTemplateId.xyAndEncoders => Icons.gamepad,
      PageTemplateId.mixerStub8Track => Icons.view_column,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = Container(
      key: ValueKey('template_card_${template.id.name}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderNormal),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _iconForTemplate(template.id),
                  color: _kAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      template.name,
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${template.gridColumns}x${template.gridRows} • ${template.controlCount} controls',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: _kAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.drag_indicator, color: Colors.white24, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            template.description,
            style: const TextStyle(
              fontFamily: 'Inter',
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: ValueKey('template_on_page_${template.id.name}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: _kBorderNormal),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    final result = ref
                        .read(layoutStateProvider.notifier)
                        .stampTemplateOnActivePage(template);
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.clearSnackBars();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          result.isSuccess
                              ? 'Stamped ${template.name} onto active page'
                              : result.status ==
                                    TemplateStampStatus.noActivePage
                              ? 'No active page — create a new page instead'
                              : 'Not enough open space on active page — try NEW PAGE',
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text(
                    'ON PAGE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  key: ValueKey('template_new_page_${template.id.name}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _kAccent,
                    foregroundColor: _kSurface,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    final notifier = ref.read(layoutStateProvider.notifier);
                    final created = notifier.addPageFromTemplate(template);
                    final createdIndex = ref
                        .read(layoutStateProvider)
                        .pages
                        .indexWhere((p) => p.id == created.id);
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.clearSnackBars();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Added page "${created.name}"'),
                        duration: const Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                        action: createdIndex == -1
                            ? null
                            : SnackBarAction(
                                label: 'UNDO',
                                onPressed: () {
                                  notifier.removePage(createdIndex);
                                },
                              ),
                      ),
                    );
                  },
                  child: const Text(
                    'NEW PAGE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return LongPressDraggable<PageTemplate>(
      data: template,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.9, child: SizedBox(width: 240, child: card)),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: card),
      child: card,
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
        affinity: Axis.horizontal,
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

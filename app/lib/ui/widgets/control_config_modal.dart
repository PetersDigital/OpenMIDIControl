// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/layout_models.dart';
import '../../core/models/widget_style.dart';
import '../design_system.dart';
import 'midi_action_fields.dart';
import 'scrollable_dialog_content.dart';
import '../layout_state.dart';

class ControlConfigModal extends ConsumerStatefulWidget {
  final String controlId;
  final String displayNameLabel;

  const ControlConfigModal({
    super.key,
    required this.controlId,
    this.displayNameLabel = 'Display Name',
  });

  @override
  ConsumerState<ControlConfigModal> createState() => _ControlConfigModalState();
}

class _ControlConfigModalState extends ConsumerState<ControlConfigModal> {
  final _formKey = GlobalKey<FormState>();
  late final ControlType? _controlType;
  late final MidiActionDraft _primaryAction;
  MidiActionDraft? _secondaryAction;
  late final TextEditingController _displayNameController;
  bool _invertX = false;
  bool _invertY = false;
  String? _accentColorHex;
  String? _fontFamily;
  bool _showLabel = true;
  bool _showNumericReadout = true;

  bool get _isXy => _controlType == ControlType.xyPad;
  bool get _isContinuous => switch (_controlType) {
    ControlType.fader || ControlType.xyPad || ControlType.encoder => true,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    final control = ref
        .read(layoutStateProvider)
        .getControlById(widget.controlId);

    _controlType = control?.type;
    _primaryAction = MidiActionDraft(
      payload: control?.payload,
      channel: control?.channel ?? 0,
      identifier: control?.defaultCc,
      drumPad: _controlType == ControlType.drumPad,
      allowUnassigned: _isXy,
    );

    final name = control?.customName;
    _displayNameController = TextEditingController(
      text: name == 'Unassigned' ? null : name,
    );

    if (_isXy && control != null) {
      _secondaryAction = MidiActionDraft(
        payload: control.effectiveSecondaryPayload,
        channel: control.channel,
        identifier: control.secondaryCc,
        allowUnassigned: true,
      );
      _invertX = control.invertX;
      _invertY = control.invertY;
    }

    final style = control?.effectiveStyle ?? WidgetStyle.defaults;
    _accentColorHex = style.accentColorHex;
    _fontFamily = style.fontFamily;
    _showLabel = style.showLabel;
    _showNumericReadout = style.showNumericReadout;
  }

  @override
  void dispose() {
    _primaryAction.dispose();
    _secondaryAction?.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _save() {
    final invalidFields = _formKey.currentState!.validateGranularly();
    if (invalidFields.isNotEmpty) {
      Scrollable.ensureVisible(invalidFields.first.context, alignment: 0.15);
      return;
    }
    final secondary = _secondaryAction?.payload;
    final nextStyle = WidgetStyle(
      accentColorHex: _accentColorHex,
      fontFamily: _fontFamily,
      showLabel: _showLabel,
      showNumericReadout: _showNumericReadout,
    );

    ref
        .read(layoutStateProvider.notifier)
        .updateControlActions(
          widget.controlId,
          payload: _primaryAction.payload,
          secondaryPayload: secondary,
          clearSecondary: _secondaryAction != null && secondary == null,
          name: _displayNameController.text,
          invertX: _isXy ? _invertX : null,
          invertY: _isXy ? _invertY : null,
          style: nextStyle.isDefault ? null : nextStyle,
          clearStyle: nextStyle.isDefault,
        );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2024),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Configure Control',
            style: AppText.performance(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Color(0xFFC3C7CA)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 20,
          ),
        ],
      ),
      content: ScrollableDialogContent(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isXy) ...[
                const Text(
                  'X Axis',
                  style: TextStyle(color: Color(0xFFC3C7CA)),
                ),
                const SizedBox(height: 8),
              ],
              MidiActionFields(
                key: _isXy ? const ValueKey('xy-x-action') : null,
                draft: _primaryAction,
                usesPitchBendPosition: _isContinuous,
                supportsVariableVelocity:
                    _isContinuous || _controlType == ControlType.drumPad,
              ),
              if (_secondaryAction case final secondary?) ...[
                CheckboxListTile(
                  title: const Text(
                    'Invert X',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: _invertX,
                  onChanged: (v) => setState(() => _invertX = v ?? false),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Y Axis',
                  style: TextStyle(color: Color(0xFFC3C7CA)),
                ),
                const SizedBox(height: 8),
                MidiActionFields(
                  key: const ValueKey('xy-y-action'),
                  draft: secondary,
                  usesPitchBendPosition: true,
                  supportsVariableVelocity: true,
                ),
                CheckboxListTile(
                  title: const Text(
                    'Invert Y',
                    style: TextStyle(color: Colors.white),
                  ),
                  value: _invertY,
                  onChanged: (v) => setState(() => _invertY = v ?? false),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _displayNameController,
                textInputAction: TextInputAction.done,
                style: const TextStyle(color: Colors.white),
                decoration: MidiActionFields.decoration.copyWith(
                  labelText: widget.displayNameLabel,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'APPEARANCE',
                style: AppText.system(
                  color: const Color(0xFFC3C7CA),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ColorSwatchChip(
                    key: const ValueKey('style_color_default'),
                    tooltip: 'Default Accent',
                    color: null,
                    selected: _accentColorHex == null,
                    onTap: () => setState(() => _accentColorHex = null),
                  ),
                  for (final swatch in WidgetStyle.curatedPalette)
                    _ColorSwatchChip(
                      key: ValueKey('style_color_${swatch.hex}'),
                      tooltip: swatch.name,
                      color: Color(swatch.colorValue),
                      selected: _accentColorHex == swatch.hex,
                      onTap: () => setState(() => _accentColorHex = swatch.hex),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String?>(
                key: const ValueKey('style_font_dropdown'),
                initialValue: _fontFamily,
                dropdownColor: const Color(0xFF1E2024),
                style: const TextStyle(color: Colors.white),
                decoration: MidiActionFields.decoration.copyWith(
                  labelText: 'Font',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Default'),
                  ),
                  for (final font in WidgetStyle.supportedFonts)
                    DropdownMenuItem<String?>(value: font, child: Text(font)),
                ],
                onChanged: (val) => setState(() => _fontFamily = val),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                key: const ValueKey('style_show_label'),
                title: const Text(
                  'Show Label',
                  style: TextStyle(color: Colors.white),
                ),
                value: _showLabel,
                onChanged: (v) => setState(() => _showLabel = v ?? true),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                key: const ValueKey('style_show_numeric_readout'),
                title: const Text(
                  'Show Numeric Readout',
                  style: TextStyle(color: Colors.white),
                ),
                value: _showNumericReadout,
                onChanged: (v) =>
                    setState(() => _showNumericReadout = v ?? true),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
          child: Row(
            children: [
              TextButton(
                onPressed: () {
                  ref
                      .read(layoutStateProvider.notifier)
                      .clearControl(widget.controlId);
                  Navigator.of(context).pop();
                },
                child: Text(
                  _isXy ? 'Clear All' : 'Clear',
                  style: AppText.system(color: Colors.redAccent),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  ref
                      .read(layoutStateProvider.notifier)
                      .resetControl(widget.controlId);
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Reset',
                  style: AppText.system(color: const Color(0xFFA6C9F8)),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA6C9F8),
                  foregroundColor: const Color(0xFF0C0E12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  'Save',
                  style: AppText.system(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorSwatchChip extends StatelessWidget {
  final String tooltip;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatchChip({
    super.key,
    required this.tooltip,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fillColor = color ?? const Color(0xFF282A2E);
    final iconColor = color == null
        ? Colors.white70
        : (ThemeData.estimateBrightnessForColor(fillColor) == Brightness.light
              ? const Color(0xFF0C0E12)
              : Colors.white);

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: fillColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.white : Colors.white24,
              width: selected ? 2.5 : 1.0,
            ),
          ),
          alignment: Alignment.center,
          child: selected
              ? Icon(Icons.check, size: 16, color: iconColor)
              : (color == null
                    ? const Icon(
                        Icons.auto_fix_high,
                        size: 14,
                        color: Colors.white54,
                      )
                    : null),
        ),
      ),
    );
  }
}

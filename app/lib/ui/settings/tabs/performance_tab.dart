// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/action_payload.dart';
import '../../open_midi_screen.dart';
import '../../header_transport_state.dart';
import '../../midi_settings_state.dart';
import '../../side_panel_state.dart';
import '../../design_system.dart';
import '../../widgets/midi_action_fields.dart';
import '../../widgets/scrollable_dialog_content.dart';

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

const _kAccent = Color(0xFFA6C9F8);
const _kCardBg = Color(0xFF1A1C20);
const _kBorderNormal = Color(0x14FFFFFF);
const _kBorderSelected = _kAccent;
const _kSectionLabel = TextStyle(
  fontFamily: 'Inter',
  color: Color(0xFFC3C7CA),
  fontSize: 11,
  fontWeight: FontWeight.bold,
  letterSpacing: 2.0,
);

Widget _sectionLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Text(text, style: _kSectionLabel),
);

Widget _divider() => const Divider(color: Color(0x1AFFFFFF), height: 32);

// ---------------------------------------------------------------------------
// PerformanceTab
// ---------------------------------------------------------------------------

class PerformanceTab extends StatelessWidget {
  const PerformanceTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: const [
        _FaderBehaviorSection(),
        _DividerSection(),
        _LayoutHandSection(),
        _DividerSection(),
        _PanelPositionSection(),
        _DividerSection(),
        _SafetyHoldSection(),
        _DividerSection(),
        _ConfigGestureSection(),
        _DividerSection(),
        _TransportAssignmentsSection(),
        SizedBox(height: 32),
      ],
    );
  }
}

class _DividerSection extends StatelessWidget {
  const _DividerSection();
  @override
  Widget build(BuildContext context) => _divider();
}

// ---------------------------------------------------------------------------
// Fader Behavior
// ---------------------------------------------------------------------------

class _FaderBehaviorSection extends ConsumerWidget {
  const _FaderBehaviorSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(faderBehaviorProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('FADER BEHAVIOR'),
        ...FaderBehavior.values.map(
          (b) => _SelectionCard(
            selected: current == b,
            title: b.name.toUpperCase(),
            subtitle: _faderDesc(b),
            onTap: () =>
                ref.read(faderBehaviorProvider.notifier).updateBehavior(b),
          ),
        ),
      ],
    );
  }

  String _faderDesc(FaderBehavior b) => switch (b) {
    FaderBehavior.hybrid =>
      'Touch anywhere to grab; slide for relative changes.',
    FaderBehavior.jump => 'Fader snaps instantly to your exact touch point.',
    FaderBehavior.catchUp =>
      'Ignored until you cross the physical fader position.',
  };
}

// ---------------------------------------------------------------------------
// Layout Hand
// ---------------------------------------------------------------------------

class _LayoutHandSection extends ConsumerWidget {
  const _LayoutHandSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final faderOnRight = ref.watch(
      layoutHandProvider.select((h) => h == LayoutHand.faderOnRight),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('FADER POSITION'),
        _ToggleCard(
          value: faderOnRight,
          trueLabel: 'FADER ON RIGHT',
          falseLabel: 'FADER ON LEFT',
          trueSubtitle: 'Controls on left — slide faders with right hand.',
          falseSubtitle: 'Controls on right — slide faders with left hand.',
          icon: Icons.swap_horiz,
          onToggle: () => ref.read(layoutHandProvider.notifier).toggle(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Panel Position
// ---------------------------------------------------------------------------

class _PanelPositionSection extends ConsumerWidget {
  const _PanelPositionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLeft = ref.watch(
      sidePanelProvider.select((s) => s.side == SidePanelSide.left),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('SETTINGS PANEL DOCK'),
        _ToggleCard(
          value: isLeft,
          trueLabel: 'DOCK ON LEFT',
          falseLabel: 'DOCK ON RIGHT',
          trueSubtitle: 'Settings panel appears on the left in landscape.',
          falseSubtitle: 'Settings panel appears on the right in landscape.',
          icon: Icons.dock,
          onToggle: () => ref
              .read(sidePanelProvider.notifier)
              .setSide(isLeft ? SidePanelSide.right : SidePanelSide.left),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Safety Hold
// ---------------------------------------------------------------------------

class _SafetyHoldSection extends ConsumerWidget {
  const _SafetyHoldSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duration = ref.watch(safetyHoldDurationProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('SAFETY HOLD DURATION'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorderNormal),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${duration.toStringAsFixed(1)}s',
                    style: AppText.performance(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _PillBadge(
                    label: duration >= 5.0
                        ? 'MAX'
                        : duration <= 1.0
                        ? 'MIN'
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Time required to hold a control to enter config mode.',
                style: AppText.system(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 12),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                ),
                child: Slider(
                  value: duration,
                  min: 1.0,
                  max: 5.0,
                  divisions: 40,
                  activeColor: _kAccent,
                  inactiveColor: Colors.white10,
                  onChanged: (v) =>
                      ref.read(safetyHoldDurationProvider.notifier).update(v),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Config Gesture
// ---------------------------------------------------------------------------

class _ConfigGestureSection extends ConsumerWidget {
  const _ConfigGestureSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(configGestureModeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('CONFIGURATION GESTURE'),
        _SelectionCard(
          selected: mode == ConfigGestureMode.tapHold,
          title: 'TAP-THEN-HOLD',
          subtitle: 'Hold on the second touch.',
          onTap: () => ref
              .read(configGestureModeProvider.notifier)
              .update(ConfigGestureMode.tapHold),
        ),
        const SizedBox(height: 8),
        _SelectionCard(
          selected: mode == ConfigGestureMode.doubleTapHold,
          title: 'DOUBLE-TAP-THEN-HOLD',
          subtitle: 'Hold on the third touch — safest option.',
          onTap: () => ref
              .read(configGestureModeProvider.notifier)
              .update(ConfigGestureMode.doubleTapHold),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Transport Assignments
// ---------------------------------------------------------------------------

class _TransportAssignmentsSection extends ConsumerWidget {
  const _TransportAssignmentsSection();

  static IconData _roleIcon(HeaderTransportRole role) => switch (role) {
    HeaderTransportRole.rewind => Icons.fast_rewind,
    HeaderTransportRole.up => Icons.keyboard_arrow_up,
    HeaderTransportRole.record => Icons.fiber_manual_record,
    HeaderTransportRole.left => Icons.keyboard_arrow_left,
    HeaderTransportRole.stop => Icons.stop,
    HeaderTransportRole.right => Icons.keyboard_arrow_right,
    HeaderTransportRole.fastForward => Icons.fast_forward,
    HeaderTransportRole.down => Icons.keyboard_arrow_down,
    HeaderTransportRole.play => Icons.play_arrow,
  };

  static String _describeAssignment(
    ActionPayload? payload,
  ) => switch (payload) {
    null => 'Unassigned',
    CcPayload(:final channel, :final highResolution) =>
      '${payload.displayLabel}${highResolution ? ' (14-bit)' : ''} • CH ${channel + 1}',
    NotePayload(:final channel) =>
      '${payload.displayLabel} • CH ${channel + 1}',
    _ => payload.displayLabel,
  };

  Future<void> _editRole(
    BuildContext context,
    HeaderTransportRole role,
    ActionPayload? current,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _HeaderTransportAssignmentDialog(role: role, initialPayload: current),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${role.label} assignment saved'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mappings = ref.watch(headerTransportMappingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('TRANSPORT ASSIGNMENTS'),
        for (final role in HeaderTransportRole.values)
          _TransportAssignmentCard(
            key: ValueKey('transport_assignment_${role.name}'),
            icon: _roleIcon(role),
            title: role.label,
            subtitle: _describeAssignment(mappings[role]),
            assigned: mappings[role] != null,
            accentColor: role == HeaderTransportRole.record
                ? const Color(0xFFFFB59E)
                : _kAccent,
            onTap: () => _editRole(context, role, mappings[role]),
          ),
      ],
    );
  }
}

class _TransportAssignmentCard extends StatelessWidget {
  const _TransportAssignmentCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.assigned,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool assigned;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: assigned
                    ? accentColor.withValues(alpha: 0.45)
                    : _kBorderNormal,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (assigned ? accentColor : Colors.white24).withValues(
                      alpha: 0.14,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: assigned ? accentColor : Colors.white54,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: assigned ? accentColor : Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white38,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderTransportAssignmentDialog extends ConsumerStatefulWidget {
  const _HeaderTransportAssignmentDialog({
    required this.role,
    required this.initialPayload,
  });

  final HeaderTransportRole role;
  final ActionPayload? initialPayload;

  @override
  ConsumerState<_HeaderTransportAssignmentDialog> createState() =>
      _HeaderTransportAssignmentDialogState();
}

class _HeaderTransportAssignmentDialogState
    extends ConsumerState<_HeaderTransportAssignmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final MidiActionDraft _draft;
  bool _isSaving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _draft = MidiActionDraft(
      payload: widget.initialPayload,
      allowUnassigned: true,
      ccAndNoteOnly: true,
    );
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final payload = _draft.payload;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      await ref
          .read(headerTransportMappingsProvider.notifier)
          .setAssignment(widget.role, payload);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError = 'Failed to save transport assignment.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E2024),
      title: Text(
        'Assign ${widget.role.label}',
        style: AppText.performance(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: ScrollableDialogContent(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MidiActionFields(
                draft: _draft,
                usesPitchBendPosition: false,
                supportsVariableVelocity: false,
              ),
              if (_saveError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _saveError!,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kAccent,
            foregroundColor: const Color(0xFF0C0E12),
          ),
          child: Text(_isSaving ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared card widgets
// ---------------------------------------------------------------------------

class _SelectionCard extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? _kAccent.withValues(alpha: 0.08) : _kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _kBorderSelected : _kBorderNormal,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Space Grotesk',
                      color: selected ? Colors.white : Colors.white60,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: _kAccent, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final bool value;
  final String trueLabel;
  final String falseLabel;
  final String trueSubtitle;
  final String falseSubtitle;
  final IconData icon;
  final VoidCallback onToggle;

  const _ToggleCard({
    required this.value,
    required this.trueLabel,
    required this.falseLabel,
    required this.trueSubtitle,
    required this.falseSubtitle,
    required this.icon,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorderNormal),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: _kAccent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value ? trueLabel : falseLabel,
                    style: const TextStyle(
                      fontFamily: 'Space Grotesk',
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value ? trueSubtitle : falseSubtitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: (_) => onToggle(),
              activeThumbColor: _kAccent,
              inactiveThumbColor: Colors.white24,
              inactiveTrackColor: Colors.white10,
            ),
          ],
        ),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String? label;
  const _PillBadge({this.label});

  @override
  Widget build(BuildContext context) {
    if (label == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kAccent.withValues(alpha: 0.4)),
      ),
      child: Text(
        label!,
        style: const TextStyle(
          fontFamily: 'Inter',
          color: _kAccent,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

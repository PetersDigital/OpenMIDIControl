// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/action_payload.dart';
import '../design_system.dart';
import '../midi_action_dispatcher.dart';
import '../midi_service.dart';
import '../performance_ticker_mixin.dart';

extension TransportActionPresentation on TransportAction {
  ({IconData icon, String label}) get presentation => switch (this) {
    TransportAction.play => (icon: Icons.play_arrow, label: 'Play'),
    TransportAction.stop => (icon: Icons.stop, label: 'Stop'),
    TransportAction.record => (
      icon: Icons.fiber_manual_record,
      label: 'Record',
    ),
    TransportAction.cycle => (icon: Icons.repeat, label: 'Cycle'),
    TransportAction.rewind => (icon: Icons.fast_rewind, label: 'Rewind'),
    TransportAction.fastForward => (
      icon: Icons.fast_forward,
      label: 'Fast Forward',
    ),
    TransportAction.bankLeft => (icon: Icons.skip_previous, label: 'Bank Left'),
    TransportAction.bankRight => (icon: Icons.skip_next, label: 'Bank Right'),
  };
}

class TransportButton extends ConsumerStatefulWidget {
  const TransportButton({
    super.key,
    required this.action,
    this.payload,
    this.customName,
    this.isActive = true,
  });

  final TransportAction action;
  final ActionPayload? payload;
  final String? customName;
  final bool isActive;

  @override
  ConsumerState<TransportButton> createState() => _TransportButtonState();
}

class _TransportButtonState extends ConsumerState<TransportButton>
    with PerformanceTickerMixin {
  final _gate = MidiGate.transport();
  int? _pointer;

  @override
  void initState() {
    super.initState();
    initPerformanceMixin();
  }

  @override
  void didUpdateWidget(TransportButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive || widget.payload != oldWidget.payload) _release();
  }

  @override
  void onAppLifecycleChanged(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _pointer != null) {
      setState(_release);
    }
  }

  @override
  void dispose() {
    _release();
    disposePerformanceMixin();
    super.dispose();
  }

  void _release() {
    _pointer = null;
    _gate.release();
  }

  void _handlePointerDown(PointerDownEvent event, ActionPayload payload) {
    if (_pointer != null || event.buttons != kPrimaryButton) return;
    setState(() => _pointer = event.pointer);
    _gate.press(ref.read(midiServiceProvider), payload);
  }

  void _handlePointerUp(PointerEvent event) {
    if (event.pointer == _pointer) setState(_release);
  }

  void _activate(ActionPayload payload) {
    if (_pointer != null) return;
    _gate.press(ref.read(midiServiceProvider), payload);
    _gate.release();
  }

  @override
  Widget build(BuildContext context) {
    final payload = widget.payload;
    final address = switch (payload) {
      CcPayload(:final channel, :final cc) => '$channel:$cc',
      NotePayload(:final channel, :final note) => 'note:$channel:$note',
      _ => null,
    };
    final enabled = widget.isActive && address != null && payload != null;
    final isLit =
        enabled &&
        ref.watch(
          controlStateProvider.select(
            (state) => state.buttonStates[address] ?? false,
          ),
        );
    final isPressed = _pointer != null;
    final appearance = widget.action.presentation;
    final customName = widget.customName?.trim();
    final label = customName == null || customName.isEmpty
        ? appearance.label
        : customName;
    final accent = widget.action == TransportAction.record
        ? const Color(0xFFFFB59E)
        : const Color(0xFFA6C9F8);
    final color = enabled ? accent : const Color(0xFF8B9098);

    return Semantics(
      button: true,
      label: label,
      enabled: enabled,
      selected: isLit,
      onTap: enabled ? () => _activate(payload) : null,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: enabled
                ? (event) => _handlePointerDown(event, payload)
                : null,
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerUp,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isPressed ? accent : const Color(0xFF282A2E),
                border: Border.all(
                  color: isLit ? accent : const Color(0xFF111318),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          appearance.icon,
                          size: 22,
                          color: isPressed ? const Color(0xFF111318) : color,
                        ),
                        Text(
                          label.toUpperCase(),
                          style: AppText.performance(
                            color: isPressed ? const Color(0xFF111318) : color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isLit ? accent : const Color(0xFF111318),
                          ),
                          child: const SizedBox.square(dimension: 5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

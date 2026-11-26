// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import '../../core/models/action_payload.dart';
import '../../core/models/layout_models.dart';
import '../../core/models/widget_style.dart';
import '../design_system.dart';
import 'config_gesture_wrapper.dart';

import '../midi_service.dart';
import '../midi_action_dispatcher.dart';
import '../layout_state.dart';
import '../performance_ticker_mixin.dart';
import 'control_config_modal.dart';

enum MidiButtonMode { note, cc }

ActionPayload? _buttonPayload(LayoutControl control, MidiButtonMode mode) {
  final payload = control.payload;
  if (mode == MidiButtonMode.note &&
      payload is CcPayload &&
      !payload.highResolution &&
      payload.cc == control.defaultCc &&
      payload.channel == control.channel) {
    return NotePayload(channel: payload.channel, note: payload.cc);
  }
  return payload;
}

class Trigger extends ConsumerStatefulWidget {
  final String controlId;
  final MidiButtonMode mode;
  final Color activeColor;
  final Color inactiveColor;

  const Trigger({
    super.key,
    required this.controlId,
    required this.pageId,
    this.mode = MidiButtonMode.cc,
    this.activeColor = const Color(0xFFA6C9F8),
    this.inactiveColor = const Color(0xFF282A2E),
  });

  final String pageId;

  @override
  ConsumerState<Trigger> createState() => _TriggerState();
}

class _TriggerState extends ConsumerState<Trigger>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        PerformanceTickerMixin {
  bool _isPressed = false;
  int? _activePointer;
  final _midiGate = MidiGate();

  @override
  void initState() {
    super.initState();
    initPerformanceMixin();
  }

  @override
  void onAppLifecycleChanged(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _isPressed) {
      setState(() {
        _activePointer = null;
        _isPressed = false;
      });
      _midiGate.release();
    }
  }

  @override
  void dispose() {
    _midiGate.release();
    disposePerformanceMixin();
    super.dispose();
  }

  void _handlePointerDown(PointerEvent event, ActionPayload? payload) {
    if (_isPressed) return;
    _activePointer = event.pointer;

    setState(() {
      _isPressed = true;
    });

    if (payload != null) {
      _midiGate.press(ref.read(midiServiceProvider), payload, isFinal: false);
    }
  }

  void _handlePointerUp(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    setState(() {
      _isPressed = false;
    });

    _midiGate.release();
  }

  @override
  Widget build(BuildContext context) {
    final control = ref.watch(
      layoutStateProvider.select((s) {
        final page = s.pages.firstWhereOrNull((p) => p.id == widget.pageId);
        if (page == null) return null;
        return page.controls.firstWhereOrNull((c) => c.id == widget.controlId);
      }),
    );

    if (control == null) return const SizedBox.shrink();

    final isLocked = ref.watch(
      layoutStateProvider.select((s) => s.isPerformanceLocked),
    );
    final channel = control.payload?.midiChannel ?? control.channel;
    final identifier = control.defaultCc;
    final payload = _buttonPayload(control, widget.mode);
    final isUnassigned = identifier == -1 && payload == null;
    final label = control.displayName;

    return RepaintBoundary(
      child: Listener(
        onPointerDown: isUnassigned
            ? null
            : (e) => _handlePointerDown(e, payload),
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerUp,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: isUnassigned ? 0.3 : 1.0,
          child: _MidiButtonFace(
            wrapperKey: ValueKey('config_wrapper_trigger_${control.id}'),
            configId: 'trigger_${control.id}',
            onConfigRequested: isLocked
                ? null
                : () => showUtilityConfigModal(context, ref, control.id),
            isLit: _isPressed,
            activeColor: widget.activeColor,
            inactiveColor: widget.inactiveColor,
            defaultActiveFg: const Color(0xFF033258),
            duration: const Duration(milliseconds: 50),
            style: control.effectiveStyle,
            headerText: isUnassigned
                ? 'UNASSIGNED'
                : control.payload?.displayLabel ?? 'CC $identifier',
            label: label,
            channelText: isUnassigned ? null : 'CH${channel + 1}',
          ),
        ),
      ),
    );
  }
}

Future<void> showUtilityConfigModal(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  await showDialog(
    context: context,
    builder: (context) =>
        ControlConfigModal(controlId: id, displayNameLabel: 'Control Name'),
  );
}

class Toggle extends ConsumerStatefulWidget {
  final String controlId;
  final MidiButtonMode mode;
  final Color activeColor;
  final Color inactiveColor;

  const Toggle({
    super.key,
    required this.controlId,
    required this.pageId,
    this.mode = MidiButtonMode.cc,
    this.activeColor = const Color(0xFFFFB59E), // Distinct color for toggles
    this.inactiveColor = const Color(0xFF282A2E),
  });

  final String pageId;

  @override
  ConsumerState<Toggle> createState() => _ToggleState();
}

class _ToggleState extends ConsumerState<Toggle>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        PerformanceTickerMixin {
  bool _isActive = false;
  bool _isPressed = false;
  int? _activePointer;
  final _midiGate = MidiGate();

  @override
  void initState() {
    super.initState();
    initPerformanceMixin();
  }

  @override
  void dispose() {
    if (_midiGate.heldPayload is NotePayload) {
      _midiGate.release();
    }
    disposePerformanceMixin();
    super.dispose();
  }

  void _handlePointerDown(PointerEvent event) {
    if (_isPressed) return;
    _activePointer = event.pointer;

    setState(() {
      _isPressed = true;
    });
  }

  void _handlePointerUp(PointerEvent event, ActionPayload? payload) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;

    _toggleState(payload);

    setState(() {
      _isPressed = false;
    });
  }

  void _toggleState(ActionPayload? payload) {
    setState(() => _isActive = !_isActive);

    if (_isActive && payload != null) {
      _midiGate.press(ref.read(midiServiceProvider), payload);
    } else if (!_isActive) {
      _midiGate.release(relativeOnRelease: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final control = ref.watch(
      layoutStateProvider.select((s) {
        final page = s.pages.firstWhereOrNull((p) => p.id == widget.pageId);
        if (page == null) return null;
        return page.controls.firstWhereOrNull((c) => c.id == widget.controlId);
      }),
    );

    if (control == null) return const SizedBox.shrink();

    final isLocked = ref.watch(
      layoutStateProvider.select((s) => s.isPerformanceLocked),
    );
    final channel = control.payload?.midiChannel ?? control.channel;
    final identifier = control.defaultCc;
    final payload = _buttonPayload(control, widget.mode);
    final isUnassigned = identifier == -1 && payload == null && !_isActive;
    final label = control.displayName;

    return RepaintBoundary(
      child: Listener(
        onPointerDown: isUnassigned ? null : _handlePointerDown,
        onPointerUp: (e) => _handlePointerUp(e, payload),
        onPointerCancel: (e) => _handlePointerUp(e, payload),
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: isUnassigned ? 0.3 : 1.0,
          child: _MidiButtonFace(
            wrapperKey: ValueKey('config_wrapper_toggle_${control.id}'),
            configId: 'toggle_${control.id}',
            onConfigRequested: isLocked
                ? null
                : () => showUtilityConfigModal(context, ref, control.id),
            isLit: _isActive,
            activeColor: widget.activeColor,
            inactiveColor: widget.inactiveColor,
            defaultActiveFg: const Color(0xFF690005),
            duration: const Duration(milliseconds: 150),
            style: control.effectiveStyle,
            headerText: isUnassigned
                ? 'UNASSIGNED'
                : control.payload?.displayLabel ?? 'CC $identifier',
            label: label,
            channelText: isUnassigned ? null : 'CH${channel + 1}',
          ),
        ),
      ),
    );
  }
}

class _MidiButtonFace extends StatelessWidget {
  final Key wrapperKey;
  final String configId;
  final VoidCallback? onConfigRequested;
  final bool isLit;
  final Color activeColor;
  final Color inactiveColor;
  final Color defaultActiveFg;
  final Duration duration;
  final WidgetStyle style;
  final String headerText;
  final String label;
  final String? channelText;

  const _MidiButtonFace({
    required this.wrapperKey,
    required this.configId,
    required this.onConfigRequested,
    required this.isLit,
    required this.activeColor,
    required this.inactiveColor,
    required this.defaultActiveFg,
    required this.duration,
    required this.style,
    required this.headerText,
    required this.label,
    required this.channelText,
  });

  @override
  Widget build(BuildContext context) {
    final Color? customAccent = style.accentColorValue != null
        ? Color(style.accentColorValue!)
        : null;
    final Color activeBg = customAccent ?? activeColor;
    final Color activeFg = customAccent != null
        ? (ThemeData.estimateBrightnessForColor(customAccent) ==
                  Brightness.light
              ? const Color(0xFF0C0E12)
              : Colors.white)
        : defaultActiveFg;
    final String? fontFamily = style.fontFamily;

    return AnimatedContainer(
      duration: duration,
      decoration: BoxDecoration(
        color: isLit ? activeBg : inactiveColor,
        borderRadius: BorderRadius.zero,
        border: Border.all(
          color: isLit ? activeBg : const Color(0xFF111318),
          width: 1.0,
        ),
      ),
      child: Stack(
        children: [
          _ButtonHeaderLabel(
            wrapperKey: wrapperKey,
            configId: configId,
            onConfigRequested: onConfigRequested,
            text: headerText,
            visible: style.showNumericReadout,
            fontFamily: fontFamily,
            color: isLit
                ? activeFg.withValues(alpha: 0.6)
                : const Color(0xFFC3C7CA).withValues(alpha: 0.3),
          ),
          if (style.showLabel)
            Center(
              child: Container(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppText.performance(
                      color: isLit ? activeFg : const Color(0xFFC3C7CA),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ).copyWith(fontFamily: fontFamily),
                  ),
                ),
              ),
            ),
          _ButtonFooterRow(
            statusText: isLit ? 'ON' : 'OFF',
            statusColor: isLit
                ? activeFg
                : const Color(0xFFC3C7CA).withValues(alpha: 0.3),
            channelText: style.showNumericReadout ? channelText : null,
            channelColor: isLit
                ? activeFg.withValues(alpha: 0.6)
                : const Color(0xFFC3C7CA).withValues(alpha: 0.3),
            fontFamily: fontFamily,
          ),
        ],
      ),
    );
  }
}

class _ButtonHeaderLabel extends StatelessWidget {
  final Key wrapperKey;
  final String configId;
  final VoidCallback? onConfigRequested;
  final String text;
  final bool visible;
  final String? fontFamily;
  final Color color;

  const _ButtonHeaderLabel({
    required this.wrapperKey,
    required this.configId,
    required this.onConfigRequested,
    required this.text,
    required this.visible,
    required this.fontFamily,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ConfigGestureWrapper(
        key: wrapperKey,
        id: configId,
        onConfigRequested: onConfigRequested,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.topLeft,
          child: visible
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.topLeft,
                  child: Text(
                    text,
                    style: AppText.performance(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ).copyWith(fontFamily: fontFamily),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _ButtonFooterRow extends StatelessWidget {
  final String statusText;
  final Color statusColor;
  final String? channelText;
  final Color channelColor;
  final String? fontFamily;

  const _ButtonFooterRow({
    required this.statusText,
    required this.statusColor,
    required this.channelText,
    required this.channelColor,
    required this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 4,
      left: 4,
      right: 4,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                statusText,
                style: TextStyle(
                  fontFamily: fontFamily ?? 'Space Grotesk',
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (channelText != null) ...[
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  channelText!,
                  style: TextStyle(
                    fontFamily: fontFamily ?? 'Space Grotesk',
                    color: channelColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

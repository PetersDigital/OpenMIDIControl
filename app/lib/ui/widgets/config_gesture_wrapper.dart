// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../midi_settings_state.dart';
import '../providers/config_ui_provider.dart';

class ConfigGestureWrapper extends ConsumerStatefulWidget {
  final String id;
  final Widget child;
  final VoidCallback onConfigRequested;
  final VoidCallback? onRenameRequested;
  final bool isDragging;
  final HitTestBehavior behavior;

  const ConfigGestureWrapper({
    super.key,
    required this.id,
    required this.child,
    required this.onConfigRequested,
    this.onRenameRequested,
    this.isDragging = false,
    this.behavior = HitTestBehavior.translucent,
  });

  @override
  ConsumerState<ConfigGestureWrapper> createState() =>
      _ConfigGestureWrapperState();
}

class _ConfigGestureWrapperState extends ConsumerState<ConfigGestureWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  // Gesture State
  DateTime? _lastTapTime;
  int _tapCount = 0;
  Timer? _configTimer;
  Timer? _tapResetTimer;
  bool _isDown = false;
  Offset? _initialPointerPos;
  int? _activePointerId;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this);
    _progressController.addListener(() {
      if (!mounted) return;
      // Use microtask to avoid "modifying during build" errors if listener
      // is triggered during a lifecycle transition
      Future.microtask(() {
        if (mounted) {
          ref
              .read(configProgressProvider.notifier)
              .update(_progressController.value);
        }
      });
    });
  }

  @override
  void didUpdateWidget(covariant ConfigGestureWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isDragging && widget.isDragging) {
      // If we started dragging performance controls, immediately cancel any pending config
      _stopConfigTimer();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _configTimer?.cancel();
    _tapResetTimer?.cancel();
    // Ensure we don't leave a ghost progress bar if disposed during hold
    Future.microtask(() {
      if (mounted) {
        ref.read(configProgressProvider.notifier).reset();
      }
    });
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    // HARDENING: Prevent multi-touch interference.
    // If a finger is already down, ignore new touches for configuration triggers.
    // This stops "flams" or simultaneous performance hits from triggering the menu.
    if (_isDown || widget.isDragging) return;

    final now = DateTime.now();
    final timeSinceLastTap = _lastTapTime != null
        ? now.difference(_lastTapTime!)
        : const Duration(seconds: 999);

    setState(() {
      _isDown = true;
      _activePointerId = event.pointer;
      _initialPointerPos = event.localPosition;
    });

    final mode = ref.read(configGestureModeProvider);

    // Tap sequence logic: strictly serial double-tap detection
    if (_tapCount == 0 || (timeSinceLastTap.inMilliseconds > 600)) {
      _tapCount = 1;
      _tapResetTimer?.cancel();
      _tapResetTimer = Timer(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _tapCount = 0);
      });

      // If in single-tap mode, start the timer immediately
      if (mode == ConfigGestureMode.tapHold) {
        _startConfigTimer();
      }
    } else if (_tapCount == 1 && timeSinceLastTap.inMilliseconds < 400) {
      if (mode == ConfigGestureMode.doubleTapHold) {
        _tapCount = 2;
        _tapResetTimer?.cancel();

        // RENAME GESTURE: Quick double-tap (within 400ms) triggers rename immediately
        if (widget.onRenameRequested != null) {
          widget.onRenameRequested!();
          _tapCount = 0; // Reset after rename action
          return;
        }

        _startConfigTimer();
      }
    } else {
      // Excessive taps or too slow - reset
      _tapCount = 0;
      _stopConfigTimer();
    }

    _lastTapTime = now;
  }

  void _startConfigTimer() {
    final holdDuration = ref.read(safetyHoldDurationProvider);
    final duration = Duration(milliseconds: (holdDuration * 1000).toInt());

    _progressController.duration = duration;
    _progressController.forward(from: 0.0);

    _configTimer?.cancel();
    _configTimer = Timer(duration, () {
      // Final validation before triggering: finger must still be down,
      // and we must not be dragging a performance control.
      if (!_isDown || widget.isDragging || !mounted) return;

      setState(() {
        _isDown = false;
        _progressController.reset();
      });
      Future.microtask(() => ref.read(configProgressProvider.notifier).reset());
      _tapCount = 0;
      widget.onConfigRequested();
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointerId || _initialPointerPos == null) return;

    // HARDENING: Cumulative distance threshold.
    // If the finger moves more than 15 pixels from the INITIAL touch point,
    // it's considered a deliberate movement (performance gesture) and cancels the config trigger.
    final distance = (event.localPosition - _initialPointerPos!).distance;
    if (distance > 15) {
      _stopConfigTimer();
    }
  }

  void _stopConfigTimer() {
    if (!mounted) return;
    setState(() {
      _progressController.reset();
      _configTimer?.cancel();
    });
    Future.microtask(() {
      if (mounted) {
        ref.read(configProgressProvider.notifier).reset();
      }
    });
  }

  void _handlePointerUpCancel() {
    setState(() {
      _isDown = false;
      _activePointerId = null;
      _initialPointerPos = null;
    });
    _stopConfigTimer();
  }

  @override
  Widget build(BuildContext context) {
    // If it's the first tap of a potential sequence, we want it to pass through
    // to the parent performance widget (fader/encoder).
    // Subsequent taps (like the second tap of a double-tap-hold) should be
    // intercepted to handle the config loading and prevent accidental underlying hits.
    final shouldIntercept = _tapCount > 0;

    return GestureDetector(
      // We only provide handlers if we want to intercept, otherwise we let the
      // event bubble up to the performance widgets.
      onTap: shouldIntercept ? () {} : null,
      onDoubleTap: shouldIntercept ? () {} : null,
      onLongPress: shouldIntercept ? () {} : null,
      behavior: shouldIntercept
          ? HitTestBehavior.opaque
          : HitTestBehavior.translucent,
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: (_) => _handlePointerUpCancel(),
        onPointerCancel: (_) => _handlePointerUpCancel(),
        behavior: widget.behavior,
        child: widget.child,
      ),
    );
  }
}

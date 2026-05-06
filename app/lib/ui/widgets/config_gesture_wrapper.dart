// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../midi_settings_state.dart';
import '../providers/config_ui_provider.dart';

const int _kMaxDoubleTapGapMs = 600;
const int _kMaxDoubleTapSpeedMs = 400;
const double _kMaxPanDistanceThreshold = 15.0;

class ConfigGestureWrapper extends ConsumerStatefulWidget {
  final String id;
  final Widget child;
  final VoidCallback? onConfigRequested;
  final VoidCallback? onRenameRequested;
  final HitTestBehavior behavior;

  const ConfigGestureWrapper({
    super.key,
    required this.id,
    required this.child,
    this.onConfigRequested,
    this.onRenameRequested,
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
  final Stopwatch _tapStopwatch = Stopwatch();
  int _lastTapElapsedMs = 0;
  int _tapCount = 0;
  Timer? _configTimer;
  Timer? _tapResetTimer;
  bool _isDown = false;
  Offset? _initialPointerPos;
  int? _activePointerId;

  @override
  void initState() {
    super.initState();
    _tapStopwatch.start();
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
    if (_isDown) return;

    // If no callbacks are provided, don't track taps at all to avoid stealing gestures
    if (widget.onConfigRequested == null && widget.onRenameRequested == null) {
      return;
    }

    final currentElapsed = _tapStopwatch.elapsedMilliseconds;
    final int timeSinceLastTap = _lastTapElapsedMs > 0
        ? currentElapsed - _lastTapElapsedMs
        : 999999;

    setState(() {
      _isDown = true;
      _activePointerId = event.pointer;
      _initialPointerPos = event.localPosition;
    });

    final mode = ref.read(configGestureModeProvider);

    // Tap sequence logic: strictly serial double-tap detection
    if (_tapCount == 0 || (timeSinceLastTap > _kMaxDoubleTapGapMs)) {
      _tapCount = 1;
      _tapResetTimer?.cancel();
      _tapResetTimer = Timer(
        const Duration(milliseconds: _kMaxDoubleTapGapMs),
        () {
          if (mounted) setState(() => _tapCount = 0);
        },
      );

      // If in single-tap mode, start the timer immediately if we have a callback
      if (mode == ConfigGestureMode.tapHold &&
          (widget.onConfigRequested != null ||
              widget.onRenameRequested != null)) {
        _startConfigTimer();
      }
    } else if (_tapCount == 1 && timeSinceLastTap < _kMaxDoubleTapSpeedMs) {
      if (mode == ConfigGestureMode.doubleTapHold) {
        _tapCount = 2;
        _tapResetTimer?.cancel();

        // RENAME GESTURE: Quick double-tap (within 400ms) triggers rename immediately
        if (widget.onRenameRequested != null) {
          widget.onRenameRequested!();
          _tapCount = 0; // Reset after rename action
          return;
        }

        if (widget.onConfigRequested != null ||
            widget.onRenameRequested != null) {
          _startConfigTimer();
        }
      }
    } else {
      // Excessive taps or too slow - reset
      _tapCount = 0;
      _stopConfigTimer();
    }

    _lastTapElapsedMs = currentElapsed;
  }

  void _startConfigTimer() {
    final holdDuration = ref.read(safetyHoldDurationProvider);
    final duration = Duration(milliseconds: (holdDuration * 1000).toInt());

    _progressController.duration = duration;
    _progressController.forward(from: 0.0);

    _configTimer?.cancel();
    _configTimer = Timer(duration, () {
      // Final validation before triggering: finger must still be down.
      // (The max pan distance threshold handles preventing trigger on drag).
      if (!_isDown || !mounted) return;

      setState(() {
        _isDown = false;
        _progressController.reset();
      });
      Future.microtask(() => ref.read(configProgressProvider.notifier).reset());
      _tapCount = 0;
      if (widget.onConfigRequested != null) {
        widget.onConfigRequested!();
      }
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointerId || _initialPointerPos == null) return;

    // HARDENING: Cumulative distance threshold.
    // If the finger moves more than _kMaxPanDistanceThreshold pixels from the INITIAL touch point,
    // it's considered a deliberate movement (performance gesture) and cancels the config trigger.
    final distance = (event.localPosition - _initialPointerPos!).distance;
    if (distance > _kMaxPanDistanceThreshold) {
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
    final hasCallbacks =
        widget.onConfigRequested != null || widget.onRenameRequested != null;
    final shouldIntercept = _tapCount > 0 && hasCallbacks;

    return GestureDetector(
      // We only provide handlers if we want to intercept, otherwise we let the
      // event bubble up to the performance widgets.
      onTap: shouldIntercept ? () {} : null,
      onDoubleTap: shouldIntercept ? () {} : null,
      onLongPress: shouldIntercept ? () {} : null,
      // Intercept pan gestures to prevent the underlying fader from moving
      // while the user is attempting a double-tap-and-hold config gesture.
      onPanStart: shouldIntercept ? (_) {} : null,
      onPanUpdate: shouldIntercept ? (_) {} : null,
      onPanEnd: shouldIntercept ? (_) {} : null,
      onPanCancel: shouldIntercept ? () {} : null,
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

// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../midi_settings_state.dart';

class DelayedMenuTrigger extends ConsumerStatefulWidget {
  final Widget child;
  final VoidCallback onTrigger;
  final Color? feedbackColor;

  const DelayedMenuTrigger({
    super.key,
    required this.child,
    required this.onTrigger,
    this.feedbackColor = Colors.white,
  });

  @override
  ConsumerState<DelayedMenuTrigger> createState() => _DelayedMenuTriggerState();
}

class _DelayedMenuTriggerState extends ConsumerState<DelayedMenuTrigger>
    with TickerProviderStateMixin {
  Timer? _timer;
  Timer? _tapResetTimer;
  bool _isHolding = false;
  late AnimationController _progressController;

  // Gesture state
  DateTime? _lastTapTime;
  int _tapCount = 0;
  bool _isTapHoldCandidate = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tapResetTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    final now = DateTime.now();
    final timeSinceLastTap = _lastTapTime != null
        ? now.difference(_lastTapTime!)
        : const Duration(seconds: 1);

    final mode = ref.read(configGestureModeProvider);

    if (mode == ConfigGestureMode.doubleTapHold) {
      _isTapHoldCandidate =
          _tapCount >= 2 && timeSinceLastTap.inMilliseconds < 400;
    } else {
      _isTapHoldCandidate = timeSinceLastTap.inMilliseconds < 400;
    }

    if (_isTapHoldCandidate) {
      _startHold();
    }
  }

  void _startHold() {
    final durationSecs = ref.read(safetyHoldDurationProvider);
    final duration = Duration(milliseconds: (durationSecs * 1000).toInt());

    setState(() => _isHolding = true);
    _progressController.duration = duration;
    _progressController.forward(from: 0);
    _timer = Timer(duration, () {
      if (_isHolding) {
        widget.onTrigger();
        _stopHold();
      }
    });
  }

  void _stopHold() {
    _timer?.cancel();
    _timer = null;
    if (mounted) {
      setState(() => _isHolding = false);
      _progressController.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _lastTapTime = DateTime.now();
        _tapCount++;
        _tapResetTimer?.cancel();
        _tapResetTimer = Timer(const Duration(milliseconds: 600), () {
          _tapCount = 0;
        });
      },
      onTapDown: _handleTapDown,
      onTapUp: (_) => _stopHold(),
      onTapCancel: () => _stopHold(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          if (_isHolding)
            AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    value: _progressController.value,
                    strokeWidth: 2,
                    color: widget.feedbackColor?.withValues(alpha: 0.8),
                    backgroundColor: widget.feedbackColor?.withValues(
                      alpha: 0.1,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

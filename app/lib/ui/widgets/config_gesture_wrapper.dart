// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../midi_settings_state.dart';

class ConfigGestureWrapper extends ConsumerStatefulWidget {
  final String id;
  final Widget child;
  final VoidCallback onConfigRequested;
  final bool isDragging;
  final HitTestBehavior behavior;

  const ConfigGestureWrapper({
    super.key,
    required this.id,
    required this.child,
    required this.onConfigRequested,
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

  DateTime? _lastTapTime;
  int _tapCount = 0;
  bool _isTapHoldCandidate = false;
  bool _isLongHold = false;
  Timer? _configTimer;
  Timer? _tapResetTimer;
  bool _isDown = false;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(covariant ConfigGestureWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isDragging && widget.isDragging) {
      // If we started dragging while a config was pending, cancel it
      setState(() {
        _isTapHoldCandidate = false;
        _isDown = false;
        _progressController.reset();
        _configTimer?.cancel();
      });
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _configTimer?.cancel();
    _tapResetTimer?.cancel();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.isDragging) return;

    final now = DateTime.now();
    final timeSinceLastTap = _lastTapTime != null
        ? now.difference(_lastTapTime!)
        : const Duration(seconds: 1);

    final mode = ref.read(configGestureModeProvider);

    if (mode == ConfigGestureMode.doubleTapHold) {
      _isTapHoldCandidate =
          _tapCount == 1 && timeSinceLastTap.inMilliseconds < 400;
    } else {
      // Single tap-hold mode: Trigger on first touch (Long Press behavior)
      _isTapHoldCandidate = true;
    }

    setState(() {
      _isDown = true;
      _isLongHold = false;
    });

    if (_isTapHoldCandidate) {
      final holdDuration = ref.read(safetyHoldDurationProvider);
      final duration = Duration(milliseconds: (holdDuration * 1000).toInt());

      _progressController.duration = duration;
      _progressController.forward(from: 0.0);

      _configTimer = Timer(duration, () {
        if (!_isDown || widget.isDragging) return;

        setState(() {
          _isLongHold = true;
          _isDown = false;
          _isTapHoldCandidate = false;
          _progressController.reset();
        });
        _tapCount = 0;
        widget.onConfigRequested();
      });
    }

    _lastTapTime = now;
    _tapCount++;
    _tapResetTimer?.cancel();
    _tapResetTimer = Timer(const Duration(milliseconds: 600), () {
      _tapCount = 0;
    });
  }

  void _handlePointerUpCancel() {
    setState(() {
      _isDown = false;
      _isTapHoldCandidate = false;
      _progressController.reset();
      _configTimer?.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: (_) => _handlePointerUpCancel(),
      onPointerCancel: (_) => _handlePointerUpCancel(),
      behavior: widget.behavior,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          if (_isDown &&
              !_isLongHold &&
              !widget.isDragging &&
              _isTapHoldCandidate)
            AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: _progressController.value,
                    strokeWidth: 4,
                    color: Colors.white.withValues(alpha: 0.6),
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

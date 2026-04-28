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
  Timer? _configTimer;
  Timer? _tapResetTimer;
  bool _isDown = false;

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
      // If we started dragging while a config was pending, cancel it
      setState(() {
        _isTapHoldCandidate = false;
        _isDown = false;
        _progressController.reset();
        _configTimer?.cancel();
      });
      // Defer provider modification to avoid errors during didUpdateWidget
      Future.microtask(() => ref.read(configProgressProvider.notifier).reset());
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _configTimer?.cancel();
    _tapResetTimer?.cancel();
    // Ensure we don't leave a ghost progress bar if disposed during hold
    Future.microtask(() => ref.read(configProgressProvider.notifier).reset());
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
    });

    if (_isTapHoldCandidate) {
      final holdDuration = ref.read(safetyHoldDurationProvider);
      final duration = Duration(milliseconds: (holdDuration * 1000).toInt());

      _progressController.duration = duration;
      _progressController.forward(from: 0.0);

      _configTimer = Timer(duration, () {
        if (!_isDown || widget.isDragging) return;

        setState(() {
          _isDown = false;
          _isTapHoldCandidate = false;
          _progressController.reset();
        });
        Future.microtask(
          () => ref.read(configProgressProvider.notifier).reset(),
        );
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
    Future.microtask(() => ref.read(configProgressProvider.notifier).reset());
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Intercept all major gestures to prevent them from reaching parent performance widgets
      onTap: () {},
      onDoubleTap: () {},
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (_) {},
      onHorizontalDragStart: (_) {},
      onHorizontalDragUpdate: (_) {},
      onLongPress: () {},
      behavior: HitTestBehavior.opaque,
      child: Listener(
        onPointerDown: _handlePointerDown,
        onPointerUp: (_) => _handlePointerUpCancel(),
        onPointerCancel: (_) => _handlePointerUpCancel(),
        behavior: widget.behavior,
        child: Stack(alignment: Alignment.center, children: [widget.child]),
      ),
    );
  }
}

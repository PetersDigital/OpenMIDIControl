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
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  bool _isHolding = false;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    final durationSecs = ref.read(safetyHoldDurationProvider);
    _progressController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (durationSecs * 1000).toInt()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressController.dispose();
    super.dispose();
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
      onPanDown: (_) => _startHold(),
      onPanEnd: (_) => _stopHold(),
      onPanCancel: () => _stopHold(),
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

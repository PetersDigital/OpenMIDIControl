// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';
import 'package:flutter/material.dart';

class DelayedMenuTrigger extends StatefulWidget {
  final Widget child;
  final VoidCallback onTrigger;
  final Duration delay;
  final Color? feedbackColor;

  const DelayedMenuTrigger({
    super.key,
    required this.child,
    required this.onTrigger,
    this.delay = const Duration(seconds: 3),
    this.feedbackColor = Colors.white,
  });

  @override
  State<DelayedMenuTrigger> createState() => _DelayedMenuTriggerState();
}

class _DelayedMenuTriggerState extends State<DelayedMenuTrigger>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  bool _isHolding = false;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: widget.delay,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _startHold() {
    setState(() => _isHolding = true);
    _progressController.forward(from: 0);
    _timer = Timer(widget.delay, () {
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

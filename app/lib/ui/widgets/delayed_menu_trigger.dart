// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config_gesture_wrapper.dart';

class DelayedMenuTrigger extends ConsumerStatefulWidget {
  final String id;
  final Widget child;
  final VoidCallback onTrigger;
  final Color? feedbackColor;

  const DelayedMenuTrigger({
    super.key,
    required this.id,
    required this.child,
    required this.onTrigger,
    this.feedbackColor = Colors.white,
  });

  @override
  ConsumerState<DelayedMenuTrigger> createState() => _DelayedMenuTriggerState();
}

class _DelayedMenuTriggerState extends ConsumerState<DelayedMenuTrigger> {
  @override
  Widget build(BuildContext context) {
    return ConfigGestureWrapper(
      id: widget.id,
      onConfigRequested: widget.onTrigger,
      child: widget.child,
    );
  }
}

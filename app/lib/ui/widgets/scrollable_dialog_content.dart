// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';

class ScrollableDialogContent extends StatefulWidget {
  final Widget child;
  final ScrollController? controller;
  final bool thumbVisibility;
  final bool trackVisibility;
  final EdgeInsetsGeometry padding;

  const ScrollableDialogContent({
    super.key,
    required this.child,
    this.controller,
    this.thumbVisibility = true,
    this.trackVisibility = true,
    this.padding = const EdgeInsets.only(right: 4.0),
  });

  @override
  State<ScrollableDialogContent> createState() =>
      _ScrollableDialogContentState();
}

class _ScrollableDialogContentState extends State<ScrollableDialogContent> {
  late final ScrollController _scrollController;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _scrollController = widget.controller!;
      _ownsController = false;
    } else {
      _scrollController = ScrollController();
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: widget.thumbVisibility,
      trackVisibility: widget.trackVisibility,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );
  }
}

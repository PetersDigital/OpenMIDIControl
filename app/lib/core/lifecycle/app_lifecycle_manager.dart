// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppLifecycleStateNotifier extends Notifier<AppLifecycleState> {
  late final AppLifecycleListener _listener;

  @override
  AppLifecycleState build() {
    _listener = AppLifecycleListener(
      onStateChange: (state) {
        this.state = state;
      },
    );

    ref.onDispose(() {
      _listener.dispose();
    });

    return AppLifecycleState.resumed;
  }
}

final appLifecycleStateProvider =
    NotifierProvider<AppLifecycleStateNotifier, AppLifecycleState>(
      AppLifecycleStateNotifier.new,
    );

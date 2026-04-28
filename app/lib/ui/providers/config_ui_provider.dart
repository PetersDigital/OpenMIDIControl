// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConfigProgressNotifier extends Notifier<double> {
  @override
  double build() => 0.0;

  void update(double progress) {
    state = progress;
  }

  void reset() {
    state = 0.0;
  }
}

final configProgressProvider = NotifierProvider<ConfigProgressNotifier, double>(
  ConfigProgressNotifier.new,
);

// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final globalUiScaleProvider =
    AsyncNotifierProvider<GlobalUiScaleNotifier, double>(
      GlobalUiScaleNotifier.new,
    );

class GlobalUiScaleNotifier extends AsyncNotifier<double> {
  static const storageKey = 'globalUiScale';
  static const minScale = 0.75;
  static const maxScale = 1.35;
  static const defaultScale = 1.0;

  Future<void> _writes = Future<void>.value();

  static double _normalize(Object? value) => value is num && value.isFinite
      ? value.clamp(minScale, maxScale).toDouble()
      : defaultScale;

  @override
  Future<double> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return _normalize(prefs.get(storageKey));
    } on Exception {
      return defaultScale;
    }
  }

  Future<void> setScale(double scale) {
    final next = _normalize(scale);
    final write = _writes.then((_) async {
      await future;
      if (!ref.mounted) return;
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted) return;
      if (!await prefs.setDouble(storageKey, next)) {
        throw StateError('Failed to save the grid scale.');
      }
      if (ref.mounted) state = AsyncData(next);
    });
    _writes = write.catchError((Object _) {});
    return write;
  }
}

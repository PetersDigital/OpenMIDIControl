// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/ui/widgets/config_gesture_wrapper.dart';
import 'package:app/ui/midi_settings_state.dart';

void main() {
  group('ConfigGestureWrapper', () {
    testWidgets('triggers onConfigRequested on long press when single tap mode', (
      tester,
    ) async {
      bool requested = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            configGestureModeProvider.overrideWith(() {
              final notifier = ConfigGestureModeNotifier();
              // In tests, we need to defer the update if it relies on being initialized
              return notifier;
            }),
            safetyHoldDurationProvider.overrideWith(
              () => SafetyHoldDurationNotifier(),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  // Explicitly set the value to tapHold inside the builder
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref
                        .read(configGestureModeProvider.notifier)
                        .update(ConfigGestureMode.tapHold);
                    ref.read(safetyHoldDurationProvider.notifier).update(0.1);
                  });
                  return ConfigGestureWrapper(
                    id: 'test',
                    onConfigRequested: () => requested = true,
                    child: Container(
                      width: 100,
                      height: 100,
                      color: Colors.blue,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.longPress(find.byType(ConfigGestureWrapper));
      await tester.pump(
        const Duration(milliseconds: 200),
      ); // allow time for timer

      expect(requested, isTrue);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/ui/open_midi_screen.dart';
import 'package:app/ui/hybrid_touch_fader.dart';

void main() {
  testWidgets('Main UI renders without overflow', (WidgetTester tester) async {
    // 1. Set the test environment to a standard mobile portrait size (e.g., 1080x2400 at 3.0 pixel ratio)
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    // 2. Pump the widget
    await tester.pumpWidget(
      const ProviderScope( // Since Jules is using Riverpod
        child: MaterialApp(home: OpenMIDIMainScreen()),
      ),
    );

    // 3. Verify it builds without throwing RenderFlex errors
    expect(find.byType(HybridTouchFader), findsNWidgets(2));

    // 4. CRITICAL: Reset the view so it doesn't bleed into other tests
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}

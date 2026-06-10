// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/ui/layout_state.dart';

void main() {
  group('LayoutStateNotifier - updateControlSpatialData', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('resizing left fader wider pushes and shrinks right fader', () {
      final notifier = container.read(layoutStateProvider.notifier);

      // Initial state of Fader page:
      // Fader 0: x: 0, y: 0, width: 4, height: 4
      // Fader 1: x: 4, y: 0, width: 4, height: 4
      var state = container.read(layoutStateProvider);
      var page = state.pages.firstWhere((p) => p.id == 'page_0');
      expect(page.controls[0].id, 'fader_0');
      expect(page.controls[0].x, 0);
      expect(page.controls[0].width, 4);

      expect(page.controls[1].id, 'fader_1');
      expect(page.controls[1].x, 4);
      expect(page.controls[1].width, 4);

      // Resize Fader 0 from width 4 to 5
      notifier.updateControlSpatialData('page_0', 'fader_0', width: 5);

      state = container.read(layoutStateProvider);
      page = state.pages.firstWhere((p) => p.id == 'page_0');

      // Fader 0 should be width 5
      expect(page.controls[0].x, 0);
      expect(page.controls[0].width, 5);

      // Fader 1 should be pushed to x: 5, width: 3
      expect(page.controls[1].x, 5);
      expect(page.controls[1].width, 3);

      // Resize Fader 0 from width 5 to 6
      notifier.updateControlSpatialData('page_0', 'fader_0', width: 6);

      state = container.read(layoutStateProvider);
      page = state.pages.firstWhere((p) => p.id == 'page_0');

      expect(page.controls[0].width, 6);
      expect(page.controls[1].x, 6);
      expect(page.controls[1].width, 2);

      // Resize Fader 0 from width 6 to 7 -> should be blocked because Fader 1 would shrink below 2 (its minimum width)
      notifier.updateControlSpatialData('page_0', 'fader_0', width: 7);

      state = container.read(layoutStateProvider);
      page = state.pages.firstWhere((p) => p.id == 'page_0');

      // Values should remain at width 6
      expect(page.controls[0].width, 6);
      expect(page.controls[1].x, 6);
      expect(page.controls[1].width, 2);
    });

    test('resizing left fader narrower stretches right fader left', () {
      final notifier = container.read(layoutStateProvider.notifier);

      // First resize wider so they touch at 5
      notifier.updateControlSpatialData('page_0', 'fader_0', width: 5);

      // Then resize narrower to width 3
      notifier.updateControlSpatialData('page_0', 'fader_0', width: 3);

      final state = container.read(layoutStateProvider);
      final page = state.pages.firstWhere((p) => p.id == 'page_0');

      // Fader 0 should be width 3
      expect(page.controls[0].x, 0);
      expect(page.controls[0].width, 3);

      // Fader 1 should stretch left to x: 3, width: 5
      expect(page.controls[1].x, 3);
      expect(page.controls[1].width, 5);
    });

    test('resizing left fader wider with height passed (unchanged) works', () {
      final notifier = container.read(layoutStateProvider.notifier);

      // Resize Fader 0 from width 4 to 5, passing height: 4 (unchanged)
      notifier.updateControlSpatialData(
        'page_0',
        'fader_0',
        width: 5,
        height: 4,
      );

      final state = container.read(layoutStateProvider);
      final page = state.pages.firstWhere((p) => p.id == 'page_0');

      // Fader 0 should be width 5
      expect(page.controls[0].x, 0);
      expect(page.controls[0].width, 5);

      // Fader 1 should be pushed to x: 5, width: 3
      expect(page.controls[1].x, 5);
      expect(page.controls[1].width, 3);
    });

    test('deleteControl deletes a control from the page correctly', () {
      final notifier = container.read(layoutStateProvider.notifier);

      var state = container.read(layoutStateProvider);
      var page = state.pages.firstWhere((p) => p.id == 'page_0');
      expect(page.controls.length, 2);
      expect(page.controls.any((c) => c.id == 'fader_0'), true);

      // Delete fader_0
      notifier.deleteControl('page_0', 'fader_0');

      state = container.read(layoutStateProvider);
      page = state.pages.firstWhere((p) => p.id == 'page_0');
      expect(page.controls.length, 1);
      expect(page.controls.any((c) => c.id == 'fader_0'), false);
      expect(page.controls.first.id, 'fader_1');
    });
  });
}

// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:app/core/models/layout_models.dart';
import 'package:app/ui/editor_state.dart';
import 'package:app/ui/global_ui_scale_state.dart';
import 'package:app/ui/layout_state.dart';
import 'package:app/ui/widgets/editor_control_wrapper.dart';
import 'package:app/ui/widgets/performance_grid_viewport.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PolishTestLayout extends LayoutStateNotifier {
  _PolishTestLayout(this.initialPages);

  final List<LayoutPage> initialPages;

  @override
  LayoutState build() => LayoutState(
    pages: initialPages,
    activePageIndex: 0,
    isPerformanceLocked: false,
  );
}

void _expectNoHandleOverlap(WidgetTester tester, String controlId) {
  final deleteRect = tester.getRect(
    find.byKey(ValueKey('editor_delete_handle_$controlId')),
  );
  final settingsRect = tester.getRect(
    find.byKey(ValueKey('editor_settings_handle_$controlId')),
  );
  final resizeRect = tester.getRect(
    find.byKey(ValueKey('editor_resize_handle_$controlId')),
  );

  expect(deleteRect.overlaps(settingsRect), isFalse);
  expect(deleteRect.overlaps(resizeRect), isFalse);
  expect(settingsRect.overlaps(resizeRect), isFalse);
}

void main() {
  testWidgets(
    'delete UNDO SnackBar sets persist: false and auto-dismisses after 4 seconds',
    (tester) async {
      final control = LayoutControl(
        id: 'pad_undo',
        type: ControlType.aftertouchPad,
        defaultCc: 60,
        channel: 0,
        customName: 'AT PAD',
      );
      final container = ProviderContainer.test(
        overrides: [
          layoutStateProvider.overrideWith(
            () => _PolishTestLayout([
              LayoutPage(
                id: 'p1',
                type: PageType.utility,
                name: 'TEST',
                gridColumns: 4,
                gridRows: 4,
                controls: [control],
              ),
            ]),
          ),
        ],
      );
      container.read(selectedControlProvider.notifier).select(control.id);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 120,
                height: 160,
                child: EditorControlWrapper(
                  control: control,
                  pageId: 'p1',
                  cellWidth: 120,
                  cellHeight: 160,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey('editor_delete_handle_pad_undo')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Deleted AT PAD'), findsOneWidget);
      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.persist, isFalse);

      // Advance past the 4s duration + exit animation and confirm auto-dismiss.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Deleted AT PAD'), findsNothing);
    },
  );

  testWidgets(
    'narrow tall and compact 1-column controls lay out handles without overlap',
    (tester) async {
      final tallPad = LayoutControl(
        id: 'tall_pad',
        type: ControlType.aftertouchPad,
        defaultCc: 60,
        channel: 0,
      );
      final shortPad = LayoutControl(
        id: 'short_pad',
        type: ControlType.latchPad,
        defaultCc: 62,
        channel: 0,
        x: 1,
      );
      final container = ProviderContainer.test(
        overrides: [
          layoutStateProvider.overrideWith(
            () => _PolishTestLayout([
              LayoutPage(
                id: 'p1',
                type: PageType.utility,
                name: 'NARROW',
                gridColumns: 8,
                gridRows: 6,
                controls: [tallPad, shortPad],
              ),
            ]),
          ),
        ],
      );

      container.read(selectedControlProvider.notifier).select(tallPad.id);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 45,
                height: 160,
                child: EditorControlWrapper(
                  control: tallPad,
                  pageId: 'p1',
                  cellWidth: 45,
                  cellHeight: 160,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
      _expectNoHandleOverlap(tester, tallPad.id);

      container.read(selectedControlProvider.notifier).select(shortPad.id);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 45,
                height: 54,
                child: EditorControlWrapper(
                  control: shortPad,
                  pageId: 'p1',
                  cellWidth: 45,
                  cellHeight: 54,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
      _expectNoHandleOverlap(tester, shortPad.id);
    },
  );

  testWidgets('single-finger drag compensates for globalUiScale > 1.0', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'globalUiScale': 1.35});
    final control = LayoutControl(
      id: 'scaled_pad',
      type: ControlType.aftertouchPad,
      defaultCc: 60,
      channel: 0,
    );
    final container = ProviderContainer.test(
      overrides: [
        layoutStateProvider.overrideWith(
          () => _PolishTestLayout([
            LayoutPage(
              id: 'p1',
              type: PageType.utility,
              name: 'SCALED',
              gridColumns: 4,
              gridRows: 2,
              controls: [control],
            ),
          ]),
        ),
      ],
    );
    await container.read(globalUiScaleProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 240,
              height: 160,
              child: PerformanceGridViewport(
                scale: 1.35,
                panEnabled: false,
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      width: 60,
                      height: 80,
                      child: EditorControlWrapper(
                        control: control,
                        pageId: 'p1',
                        cellWidth: 60,
                        cellHeight: 80,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(30, 40));
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump(const Duration(milliseconds: 25));
    await gesture.moveBy(const Offset(85, 0));
    await tester.pump(const Duration(milliseconds: 25));
    await gesture.up();

    final moved = container
        .read(layoutStateProvider)
        .getControlById(control.id)!;
    expect(moved.x, 1);
  });
}

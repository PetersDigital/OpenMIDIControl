// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:app/core/models/page_templates.dart';
import 'package:app/core/models/layout_models.dart';
import 'package:app/ui/editor/widget_palette_panel.dart';
import 'package:app/ui/layout_state.dart';
import 'package:app/ui/widgets/aftertouch_pad.dart';
import 'package:app/ui/widgets/dynamic_grid_renderer.dart';
import 'package:app/ui/widgets/latch_pad.dart';
import 'package:app/ui/widgets/page_management.dart';

void main() {
  testWidgets('palette places both expressive pads on the grid', (
    tester,
  ) async {
    final container = ProviderContainer.test();
    final layout = container.read(layoutStateProvider.notifier);
    final page = container.read(layoutStateProvider).activePage!;
    layout.overwriteActivePage(page.copyWith(controls: []));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                const SizedBox(width: 300, child: WidgetPalettePanel()),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final activePage = ref
                          .watch(layoutStateProvider)
                          .activePage!;
                      return DynamicGridRenderer(
                        controls: activePage.controls,
                        pageId: activePage.id,
                        isActive: true,
                        isMobile: false,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final pad = find.text('Aftertouch Pad');
    await tester.scrollUntilVisible(pad, 150);
    await tester.tap(pad);
    await tester.pumpAndSettle();
    final placed = container
        .read(layoutStateProvider)
        .activePage!
        .controls
        .single;
    expect(placed.type, ControlType.aftertouchPad);
    expect(placed.payload, isNull);
    expect(find.byType(AftertouchPad), findsOneWidget);

    final latch = find.text('Latch Pad');
    await tester.scrollUntilVisible(latch, 150);
    await tester.tap(latch);
    await tester.pumpAndSettle();
    final newPad = container
        .read(layoutStateProvider)
        .activePage!
        .controls
        .last;
    expect(newPad.type, ControlType.latchPad);
    expect(newPad.payload, isNull);
    expect(newPad.latchDurationMs, LayoutControl.defaultLatchDurationMs);
    expect(find.byType(LatchPad), findsOneWidget);
  });

  group('Template UI integration', () {
    testWidgets(
      'WidgetPalettePanel switches to TEMPLATES and stamps/undoes NEW PAGE',
      (WidgetTester tester) async {
        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  container = ProviderScope.containerOf(context);
                  return const Scaffold(body: WidgetPalettePanel());
                },
              ),
            ),
          ),
        );

        expect(find.text('Fader'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('palette_tab_templates')));
        await tester.pumpAndSettle();

        expect(find.text('Factory Fader Bank'), findsOneWidget);
        await tester.drag(
          find.byKey(const ValueKey('palette_templates_list')),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        expect(find.text('8-Track Mixer Stub'), findsOneWidget);

        await tester.drag(
          find.byKey(const ValueKey('palette_templates_list')),
          const Offset(0, 300),
        );
        await tester.pumpAndSettle();

        final initialCount = container.read(layoutStateProvider).pages.length;

        // ON PAGE should reject on the full default fader page without adding controls.
        await tester.tap(
          find.byKey(const ValueKey('template_on_page_factoryFaderBank')),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Not enough open space on active page — try NEW PAGE'),
          findsOneWidget,
        );
        expect(container.read(layoutStateProvider).pages.length, initialCount);

        // NEW PAGE appends a template page and offers UNDO.
        await tester.tap(
          find.byKey(const ValueKey('template_new_page_factoryFaderBank')),
        );
        await tester.pumpAndSettle();
        expect(
          container.read(layoutStateProvider).pages.length,
          initialCount + 1,
        );
        expect(
          container.read(layoutStateProvider).activePage!.name,
          'FADER BANK',
        );

        await tester.tap(find.text('UNDO'));
        await tester.pumpAndSettle();
        expect(container.read(layoutStateProvider).pages.length, initialCount);
      },
    );

    testWidgets(
      'PageManagementSection + ADD NEW PAGE can create page from template',
      (WidgetTester tester) async {
        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Builder(
                builder: (context) {
                  container = ProviderScope.containerOf(context);
                  return const Scaffold(
                    body: CustomScrollView(slivers: [PageManagementSection()]),
                  );
                },
              ),
            ),
          ),
        );

        final initialCount = container.read(layoutStateProvider).pages.length;

        await tester.tap(find.text('+ ADD NEW PAGE'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Stage Mixer');
        await tester.pump();

        final mixerOption = find.byKey(
          const ValueKey('add_page_template_mixerStub8Track'),
        );
        await tester.ensureVisible(mixerOption);
        await tester.tap(mixerOption);
        await tester.pumpAndSettle();

        final pages = container.read(layoutStateProvider).pages;
        expect(pages.length, initialCount + 1);
        expect(pages.last.name, 'Stage Mixer');
        expect(pages.last.controls.length, 24);
      },
    );

    testWidgets(
      'All stamped factory templates render cleanly in DynamicGridRenderer',
      (WidgetTester tester) async {
        for (final viewport in [const Size(412, 600), const Size(960, 640)]) {
          for (final template in FactoryPageTemplates.all) {
            final page = template.instantiatePage(
              pageId: 'render_${template.id.name}',
              idSuffix: 'render',
            );

            await tester.binding.setSurfaceSize(viewport);
            await tester.pumpWidget(
              ProviderScope(
                child: MaterialApp(
                  home: Scaffold(
                    body: SizedBox(
                      width: viewport.width,
                      height: viewport.height,
                      child: DynamicGridRenderer(
                        controls: page.controls,
                        pageId: page.id,
                        isActive: false,
                        isMobile: viewport.width < 600,
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pump();
            expect(
              tester.takeException(),
              isNull,
              reason: '${template.name} @ $viewport',
            );
          }
        }
        await tester.binding.setSurfaceSize(null);
      },
    );
  });
}

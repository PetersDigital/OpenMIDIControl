// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/models/action_payload.dart';
import 'package:app/core/models/layout_models.dart';
import 'package:app/core/models/page_templates.dart';
import 'package:app/ui/layout_state.dart';

void main() {
  group('FactoryPageTemplates catalog', () {
    test('all templates are immutable, valid, and have explicit payloads', () {
      expect(FactoryPageTemplates.all.length, 5);
      expect(
        () => FactoryPageTemplates.all.add(
          FactoryPageTemplates.byId(PageTemplateId.factoryFaderBank),
        ),
        throwsUnsupportedError,
      );

      for (final template in FactoryPageTemplates.all) {
        expect(template.isValid, isTrue, reason: template.name);
        expect(template.boundingWidth, lessThanOrEqualTo(template.gridColumns));
        expect(template.boundingHeight, lessThanOrEqualTo(template.gridRows));
        expect(
          () => template.controls.add(template.controls.first),
          throwsUnsupportedError,
        );

        for (final control in template.controls) {
          expect(control.payload, isNotNull, reason: control.idPrefix);
          if (control.type == ControlType.xyPad) {
            expect(control.secondaryPayload, isNotNull);
          }
        }
      }
    });

    test('factory templates match expected dimensions and ActionPayloads', () {
      final faders = FactoryPageTemplates.byId(PageTemplateId.factoryFaderBank);
      expect(faders.controlCount, 4);
      expect(faders.controls.map((c) => c.defaultCc), [1, 11, 7, 74]);

      final drums = FactoryPageTemplates.byId(PageTemplateId.drumGrid4x4);
      expect(drums.controlCount, 16);
      expect(
        drums.controls.first.payload,
        const NotePayload(
          channel: 9,
          note: 36,
          velocityMode: NoteVelocityMode.touchPosition,
          velocityCurve: NoteVelocityCurve.drumPad,
        ),
      );
      expect(
        drums.controls.last.payload,
        const NotePayload(
          channel: 9,
          note: 51,
          velocityMode: NoteVelocityMode.touchPosition,
          velocityCurve: NoteVelocityCurve.drumPad,
        ),
      );

      final xyEnc = FactoryPageTemplates.byId(PageTemplateId.xyAndEncoders);
      expect(xyEnc.controlCount, 5);
      expect(xyEnc.controls.first.type, ControlType.xyPad);
      expect(xyEnc.controls.first.invertY, isTrue);

      final mixer = FactoryPageTemplates.byId(PageTemplateId.mixerStub8Track);
      expect(mixer.gridColumns, 8);
      expect(mixer.gridRows, 6);
      expect(mixer.controlCount, 24);

      final mcu = FactoryPageTemplates.byId(PageTemplateId.mcuMixer8Track);
      expect((mcu.gridColumns, mcu.gridRows, mcu.controlCount), (9, 9, 49));
      expect(mcu.controls.last.payload, const McuActionPayload.fader(8));
      expect(
        mcu.controls.where((c) => c.type == ControlType.encoder),
        hasLength(8),
      );
      expect(
        mcu.controls.where((c) => c.type == ControlType.trigger),
        hasLength(32),
      );
      expect(
        mcu.controls.where((c) => c.type == ControlType.fader),
        hasLength(9),
      );
    });

    test('instantiated page round-trips through JSON cleanly', () {
      for (final template in FactoryPageTemplates.all) {
        final page = template.instantiatePage(
          pageId: 'test_${template.id.name}',
          idSuffix: 'roundtrip',
        );
        final decoded = LayoutPage.fromJson(page.toJson());
        expect(decoded, page);
      }
    });
  });

  group('LayoutStateNotifier template stamping', () {
    test('addPageFromTemplate creates unique IDs across rapid stamps', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(layoutStateProvider.notifier);
      final template = FactoryPageTemplates.byId(PageTemplateId.drumGrid4x4);

      final first = notifier.addPageFromTemplate(template);
      final second = notifier.addPageFromTemplate(
        template,
        customName: 'Custom Drums',
      );

      expect(first.id, isNot(second.id));
      expect(first.name, '4X4 DRUMS');
      expect(second.name, 'Custom Drums');

      final firstControlIds = first.controls.map((c) => c.id).toSet();
      final secondControlIds = second.controls.map((c) => c.id).toSet();
      expect(firstControlIds.length, 16);
      expect(secondControlIds.length, 16);
      expect(firstControlIds.intersection(secondControlIds), isEmpty);

      final state = container.read(layoutStateProvider);
      expect(state.activePageIndex, state.pages.length - 1);
    });

    test(
      'stampTemplateOnActivePage places controls on empty page and rejects collisions',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(layoutStateProvider.notifier);
        notifier.addPage(PageType.fader, 'Blank 8x4');
        final activeIndex = container.read(layoutStateProvider).activePageIndex;
        final blankPageId = container
            .read(layoutStateProvider)
            .pages[activeIndex]
            .id;

        // Clear the auto-generated starter faders so the page is empty.
        final existing = [
          ...container.read(layoutStateProvider).pages[activeIndex].controls,
        ];
        for (final control in existing) {
          notifier.deleteControl(blankPageId, control.id);
        }
        expect(
          container.read(layoutStateProvider).activePage!.controls,
          isEmpty,
        );

        // 8x6 mixer template does not fit on 8x4 page -> rejected cleanly.
        final tooTallResult = notifier.stampTemplateOnActivePage(
          FactoryPageTemplates.byId(PageTemplateId.mixerStub8Track),
        );
        expect(tooTallResult.status, TemplateStampStatus.insufficientSpace);
        expect(
          container.read(layoutStateProvider).activePage!.controls,
          isEmpty,
        );

        // 8x4 fader bank fits on empty 8x4 page.
        final fitResult = notifier.stampTemplateOnActivePage(
          FactoryPageTemplates.byId(PageTemplateId.factoryFaderBank),
        );
        expect(fitResult.isSuccess, isTrue);
        expect(fitResult.addedCount, 4);
        expect(fitResult.originX, 0);
        expect(fitResult.originY, 0);
        expect(
          container.read(layoutStateProvider).activePage!.controls.length,
          4,
        );

        // Second stamp on now-full page rejects collision without mutating state.
        final collisionResult = notifier.stampTemplateOnActivePage(
          FactoryPageTemplates.byId(PageTemplateId.xyAndEncoders),
        );
        expect(collisionResult.status, TemplateStampStatus.insufficientSpace);
        expect(
          container.read(layoutStateProvider).activePage!.controls.length,
          4,
        );
      },
    );

    test(
      'stampTemplateOnActivePage validates explicit origin and empty page list',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(layoutStateProvider.notifier);
        final template = FactoryPageTemplates.byId(
          PageTemplateId.factoryFaderBank,
        );

        // Explicit invalid origin on populated page rejects.
        final badOrigin = notifier.stampTemplateOnActivePage(
          template,
          originX: 1,
          originY: 0,
        );
        expect(badOrigin.status, TemplateStampStatus.insufficientSpace);

        // Remove all pages -> noActivePage.
        while (container.read(layoutStateProvider).pages.isNotEmpty) {
          notifier.removePage(0);
        }
        final emptyResult = notifier.stampTemplateOnActivePage(template);
        expect(emptyResult.status, TemplateStampStatus.noActivePage);
      },
    );
  });
}

// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:typed_data';

import 'package:app/core/models/page_templates.dart';
import 'package:app/ui/editor_state.dart';
import 'package:app/ui/hybrid_touch_fader.dart';
import 'package:app/ui/layout_state.dart';
import 'package:app/ui/midi_service.dart';
import 'package:app/ui/open_midi_screen.dart';
import 'package:app/ui/widgets/endless_encoder.dart';
import 'package:app/ui/widgets/midi_buttons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'MCU mixer performs gestures and releases two faders on page switch',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(384, 832);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      const channel = MethodChannel('com.petersdigital.openmidicontrol/midi');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final packets = <int>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getMcuRouteGeneration') return 42;
        if (call.method == 'sendMcuBatch') {
          final data = call.arguments['events'] as Int64List;
          packets.addAll([for (var i = 0; i < data.length; i += 2) data[i]]);
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final midi = MidiService(useBackgroundWorker: false);
      addTearDown(midi.dispose);
      final container = ProviderContainer.test(
        overrides: [midiServiceProvider.overrideWithValue(midi)],
      );
      final layout = container.read(layoutStateProvider.notifier);
      final page = layout.addPageFromTemplate(
        FactoryPageTemplates.byId(PageTemplateId.mcuMixer8Track),
      );
      expect(await midi.startMcuSession(), isTrue);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: PerformanceZone(isMobile: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final knobs = find.byType(EndlessEncoderWidget).hitTestable();
      await tester.tap(knobs.first);
      expect(packets, [0x2090207F, 0x20802000]);
      packets.clear();

      final knob = tester.getRect(knobs.first);
      final rotation = await tester.startGesture(
        knob.center + Offset(0, knob.height * 0.3),
      );
      await rotation.moveBy(Offset(0, -knob.height * 0.5));
      await rotation.moveBy(Offset(0, -knob.height * 0.3));
      await rotation.up();
      await tester.pump(const Duration(milliseconds: 20));
      expect(packets, isNotEmpty);
      expect(packets.every((word) => word & 0xFFFFFF00 == 0x20B01000), isTrue);
      packets.clear();

      final mute = page.controls.firstWhere(
        (control) => control.id.startsWith('mcu_mute'),
      );
      final muteWidget = find.byWidgetPredicate(
        (widget) => widget is Trigger && widget.controlId == mute.id,
      );
      await tester.tap(muteWidget);
      expect(packets, [0x2090107F, 0x20801000]);
      packets.clear();

      final faders = find.byType(HybridTouchFader).hitTestable();
      final first = tester.getRect(faders.at(0));
      final second = tester.getRect(faders.at(1));
      final left = await tester.startGesture(first.center);
      final right = await tester.startGesture(second.center);
      await left.moveBy(const Offset(0, 30));
      await right.moveBy(const Offset(0, -30));
      await left.moveBy(const Offset(0, 40));
      await right.moveBy(const Offset(0, -40));
      layout.setPageIndex(0);
      await tester.pump();
      await left.up();
      await right.up();
      await tester.pump();

      for (final strip in [0, 1]) {
        final touch = 0x2090687F + (strip << 8);
        final release = 0x20806800 + (strip << 8);
        final bendHeader = 0x20E00000 + (strip << 16);
        final related = packets
            .where(
              (word) =>
                  word == touch ||
                  word == release ||
                  (word & 0xFFFF0000) == bendHeader,
            )
            .toList();
        expect(related.first, touch);
        expect(related[related.length - 2] & 0xFFFF0000, bendHeader);
        expect(related.last, release);
        expect(related.where((word) => word == release), hasLength(1));
      }
    },
  );

  testWidgets(
    'MCU V-Pot lights monitor ring on bit 6 feedback and clears on bit 6 off',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(384, 832);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      const channel = MethodChannel('com.petersdigital.openmidicontrol/midi');
      const eventsChannel = EventChannel(
        'com.petersdigital.openmidicontrol/midi_events',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      late MockStreamHandlerEventSink native;
      messenger.setMockStreamHandler(
        eventsChannel,
        MockStreamHandler.inline(
          onListen: (_, sink) {
            native = sink;
          },
        ),
      );
      addTearDown(() => messenger.setMockStreamHandler(eventsChannel, null));
      final packets = <int>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getMcuRouteGeneration') return 42;
        if (call.method == 'sendMcuBatch') {
          final data = call.arguments['events'] as Int64List;
          packets.addAll([for (var i = 0; i < data.length; i += 2) data[i]]);
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final midi = MidiService(useBackgroundWorker: false);
      addTearDown(midi.dispose);
      final container = ProviderContainer.test(
        overrides: [midiServiceProvider.overrideWithValue(midi)],
      );
      container
          .read(layoutStateProvider.notifier)
          .addPageFromTemplate(
            FactoryPageTemplates.byId(PageTemplateId.mcuMixer8Track),
          );
      expect(await midi.startMcuSession(), isTrue);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: PerformanceZone(isMobile: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Monitor OFF'), findsNWidgets(8));
      expect(find.bySemanticsLabel('Monitor ON'), findsNothing);
      expect(find.text('MCU'), findsNothing);
      expect(find.text('PAN'), findsNWidgets(8));

      final vPot1 = find.byType(EndlessEncoderWidget).hitTestable().first;
      await tester.tap(vPot1);
      await tester.pump();
      expect(packets, [0x2090207F, 0x20802000]);
      expect(find.bySemanticsLabel('Monitor ON'), findsOneWidget);
      expect(find.bySemanticsLabel('Monitor OFF'), findsNWidgets(7));

      native.success(
        Int64List.fromList([-2, 42, 1, 0x40B03000, 0xACB2CB2C, 1]),
      );
      await tester.pump();
      await tester.pump();
      expect(find.bySemanticsLabel('Monitor ON'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);

      native.success(Int64List.fromList([-2, 42, 1, 0x20E02035, 0, 1]));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('-20.0'), findsOneWidget);

      await tester.tap(vPot1);
      await tester.pump();
      expect(find.bySemanticsLabel('Monitor ON'), findsNothing);
      expect(find.bySemanticsLabel('Monitor OFF'), findsNWidgets(8));
    },
  );

  testWidgets(
    'HybridTouchFader snaps to cached MCU feedback when resumed from pause',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(384, 832);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      const channel = MethodChannel('com.petersdigital.openmidicontrol/midi');
      const eventsChannel = EventChannel(
        'com.petersdigital.openmidicontrol/midi_events',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      late MockStreamHandlerEventSink native;
      messenger.setMockStreamHandler(
        eventsChannel,
        MockStreamHandler.inline(
          onListen: (_, sink) {
            native = sink;
          },
        ),
      );
      addTearDown(() => messenger.setMockStreamHandler(eventsChannel, null));
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getMcuRouteGeneration') return 42;
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final midi = MidiService(useBackgroundWorker: false);
      addTearDown(midi.dispose);
      final container = ProviderContainer.test(
        overrides: [midiServiceProvider.overrideWithValue(midi)],
      );
      container
          .read(layoutStateProvider.notifier)
          .addPageFromTemplate(
            FactoryPageTemplates.byId(PageTemplateId.mcuMixer8Track),
          );
      expect(await midi.startMcuSession(), isTrue);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: PerformanceZone(isMobile: true)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Deliver -20.0 dB feedback, freeze mid-animation by pausing, then resume.
      native.success(Int64List.fromList([-2, 42, 1, 0x20E02035, 0, 1]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 5));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(find.text('-20.0'), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('-20.0'), findsOneWidget);
    },
  );

  testWidgets('root Back dismisses overlays before moving app to background', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(384, 832);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'hasLaunched': true});
    const channel = MethodChannel('com.petersdigital.openmidicontrol/midi');
    const eventsChannel = EventChannel(
      'com.petersdigital.openmidicontrol/midi_events',
    );
    const systemChannel = EventChannel(
      'com.petersdigital.openmidicontrol/system_events',
    );
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockStreamHandler(
      eventsChannel,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    messenger.setMockStreamHandler(
      systemChannel,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    addTearDown(() {
      messenger.setMockStreamHandler(eventsChannel, null);
      messenger.setMockStreamHandler(systemChannel, null);
    });
    var moveToBackgroundCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'moveToBackground') {
        moveToBackgroundCalls++;
        return true;
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final midi = MidiService(useBackgroundWorker: false);
    addTearDown(midi.dispose);
    final container = ProviderContainer.test(
      overrides: [midiServiceProvider.overrideWithValue(midi)],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OpenMIDIMainScreen()),
      ),
    );
    await tester.pumpAndSettle();

    container
        .read(editorOverlayProvider.notifier)
        .toggle(EditorOverlay.palette);
    await tester.pump();
    expect(container.read(editorOverlayProvider), EditorOverlay.palette);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(container.read(editorOverlayProvider), EditorOverlay.none);
    expect(moveToBackgroundCalls, 0);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(moveToBackgroundCalls, 1);
  });
}

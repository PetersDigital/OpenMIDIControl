// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:convert';
import 'dart:ui';

import 'package:app/core/lifecycle/app_lifecycle_manager.dart';
import 'package:app/core/models/action_payload.dart';
import 'package:app/core/models/control_state.dart';
import 'package:app/ui/header_transport_state.dart';
import 'package:app/ui/midi_service.dart';
import 'package:app/ui/open_midi_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingMidiService extends MidiService {
  final List<(ActionPayload payload, bool pressed)> transportEvents = [];

  @override
  void sendTransportButton(ActionPayload payload, {required bool pressed}) {
    transportEvents.add((payload, pressed));
  }
}

class _MutableControlStateNotifier extends ControlStateNotifier {
  @override
  ControlState build() =>
      ControlState(ccValues: {}, noteStates: {}, buttonStates: {});

  void setButtonStates(Map<String, bool> buttonStates) {
    state = state.copyWith(
      version: state.version + 1,
      buttonStates: buttonStates,
    );
  }
}

class _TestLifecycleNotifier extends AppLifecycleStateNotifier {
  @override
  AppLifecycleState build() => AppLifecycleState.resumed;

  void emitState(AppLifecycleState next) => state = next;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    const channel = MethodChannel('com.petersdigital.openmidicontrol/midi');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> seedMappings(Map<HeaderTransportRole, ActionPayload> map) async {
    SharedPreferences.setMockInitialValues({
      HeaderTransportMappingsNotifier.storageKey: jsonEncode({
        for (final e in map.entries) e.key.name: e.value.toJson(),
      }),
    });
  }

  group('MidiTransportGrid header transport wiring', () {
    testWidgets(
      'square=false and square=true send momentary CC/Note and skip unassigned cells',
      (tester) async {
        const playNote = NotePayload(channel: 0, note: 94);
        const stopCc = CcPayload(channel: 1, cc: 118);
        await seedMappings({
          HeaderTransportRole.play: playNote,
          HeaderTransportRole.stop: stopCc,
        });

        for (final isSquare in [false, true]) {
          final midiService = _RecordingMidiService();
          final container = ProviderContainer(
            overrides: [midiServiceProvider.overrideWithValue(midiService)],
          );
          addTearDown(container.dispose);

          await container
              .read(headerTransportMappingsProvider.notifier)
              .ensureLoaded();

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                home: Scaffold(
                  body: SizedBox(
                    width: 400,
                    height: 400,
                    child: MidiTransportGrid(square: isSquare),
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          final playGesture = await tester.startGesture(
            tester.getCenter(find.byIcon(Icons.play_arrow)),
            buttons: kPrimaryButton,
          );
          await tester.pump();
          expect(midiService.transportEvents, [(playNote, true)]);

          await playGesture.up();
          await tester.pump();
          expect(midiService.transportEvents, [
            (playNote, true),
            (playNote, false),
          ]);

          final stopGesture = await tester.startGesture(
            tester.getCenter(find.byIcon(Icons.stop)),
            buttons: kPrimaryButton,
          );
          await tester.pump();
          await stopGesture.up();
          await tester.pump();

          expect(midiService.transportEvents, [
            (playNote, true),
            (playNote, false),
            (stopCc, true),
            (stopCc, false),
          ]);

          // Unassigned cell should do nothing.
          final rewindGesture = await tester.startGesture(
            tester.getCenter(find.byIcon(Icons.fast_rewind)),
            buttons: kPrimaryButton,
          );
          await rewindGesture.up();
          await tester.pump();
          expect(midiService.transportEvents, hasLength(4));
        }
      },
    );

    testWidgets(
      'supports simultaneous holds on different buttons without conflicts',
      (tester) async {
        const playNote = NotePayload(channel: 0, note: 94);
        const recordCc = CcPayload(channel: 0, cc: 119);
        await seedMappings({
          HeaderTransportRole.play: playNote,
          HeaderTransportRole.record: recordCc,
        });

        final midiService = _RecordingMidiService();
        final container = ProviderContainer(
          overrides: [midiServiceProvider.overrideWithValue(midiService)],
        );
        addTearDown(container.dispose);

        await container
            .read(headerTransportMappingsProvider.notifier)
            .ensureLoaded();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 360,
                  height: 360,
                  child: MidiTransportGrid(square: true),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final g1 = await tester.startGesture(
          tester.getCenter(find.byIcon(Icons.play_arrow)),
          pointer: 10,
          buttons: kPrimaryButton,
        );
        final g2 = await tester.startGesture(
          tester.getCenter(find.byIcon(Icons.fiber_manual_record)),
          pointer: 11,
          buttons: kPrimaryButton,
        );
        await tester.pump();

        expect(midiService.transportEvents, [
          (playNote, true),
          (recordCc, true),
        ]);

        await g1.up();
        await tester.pump();
        expect(midiService.transportEvents, [
          (playNote, true),
          (recordCc, true),
          (playNote, false),
        ]);

        await g2.up();
        await tester.pump();
        expect(midiService.transportEvents, [
          (playNote, true),
          (recordCc, true),
          (playNote, false),
          (recordCc, false),
        ]);
      },
    );

    testWidgets('lights matching cell on ControlState.buttonStates feedback', (
      tester,
    ) async {
      const stopCc = CcPayload(channel: 2, cc: 117);
      const playNote = NotePayload(channel: 0, note: 94);
      await seedMappings({
        HeaderTransportRole.stop: stopCc,
        HeaderTransportRole.play: playNote,
      });

      final controlStateNotifier = _MutableControlStateNotifier();
      final container = ProviderContainer(
        overrides: [
          controlStateProvider.overrideWith(() => controlStateNotifier),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(headerTransportMappingsProvider.notifier)
          .ensureLoaded();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 360,
                child: MidiTransportGrid(square: false),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      bool isCellLit(String label) {
        final selected = tester
            .getSemantics(find.bySemanticsLabel(label))
            .flagsCollection
            .isSelected;
        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.bySemanticsLabel(label),
                matching: find.byType(Container),
              )
              .first,
        );
        final decoration = container.decoration! as BoxDecoration;
        final hasLitBorder = decoration.border!.top.width == 1.5;
        expect(hasLitBorder, selected == Tristate.isTrue);
        return selected == Tristate.isTrue;
      }

      expect(isCellLit('Stop'), isFalse);
      expect(isCellLit('Play'), isFalse);

      controlStateNotifier.setButtonStates({'2:117': true});
      await tester.pump();

      expect(isCellLit('Stop'), isTrue);
      expect(isCellLit('Play'), isFalse);

      controlStateNotifier.setButtonStates({'2:117': false, 'note:0:94': true});
      await tester.pump();

      expect(isCellLit('Stop'), isFalse);
      expect(isCellLit('Play'), isTrue);
    });

    testWidgets(
      'releases original assignment on cancel, rebinding, grid closure, and backgrounding',
      (tester) async {
        const initialRewind = CcPayload(channel: 0, cc: 115);
        const reboundRewind = NotePayload(channel: 0, note: 91);
        await seedMappings({HeaderTransportRole.rewind: initialRewind});

        final midiService = _RecordingMidiService();
        final lifecycleNotifier = _TestLifecycleNotifier();
        final container = ProviderContainer(
          overrides: [
            midiServiceProvider.overrideWithValue(midiService),
            appLifecycleStateProvider.overrideWith(() => lifecycleNotifier),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(headerTransportMappingsProvider.notifier)
            .ensureLoaded();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    final visible = ref.watch(transportVisibleProvider);
                    return visible
                        ? const SizedBox(
                            width: 360,
                            height: 360,
                            child: MidiTransportGrid(square: true),
                          )
                        : const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        );

        container.read(transportVisibleProvider.notifier).setVisible(true);
        await tester.pump();

        // 1. Pointer cancel releases original assignment.
        final cancelGesture = await tester.startGesture(
          tester.getCenter(find.byIcon(Icons.fast_rewind)),
          pointer: 20,
          buttons: kPrimaryButton,
        );
        await tester.pump();
        await cancelGesture.cancel();
        await tester.pump();
        expect(midiService.transportEvents, [
          (initialRewind, true),
          (initialRewind, false),
        ]);

        // 2. App backgrounding releases held assignment.
        final bgGesture = await tester.startGesture(
          tester.getCenter(find.byIcon(Icons.fast_rewind)),
          pointer: 21,
          buttons: kPrimaryButton,
        );
        await tester.pump();
        lifecycleNotifier.emitState(AppLifecycleState.paused);
        await tester.pump();
        await bgGesture.up();
        await tester.pump();
        expect(midiService.transportEvents.sublist(2), [
          (initialRewind, true),
          (initialRewind, false),
        ]);
        lifecycleNotifier.emitState(AppLifecycleState.resumed);

        // 3. Rebinding while held releases the ORIGINAL assignment.
        final rebindGesture = await tester.startGesture(
          tester.getCenter(find.byIcon(Icons.fast_rewind)),
          pointer: 22,
          buttons: kPrimaryButton,
        );
        await tester.pump();
        await container
            .read(headerTransportMappingsProvider.notifier)
            .setAssignment(HeaderTransportRole.rewind, reboundRewind);
        await tester.pump();
        await rebindGesture.up();
        await tester.pump();
        expect(midiService.transportEvents.sublist(4), [
          (initialRewind, true),
          (initialRewind, false),
        ]);

        // 4. Grid closure while held releases the active (rebound) assignment.
        final closeGesture = await tester.startGesture(
          tester.getCenter(find.byIcon(Icons.fast_rewind)),
          pointer: 23,
          buttons: kPrimaryButton,
        );
        await tester.pump();
        container.read(transportVisibleProvider.notifier).setVisible(false);
        await tester.pump();
        await closeGesture.up();
        await tester.pump();
        expect(midiService.transportEvents.sublist(6), [
          (reboundRewind, true),
          (reboundRewind, false),
        ]);
      },
    );
  });
}

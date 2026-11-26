// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';

import 'package:app/core/models/action_payload.dart';
import 'package:app/ui/header_transport_state.dart';
import 'package:app/ui/settings/tabs/performance_tab.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> pumpPerformanceTab(
    WidgetTester tester, {
    Future<SharedPreferences> Function()? prefsOverride,
  }) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(
      overrides: [
        if (prefsOverride != null)
          headerTransportPrefsProvider.overrideWithValue(prefsOverride),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: PerformanceTab())),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  group('PerformanceTab Transport Assignments', () {
    testWidgets(
      'lists all nine role names defaulting to Unassigned and edits/clears with validation',
      (tester) async {
        final container = await pumpPerformanceTab(tester);

        await tester.scrollUntilVisible(
          find.text('TRANSPORT ASSIGNMENTS'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('TRANSPORT ASSIGNMENTS'), findsOneWidget);

        for (final role in HeaderTransportRole.values) {
          final cardFinder = find.byKey(
            ValueKey('transport_assignment_${role.name}'),
          );
          await tester.scrollUntilVisible(
            cardFinder,
            250,
            scrollable: find.byType(Scrollable).first,
          );
          expect(cardFinder, findsOneWidget);
          expect(
            find.descendant(of: cardFinder, matching: find.text(role.label)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: cardFinder, matching: find.text('Unassigned')),
            findsOneWidget,
          );
        }

        // Open Play editor and inspect allowed message types.
        final playCard = find.byKey(
          const ValueKey('transport_assignment_play'),
        );
        await tester.ensureVisible(playCard);
        await tester.pumpAndSettle();
        await tester.tap(playCard);
        await tester.pumpAndSettle();

        expect(find.text('Assign Play'), findsOneWidget);

        await tester.tap(find.text('Unassigned').last);
        await tester.pumpAndSettle();
        expect(find.text('CC'), findsWidgets);
        expect(find.text('Note'), findsWidgets);
        expect(find.text('Pitch Bend'), findsNothing);
        expect(find.text('Relative CC'), findsNothing);

        // Select CC and attempt invalid empty submission -> validation blocks save.
        await tester.tap(find.text('CC').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(find.text('Enter a CC number from 0 to 127'), findsOneWidget);
        expect(find.text('Assign Play'), findsOneWidget);
        expect(
          container.read(
            headerTransportMappingsProvider,
          )[HeaderTransportRole.play],
          isNull,
        );

        // Enter valid CC 118 and save.
        await tester.enterText(find.byType(TextFormField).first, '118');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(find.text('Assign Play'), findsNothing);
        expect(
          container.read(
            headerTransportMappingsProvider,
          )[HeaderTransportRole.play],
          const CcPayload(channel: 0, cc: 118),
        );
        expect(find.text('CC 118 • CH 1'), findsOneWidget);

        // Re-open Play editor and switch back to Unassigned.
        await tester.tap(playCard);
        await tester.pumpAndSettle();
        await tester.tap(find.text('CC').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Unassigned').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(
          container.read(
            headerTransportMappingsProvider,
          )[HeaderTransportRole.play],
          isNull,
        );
      },
    );

    testWidgets(
      'awaits persistence completion before closing the editor dialog and announcing save',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        var calls = 0;
        final writeGate = Completer<SharedPreferences>();

        final container = await pumpPerformanceTab(
          tester,
          prefsOverride: () {
            calls++;
            // First call hydrates initial defaults; subsequent write call stalls on writeGate.
            if (calls <= 1) return Future.value(prefs);
            return writeGate.future;
          },
        );
        await container
            .read(headerTransportMappingsProvider.notifier)
            .ensureLoaded();

        final stopCard = find.byKey(
          const ValueKey('transport_assignment_stop'),
        );
        await tester.scrollUntilVisible(
          stopCard,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(stopCard);
        await tester.pumpAndSettle();
        await tester.tap(stopCard);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Unassigned').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Note').last);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, '93');

        await tester.tap(find.text('Save'));
        await tester.pump();

        // While SharedPreferences write is still pending, dialog stays open and save isn't complete.
        expect(find.text('Saving...'), findsOneWidget);
        expect(find.text('Assign Stop'), findsOneWidget);
        expect(find.text('Stop assignment saved'), findsNothing);

        writeGate.complete(prefs);
        await tester.pumpAndSettle();

        expect(find.text('Assign Stop'), findsNothing);
        expect(find.text('Stop assignment saved'), findsOneWidget);
        expect(
          container.read(
            headerTransportMappingsProvider,
          )[HeaderTransportRole.stop],
          const NotePayload(channel: 0, note: 93),
        );
      },
    );
  });
}

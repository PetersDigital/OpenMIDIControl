// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:app/core/models/action_payload.dart';
import 'package:app/ui/midi_service.dart';
import 'package:app/ui/widgets/endless_encoder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _RelativeMidiService implements MidiService {
  final steps = <int>[];

  @override
  Map<String, dynamic> get currentState => {};

  @override
  Stream<Map<String, dynamic>> get uiStateUpdates => const Stream.empty();

  @override
  Future<void> sendRelativeCc(RelativeCcPayload payload, int delta) async {
    steps.add(delta);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('relative encoder sends steps beyond its displayed range', (
    tester,
  ) async {
    final service = _RelativeMidiService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [midiServiceProvider.overrideWithValue(service)],
        child: const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox.square(
                dimension: 200,
                child: EndlessEncoderWidget(
                  cc: 7,
                  showChannelLabel: false,
                  payload: RelativeCcPayload(
                    channel: 4,
                    cc: 27,
                    encoding: RelativeCcEncoding.signedBit,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(EndlessEncoderWidget)),
    );
    await gesture.moveBy(const Offset(0, -30));
    await gesture.moveBy(const Offset(0, -220));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.text('127'), findsOneWidget);
    expect(service.steps, isNotEmpty);

    final count = service.steps.length;
    await gesture.moveBy(const Offset(0, -15));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('127'), findsOneWidget);
    expect(service.steps.skip(count), [10]);
  });
}

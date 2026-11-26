// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:app/core/models/action_payload.dart';
import 'package:app/ui/widgets/midi_action_fields.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('an optional assignment starts unassigned and can be cleared', (
    tester,
  ) async {
    final draft = MidiActionDraft(
      channel: 3,
      identifier: 11,
      allowUnassigned: true,
    );
    addTearDown(draft.dispose);
    final formKey = GlobalKey<FormState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: MidiActionFields(
              draft: draft,
              usesPitchBendPosition: true,
              supportsVariableVelocity: true,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Unassigned'), findsOneWidget);
    expect(find.text('MIDI Channel'), findsNothing);
    expect(formKey.currentState!.validate(), isTrue);
    expect(draft.payload, isNull);

    await tester.tap(find.text('Unassigned'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CC').last);
    await tester.pumpAndSettle();
    expect(formKey.currentState!.validate(), isTrue);
    expect(draft.payload, const CcPayload(channel: 3, cc: 11));

    await tester.tap(find.text('CC'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unassigned').last);
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNothing);
    expect(formKey.currentState!.validate(), isTrue);
    expect(draft.payload, isNull);
  });
}

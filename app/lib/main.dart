import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/open_midi_screen.dart';
import 'ui/midi_service.dart';

void main() {
  runApp(const ProviderScope(child: OpenMIDIApp()));
}

class OpenMIDIApp extends ConsumerStatefulWidget {
  const OpenMIDIApp({super.key});

  @override
  ConsumerState<OpenMIDIApp> createState() => _OpenMIDIAppState();
}

class _OpenMIDIAppState extends ConsumerState<OpenMIDIApp> {
  @override
  Widget build(BuildContext context) {
    // Watch midi connection provider at app root to ensure listeners are active
    ref.watch(connectedMidiDeviceProvider);

    return MaterialApp(
      title: 'OpenMIDIControl',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF033258),
          brightness: Brightness.dark,
        ),
        fontFamily:
            'Inter', // Default modern font for non-DSEG elements, as per DESIGN.md
      ),
      home: const OpenMIDIMainScreen(),
    );
  }
}

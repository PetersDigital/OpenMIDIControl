import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/open_midi_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: OpenMIDIApp(),
    ),
  );
}

class OpenMIDIApp extends StatelessWidget {
  const OpenMIDIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenMIDIControl',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF033258),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto', // Default modern font for non-DSEG elements
      ),
      home: const OpenMIDIMainScreen(),
    );
  }
}

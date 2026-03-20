import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class MidiSettingsScreen extends ConsumerWidget {
  const MidiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        title: Text(
          'MIDI Ports Configuration',
          style: GoogleFonts.spaceGrotesk(
            color: Theme.of(context).colorScheme.primaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primaryContainer),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // Status banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade900.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 28),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'DEVICE DISCONNECTED',
                        style: GoogleFonts.inter(
                          color: Colors.red.shade400,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'MIDI Input/Output port configuration will be implemented here.',
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Currently operating in UI-only mode.',
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'AVAILABLE DEVICES',
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.primaryContainer,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),

          ListTile(
            tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
            leading: const Icon(Icons.usb, color: Colors.white54),
            title: Text(
              'Searching for CoreMIDI / Android MIDI devices...',
              style: GoogleFonts.inter(color: Colors.white70, fontStyle: FontStyle.italic, fontSize: 14),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ],
      ),
    );
  }
}

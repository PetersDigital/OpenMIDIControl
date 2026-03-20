import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'open_midi_screen.dart';


class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentBehavior = ref.watch(faderBehaviorProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        title: Text(
          'Settings',
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
          // App Info Header — centred, compact
          Center(
            child: Column(
              children: [
                const Icon(Icons.settings_input_component, color: Color(0xFFA6C9F8), size: 40),
                const SizedBox(height: 8),
                Text(
                  'OpenMIDIControl',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'v1.0.0 (Build: abcdef)',
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                Text(
                  '© PetersDigital',
                  style: GoogleFonts.inter(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          // Fader Behavior Section
          Text(
            'FADER CONFIGURATION',
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.primaryContainer,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 8),
          ...FaderBehavior.values.map((behavior) {
            final isSelected = currentBehavior == behavior;
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              title: Text(
                behavior.name.toUpperCase(),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                _getBehaviorDescription(behavior),
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              leading: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                size: 22,
              ),
              onTap: () {
                ref.read(faderBehaviorProvider.notifier).updateBehavior(behavior);
              },
            );
          }),

          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          // Layout Section
          Text(
            'LAYOUT',
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.primaryContainer,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 4),
          Builder(builder: (ctx) {
            final hand = ref.watch(layoutHandProvider);
            final faderOnRight = hand == LayoutHand.faderOnRight;
            return SwitchListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text(
                faderOnRight ? 'FADER ON RIGHT' : 'FADER ON LEFT',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                faderOnRight
                    ? 'Controls on left — slide faders with right hand.'
                    : 'Controls on right — slide faders with left hand.',
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              value: faderOnRight,
              activeThumbColor: Theme.of(context).colorScheme.primaryContainer,
              onChanged: (_) =>
                  ref.read(layoutHandProvider.notifier).toggle(),
            );
          }),

          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),

          Text(
            'ADVANCED (COMING SOON)',
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  String _getBehaviorDescription(FaderBehavior behavior) {
    switch (behavior) {
      case FaderBehavior.hybrid:
        return 'Touch anywhere to grab, slide for relative changes.';
      case FaderBehavior.jump:
        return 'Fader snaps instantly to your exact physical touch location.';
      case FaderBehavior.catchUp:
        return 'Touch is ignored until you cross the physical ribbon barrier.';
    }
  }
}

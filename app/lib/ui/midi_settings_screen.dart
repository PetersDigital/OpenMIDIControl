import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'midi_service.dart';

class MidiSettingsScreen extends ConsumerWidget {
  const MidiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(connectedMidiDeviceProvider);
    final connectedDevice = connectionState.connectedDevice;
    final midiStatus = ref.watch(midiStatusProvider);
    final midiDevicesAsyncValue = ref.watch(midiDevicesProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        title: const Text(
          'MIDI Ports Configuration',
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            color: Color(0xFFC3C7CA),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primaryContainer),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // Status banner
          _buildStatusBanner(context, midiStatus, connectedDevice),

          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'AVAILABLE DEVICES',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFFC3C7CA),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                color: const Color(0xFFC3C7CA),
                onPressed: () {
                  ref.read(connectedMidiDeviceProvider.notifier).disconnect();
                  ref.invalidate(midiDevicesProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: 4),

          midiDevicesAsyncValue.when(
            data: (devices) {
              if (devices.isEmpty) {
                return ListTile(
                  tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
                  leading: const Icon(Icons.usb, color: Colors.white54),
                  title: const Text(
                    'No MIDI devices found.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                    ),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                );
              }

              return Column(
                children: devices.map((device) {
                  final isThisDeviceConnected = connectedDevice?.id == device.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: ListTile(
                      tileColor: isThisDeviceConnected
                          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1)
                          : Theme.of(context).colorScheme.surfaceContainerLow,
                      leading: Icon(
                        Icons.usb,
                        color: isThisDeviceConnected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white54,
                      ),
                      title: Text(
                        device.name,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: isThisDeviceConnected ? Colors.white : Colors.white70,
                          fontWeight: isThisDeviceConnected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        device.manufacturer,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isThisDeviceConnected
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                              : Colors.transparent,
                        ),
                      ),
                      onTap: () async {
                        // Prevent connecting to already connected device to avoid unnecessary bridging
                        if (isThisDeviceConnected) return;

                        // Show simple loading feedback
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Connecting to ${device.name}...')),
                        );

                        final success = await ref.read(connectedMidiDeviceProvider.notifier).connect(device);

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          if (!success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to connect to ${device.name}'),
                                backgroundColor: Colors.red.shade800,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: const CircularProgressIndicator(),
              ),
            ),
            error: (error, stackTrace) => ListTile(
              tileColor: Theme.of(context).colorScheme.surfaceContainerLow,
              leading: const Icon(Icons.error_outline, color: Colors.redAccent),
              title: Text(
                'Error loading devices',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                error.toString(),
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context, MidiStatus status, MidiDevice? connectedDevice) {
    Color borderColor;
    IconData icon;
    Color iconColor;
    String titleText;
    Color titleColor;
    String subText;

    switch (status) {
      case MidiStatus.connected:
        borderColor = Colors.green.shade900.withValues(alpha: 0.5);
        icon = Icons.check_circle_outline;
        iconColor = Colors.green.shade400;
        titleText = 'CONNECTED';
        titleColor = Colors.green.shade400;
        subText = connectedDevice != null
            ? 'Connected to ${connectedDevice.name} (${connectedDevice.manufacturer})'
            : 'Connected to a MIDI device';
        break;
      case MidiStatus.available:
        borderColor = const Color(0xFFFFCA28).withValues(alpha: 0.5); // Amber
        icon = Icons.usb;
        iconColor = const Color(0xFFFFCA28);
        titleText = 'MIDI DEVICES AVAILABLE';
        titleColor = const Color(0xFFFFCA28);
        subText = 'Tap a device below to initialize connection.';
        break;
      case MidiStatus.connectionLost:
        borderColor = Colors.red.shade900.withValues(alpha: 0.5);
        icon = Icons.warning_amber_rounded;
        iconColor = Colors.red.shade400;
        titleText = 'CONNECTION LOST';
        titleColor = Colors.red.shade400;
        subText = 'Device was physically disconnected. Please reconnect.';
        break;
      case MidiStatus.disconnected:
        borderColor = Theme.of(context).colorScheme.surfaceContainerHighest;
        icon = Icons.usb_off;
        iconColor = Colors.grey.shade500;
        titleText = 'NO MIDI DEVICES DETECTED';
        titleColor = Colors.grey.shade500;
        subText = 'Please plug in a USB MIDI device.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  titleText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: titleColor,
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
            subText,
            style: TextStyle(
              fontFamily: 'Inter',
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

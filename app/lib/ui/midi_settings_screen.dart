import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'midi_service.dart';
import 'open_midi_screen.dart' show manualPortSelectionProvider, usbModeProvider, UsbMode;


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

          // --- MOVED CONNECTIONS SETTINGS ---
          const Text(
            'CONNECTIONS',
            style: TextStyle(
              fontFamily: 'Inter',
              color: Color(0xFFC3C7CA),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 8),
          Builder(builder: (ctx) {
            final usbMode = ref.watch(usbModeProvider);
            final isPeripheral = usbMode == UsbMode.peripheral;
            return SwitchListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text(
                isPeripheral ? 'USB PERIPHERAL MODE' : 'USB HOST MODE',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                isPeripheral
                    ? 'Acts as a MIDI device for your PC.'
                    : 'Connect external USB MIDI keyboards to this app.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              value: isPeripheral,
              activeThumbColor: Theme.of(context).colorScheme.primaryContainer,
              onChanged: (_) {
                final newMode = isPeripheral ? UsbMode.host : UsbMode.peripheral;
                ref.read(usbModeProvider.notifier).updateMode(newMode);
              },
            );
          }),
          Builder(builder: (ctx) {
            final manualSelection = ref.watch(manualPortSelectionProvider);
            return SwitchListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text(
                'MANUAL PORT SELECTION',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                manualSelection
                    ? 'Showing internal virtual ports in device list.'
                    : 'Hiding internal virtual ports (auto-routing).',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              value: manualSelection,
              activeThumbColor: Theme.of(context).colorScheme.primaryContainer,
              onChanged: (_) => ref.read(manualPortSelectionProvider.notifier).toggle(),
            );
          }),

          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          // --- END MOVED CONNECTIONS SETTINGS ---
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
            data: (allDevices) {
              final manualSelection = ref.watch(manualPortSelectionProvider);
              final devices = allDevices.where((d) => manualSelection || d.manufacturer != 'PetersDigital').toList();
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
                  return _DeviceExpansionTile(
                    device: device,
                    isThisDeviceConnected: isThisDeviceConnected,
                    activeInputPort: isThisDeviceConnected ? connectionState.inputPort : null,
                    activeOutputPort: isThisDeviceConnected ? connectionState.outputPort : null,
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
      case MidiStatus.usbActive:
        borderColor = Colors.green.shade900.withValues(alpha: 0.5);
        icon = Icons.check_circle_outline;
        iconColor = Colors.green.shade400;
        titleText = 'USB HOST MODE ACTIVE';
        titleColor = Colors.green.shade400;
        subText = 'Device is acting as a USB MIDI peripheral to host PC.';
        break;
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

class _DeviceExpansionTile extends ConsumerStatefulWidget {
  final MidiDevice device;
  final bool isThisDeviceConnected;
  final int? activeInputPort;
  final int? activeOutputPort;

  const _DeviceExpansionTile({
    required this.device,
    required this.isThisDeviceConnected,
    this.activeInputPort,
    this.activeOutputPort,
  });

  @override
  ConsumerState<_DeviceExpansionTile> createState() => _DeviceExpansionTileState();
}

class _DeviceExpansionTileState extends ConsumerState<_DeviceExpansionTile> {
  int? _selectedInputPort;
  int? _selectedOutputPort;

  @override
  void initState() {
    super.initState();
    _initializePorts();
  }

  @override
  void didUpdateWidget(covariant _DeviceExpansionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isThisDeviceConnected != oldWidget.isThisDeviceConnected ||
        widget.activeInputPort != oldWidget.activeInputPort ||
        widget.activeOutputPort != oldWidget.activeOutputPort) {
      _initializePorts();
    }
  }

  void _initializePorts() {
    if (widget.isThisDeviceConnected) {
      _selectedInputPort = widget.activeInputPort;
      _selectedOutputPort = widget.activeOutputPort;
    } else {
      if (widget.device.inputPorts.isNotEmpty) {
        _selectedInputPort = widget.device.inputPorts.first.number;
      }
      if (widget.device.outputPorts.isNotEmpty) {
        _selectedOutputPort = widget.device.outputPorts.first.number;
      }
    }
  }

  Future<void> _connect(BuildContext context) async {
    if (widget.isThisDeviceConnected) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connecting to ${widget.device.name}...')),
    );

    final success = await ref.read(connectedMidiDeviceProvider.notifier).connect(
      widget.device,
      inputPort: _selectedInputPort,
      outputPort: _selectedOutputPort,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect to ${widget.device.name}'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedBackgroundColor: widget.isThisDeviceConnected
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surfaceContainerLow,
          backgroundColor: widget.isThisDeviceConnected
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1)
              : Theme.of(context).colorScheme.surfaceContainerLow,
          leading: Icon(
            Icons.usb,
            color: widget.isThisDeviceConnected
                ? Theme.of(context).colorScheme.primary
                : Colors.white54,
          ),
          title: Text(
            widget.device.name,
            style: TextStyle(
              fontFamily: 'Inter',
              color: widget.isThisDeviceConnected ? Colors.white : Colors.white70,
              fontWeight: widget.isThisDeviceConnected ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            widget.device.manufacturer,
            style: TextStyle(
              fontFamily: 'Inter',
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: widget.isThisDeviceConnected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: widget.isThisDeviceConnected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                  : Colors.transparent,
            ),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        flex: 1,
                        child: Text(
                          'Input Port:',
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: widget.device.inputPorts.isEmpty
                            ? const Text('None available', style: TextStyle(color: Colors.white38))
                            : DropdownButton<int>(
                                isExpanded: true,
                                value: _selectedInputPort,
                                dropdownColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                                items: widget.device.inputPorts.map((port) {
                                  final isActive = widget.isThisDeviceConnected && widget.activeInputPort == port.number;
                                  return DropdownMenuItem<int>(
                                    value: port.number,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                      decoration: isActive ? BoxDecoration(
                                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                                        ),
                                      ) : null,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${port.name} (Port ${port.number})',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isActive ? Theme.of(context).colorScheme.primary : Colors.white,
                                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          if (isActive)
                                            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 16),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: widget.isThisDeviceConnected
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _selectedInputPort = value;
                                        });
                                      },
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        flex: 1,
                        child: Text(
                          'Output Port:',
                          style: TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: widget.device.outputPorts.isEmpty
                            ? const Text('None available', style: TextStyle(color: Colors.white38))
                            : DropdownButton<int>(
                                isExpanded: true,
                                value: _selectedOutputPort,
                                dropdownColor: Theme.of(context).colorScheme.surfaceContainerHigh,
                                items: widget.device.outputPorts.map((port) {
                                  final isActive = widget.isThisDeviceConnected && widget.activeOutputPort == port.number;
                                  return DropdownMenuItem<int>(
                                    value: port.number,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                      decoration: isActive ? BoxDecoration(
                                        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                                        ),
                                      ) : null,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${port.name} (Port ${port.number})',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: isActive ? Theme.of(context).colorScheme.primary : Colors.white,
                                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          if (isActive)
                                            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 16),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: widget.isThisDeviceConnected
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _selectedOutputPort = value;
                                        });
                                      },
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: widget.isThisDeviceConnected ? null : () => _connect(context),
                      child: Text(widget.isThisDeviceConnected ? 'Connected' : 'Connect'),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

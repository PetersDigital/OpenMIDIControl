// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'diagnostics_logger.dart';
import '../design_system.dart';

class DiagnosticsConsole extends ConsumerWidget {
  const DiagnosticsConsole({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(diagnosticsProvider);
    final logs = state.entries;

    return Container(
      color: Colors.black, // Dark background
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DIAGNOSTICS LOGGER',
                style: AppText.system(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontSize: 14,
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 20,
                ),
                tooltip: 'Clear Logs',
                onPressed: () {
                  ref.read(diagnosticsProvider.notifier).clear();
                },
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 16),
          Expanded(
            child: logs.isEmpty
                ? const Center(
                    child: Text(
                      'No MIDI events logged yet.',
                      style: TextStyle(
                        color: Colors.white38,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                : ListView.builder(
                    key: ValueKey(state.version),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final entry = logs[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          entry.getFormatted(), // Lazy format on render
                          style: const TextStyle(
                            color: Colors.lightGreenAccent,
                            fontFamily: 'monospace', // Terminal-like font
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system.dart';
import '../../settings_screen.dart';

const _kAccent = Color(0xFFA6C9F8);

class AboutTab extends ConsumerWidget {
  const AboutTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfo = ref.watch(packageInfoProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      children: [
        // Logo + name
        Center(
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _kAccent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _kAccent.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.settings_input_component,
                  color: _kAccent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'OpenMIDIControl',
                style: AppText.performance(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              packageInfo.when(
                data: (info) => _VersionBadge(version: info.version),
                loading: () => const SizedBox(height: 24),
                error: (_, _) => const SizedBox(height: 24),
              ),
              const SizedBox(height: 6),
              Text(
                '© 2026 PetersDigital',
                style: AppText.system(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

class _VersionBadge extends StatelessWidget {
  final String version;
  const _VersionBadge({required this.version});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kAccent.withValues(alpha: 0.3)),
      ),
      child: Text(
        'v$version',
        style: const TextStyle(
          fontFamily: 'Inter',
          color: _kAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

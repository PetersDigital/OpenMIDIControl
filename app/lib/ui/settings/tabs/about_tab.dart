// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system.dart';
import '../../settings_screen.dart';

const _kAccent = Color(0xFFA6C9F8);
const _kCardBg = Color(0xFF1A1C20);
const _kBorderNormal = Color(0x14FFFFFF);

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

        // License info card
        _InfoCard(
          icon: Icons.gavel_outlined,
          title: 'LICENSE',
          body:
              'GPL-3.0-or-later OR LicenseRef-Commercial\n'
              'Dual-licensed for open source and commercial use.',
        ),

        const SizedBox(height: 12),

        // Build info card
        packageInfo.when(
          data: (info) => _InfoCard(
            icon: Icons.build_circle_outlined,
            title: 'BUILD INFO',
            body:
                'Version: ${info.version}\n'
                'Build: ${info.buildNumber}\n'
                'Package: ${info.packageName}',
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
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

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderNormal),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _kAccent, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFFC3C7CA),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

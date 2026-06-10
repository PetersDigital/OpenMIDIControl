// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:package_info_plus/package_info_plus.dart';

import 'design_system.dart';
import 'side_panel_state.dart';
import 'settings/tabs/performance_tab.dart';
import 'settings/tabs/pages_tab.dart';
import 'settings/tabs/files_tab.dart';
import 'settings/tabs/about_tab.dart';

final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return await PackageInfo.fromPlatform();
});

// ---------------------------------------------------------------------------
// Design constants
// ---------------------------------------------------------------------------
const _kBg = Color(0xFF0D0F14);
const _kSurface = Color(0xFF111318);
const _kAccent = Color(0xFFA6C9F8);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    _TabDef(icon: Icons.tune, label: 'PERFORMANCE'),
    _TabDef(icon: Icons.layers, label: 'PAGES'),
    _TabDef(icon: Icons.folder_open, label: 'FILES'),
    _TabDef(icon: Icons.info_outline, label: 'ABOUT'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: MediaQuery.of(context).orientation == Orientation.landscape
            ? IconButton(
                icon: const Icon(Icons.close, color: Colors.white60),
                onPressed: () => ref.read(sidePanelProvider.notifier).hide(),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white60),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          'Settings',
          style: AppText.system(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _SettingsTabBar(controller: _tabController, tabs: _tabs),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [PerformanceTab(), PagesTab(), FilesTab(), AboutTab()],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom tab bar
// ---------------------------------------------------------------------------

class _TabDef {
  final IconData icon;
  final String label;
  const _TabDef({required this.icon, required this.label});
}

class _SettingsTabBar extends StatelessWidget {
  final TabController controller;
  final List<_TabDef> tabs;

  const _SettingsTabBar({required this.controller, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kSurface,
      child: TabBar(
        controller: controller,
        indicatorColor: _kAccent,
        indicatorWeight: 2.5,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: _kAccent,
        unselectedLabelColor: Colors.white38,
        tabs: tabs
            .map(
              (t) => Tab(
                height: 52,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(t.icon, size: 18),
                    const SizedBox(height: 4),
                    Text(
                      t.label,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/layout_models.dart';
import '../layout_state.dart';
import '../design_system.dart';

const _kAccent = Color(0xFFA6C9F8);
const _kSurface = Color(0xFF1E2024);
const _kCardBg = Color(0xFF1A1C20);
const _kBorderNormal = Color(0x14FFFFFF);

class PageSettingsPanel extends ConsumerStatefulWidget {
  final String pageId;

  const PageSettingsPanel({super.key, required this.pageId});

  @override
  ConsumerState<PageSettingsPanel> createState() => _PageSettingsPanelState();
}

class _PageSettingsPanelState extends ConsumerState<PageSettingsPanel> {
  late final TextEditingController _nameController;
  late final TextEditingController _colsController;
  late final TextEditingController _rowsController;

  @override
  void initState() {
    super.initState();
    final page = ref
        .read(layoutStateProvider)
        .pages
        .firstWhere((p) => p.id == widget.pageId);
    _nameController = TextEditingController(text: page.name);
    _colsController = TextEditingController(text: page.gridColumns.toString());
    _rowsController = TextEditingController(text: page.gridRows.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _colsController.dispose();
    _rowsController.dispose();
    super.dispose();
  }

  void _applySettings(int cols, int rows) {
    // Clamp values
    final clampedCols = cols.clamp(4, 32);
    final clampedRows = rows.clamp(2, 16);

    _colsController.text = clampedCols.toString();
    _rowsController.text = clampedRows.toString();

    final page = ref
        .read(layoutStateProvider)
        .pages
        .firstWhere((p) => p.id == widget.pageId);
    int outOfBoundsCount = 0;
    for (final control in page.controls) {
      if (control.x + control.width > clampedCols ||
          control.y + control.height > clampedRows) {
        outOfBoundsCount++;
      }
    }

    ref
        .read(layoutStateProvider.notifier)
        .updatePageGridAndName(
          widget.pageId,
          name: _nameController.text.trim(),
          gridColumns: clampedCols,
          gridRows: clampedRows,
        );

    if (outOfBoundsCount > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$outOfBoundsCount controls repositioned to fit the new grid.',
          ),
          backgroundColor: Colors.orange.shade800,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Unfocus text fields
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final layoutState = ref.watch(layoutStateProvider);
    final page = layoutState.pages.firstWhere(
      (p) => p.id == widget.pageId,
      orElse: () => _buildFallbackPage(),
    );

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: _kSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(-8, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x0AFFFFFF))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.settings, color: _kAccent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'PAGE SETTINGS',
                        style: AppText.system(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _PageTypeBadge(type: page.type),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                // Page Name
                TextField(
                  controller: _nameController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Space Grotesk',
                    fontSize: 18,
                  ),
                  decoration: InputDecoration(
                    labelText: 'PAGE NAME',
                    labelStyle: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      letterSpacing: 1.5,
                    ),
                    filled: true,
                    fillColor: _kCardBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kBorderNormal),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kBorderNormal),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _kAccent),
                    ),
                  ),
                  onSubmitted: (_) =>
                      _applySettings(page.gridColumns, page.gridRows),
                ),

                const SizedBox(height: 32),

                // Grid Size Presets
                Text(
                  'GRID SIZE',
                  style: AppText.system(
                    color: const Color(0xFFC3C7CA),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _GridChip(
                      cols: 8,
                      rows: 4,
                      currentCols: page.gridColumns,
                      currentRows: page.gridRows,
                      onSelect: _applySettings,
                    ),
                    _GridChip(
                      cols: 8,
                      rows: 6,
                      currentCols: page.gridColumns,
                      currentRows: page.gridRows,
                      onSelect: _applySettings,
                    ),
                    _GridChip(
                      cols: 12,
                      rows: 4,
                      currentCols: page.gridColumns,
                      currentRows: page.gridRows,
                      onSelect: _applySettings,
                    ),
                    _GridChip(
                      cols: 16,
                      rows: 4,
                      currentCols: page.gridColumns,
                      currentRows: page.gridRows,
                      onSelect: _applySettings,
                    ),
                    _GridChip(
                      cols: 8,
                      rows: 8,
                      currentCols: page.gridColumns,
                      currentRows: page.gridRows,
                      onSelect: _applySettings,
                    ),
                    _GridChip(
                      cols: 16,
                      rows: 8,
                      currentCols: page.gridColumns,
                      currentRows: page.gridRows,
                      onSelect: _applySettings,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Custom Grid Size
                Row(
                  children: [
                    const Text(
                      'Custom:',
                      style: TextStyle(color: Colors.white60, fontSize: 14),
                    ),
                    const Spacer(),
                    _CustomNumberInput(
                      controller: _colsController,
                      label: 'Cols',
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '×',
                        style: TextStyle(color: Colors.white38, fontSize: 18),
                      ),
                    ),
                    _CustomNumberInput(
                      controller: _rowsController,
                      label: 'Rows',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    final cols =
                        int.tryParse(_colsController.text) ?? page.gridColumns;
                    final rows =
                        int.tryParse(_rowsController.text) ?? page.gridRows;
                    _applySettings(cols, rows);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _kAccent.withValues(alpha: 0.15),
                    foregroundColor: _kAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('APPLY'),
                ),

                const SizedBox(height: 16),
                const Text(
                  '⚠ Shrinking the grid may reposition controls to fit within bounds.',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  LayoutPage _buildFallbackPage() {
    return LayoutPage(
      id: widget.pageId,
      name: 'Unknown',
      type: PageType.utility,
      gridColumns: 8,
      gridRows: 4,
      controls: [],
    );
  }
}

class _GridChip extends StatelessWidget {
  final int cols;
  final int rows;
  final int currentCols;
  final int currentRows;
  final Function(int, int) onSelect;

  const _GridChip({
    required this.cols,
    required this.rows,
    required this.currentCols,
    required this.currentRows,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = cols == currentCols && rows == currentRows;

    return ActionChip(
      label: Text('$cols × $rows'),
      labelStyle: TextStyle(
        fontFamily: 'Space Grotesk',
        color: isSelected ? Colors.black : Colors.white,
        fontWeight: FontWeight.bold,
      ),
      backgroundColor: isSelected ? _kAccent : _kCardBg,
      side: BorderSide(color: isSelected ? Colors.transparent : _kBorderNormal),
      onPressed: () => onSelect(cols, rows),
    );
  }
}

class _CustomNumberInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const _CustomNumberInput({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Space Grotesk',
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 8,
          ),
          filled: true,
          fillColor: _kCardBg,
          hintText: label,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _kBorderNormal),
          ),
        ),
      ),
    );
  }
}

class _PageTypeBadge extends StatelessWidget {
  final PageType type;

  const _PageTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final String label = switch (type) {
      PageType.fader => 'FADER BANK',
      PageType.xyPad => 'XY PAD',
      PageType.drumPad => 'DRUM GRID',
      PageType.utility => 'UTILITY GRID',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models/action_payload.dart';

/// Fixed roles for the nine buttons in the header drop-down 3x3 transport grid.
///
/// Kept intentionally separate from [TransportAction], which is reserved for
/// MCU protocol payloads.
enum HeaderTransportRole {
  rewind('Rewind'),
  up('Up'),
  record('Record'),
  left('Left'),
  stop('Stop'),
  right('Right'),
  fastForward('Fast Forward'),
  down('Down'),
  play('Play');

  const HeaderTransportRole(this.label);

  final String label;

  static HeaderTransportRole? fromKey(String key) {
    for (final role in values) {
      if (role.name == key) return role;
    }
    return null;
  }
}

/// Provides the [SharedPreferences] loader used by [HeaderTransportMappingsNotifier].
final headerTransportPrefsProvider =
    Provider<Future<SharedPreferences> Function()>(
      (ref) => SharedPreferences.getInstance,
    );

/// Stores global MIDI assignments for the 3x3 header transport grid.
///
/// Each role accepts a [CcPayload], [NotePayload], or `null` (Unassigned).
/// Every role defaults to Unassigned so upgrading existing installs never emits
/// unexpected MIDI traffic.
class HeaderTransportMappingsNotifier
    extends Notifier<Map<HeaderTransportRole, ActionPayload>> {
  static const storageKey = 'header_transport_assignments_v1';

  late Future<void> _initialLoad;
  Future<void> _writeChain = Future<void>.value();
  bool _disposed = false;

  static bool isSupportedPayload(ActionPayload? payload) =>
      payload == null || payload is CcPayload || payload is NotePayload;

  /// Resolves the `ControlState.buttonStates` key for a transport assignment.
  static String? feedbackAddress(ActionPayload? payload) => switch (payload) {
    CcPayload(:final channel, :final cc) => '$channel:$cc',
    NotePayload(:final channel, :final note) => 'note:$channel:$note',
    _ => null,
  };

  @override
  Map<HeaderTransportRole, ActionPayload> build() {
    _disposed = false;
    _writeChain = Future<void>.value();
    ref.onDispose(() {
      _disposed = true;
    });
    _initialLoad = _loadFromPrefs();
    return const <HeaderTransportRole, ActionPayload>{};
  }

  /// Completes once initial hydration from [SharedPreferences] finishes.
  Future<void> ensureLoaded() => _initialLoad;

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await ref.read(headerTransportPrefsProvider)();
      if (_disposed) return;

      final raw = prefs.getString(storageKey);
      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;

      final loaded = <HeaderTransportRole, ActionPayload>{};
      for (final entry in decoded.entries) {
        final role = HeaderTransportRole.fromKey(entry.key);
        if (role == null) continue;
        final value = entry.value;
        if (value is! Map<String, dynamic>) continue;
        try {
          final payload = ActionPayload.fromJson(value);
          if (payload is CcPayload || payload is NotePayload) {
            loaded[role] = payload;
          }
        } catch (_) {
          // Ignore malformed or incompatible entries and keep role unassigned.
        }
      }

      if (_disposed) return;
      state = Map.unmodifiable(loaded);
    } catch (_) {
      // Fall back to all-unassigned defaults if preferences cannot be read.
    }
  }

  /// Persists a CC, Note, or Unassigned (`null`) assignment for [role].
  Future<void> setAssignment(HeaderTransportRole role, ActionPayload? payload) {
    if (!isSupportedPayload(payload)) {
      throw ArgumentError.value(
        payload,
        'payload',
        'Header transport assignments only support CC, Note, or Unassigned.',
      );
    }

    final future = _writeChain.then((_) async {
      await _initialLoad;
      if (_disposed) return;

      final next = Map<HeaderTransportRole, ActionPayload>.of(state);
      if (payload == null) {
        next.remove(role);
      } else {
        next[role] = payload;
      }

      final prefs = await ref.read(headerTransportPrefsProvider)();
      if (_disposed) return;

      final encoded = jsonEncode({
        for (final entry in next.entries) entry.key.name: entry.value.toJson(),
      });
      final saved = await prefs.setString(storageKey, encoded);
      if (!saved) {
        throw StateError('Failed to persist header transport mappings.');
      }
      if (_disposed) return;
      state = Map.unmodifiable(next);
    });

    _writeChain = future.catchError((_) {});
    return future;
  }

  /// Clears [role] back to Unassigned and persists the change.
  Future<void> clearAssignment(HeaderTransportRole role) =>
      setAssignment(role, null);
}

final headerTransportMappingsProvider =
    NotifierProvider<
      HeaderTransportMappingsNotifier,
      Map<HeaderTransportRole, ActionPayload>
    >(HeaderTransportMappingsNotifier.new);

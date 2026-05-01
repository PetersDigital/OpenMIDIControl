// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A mixin for [ConsumerState] that standardises the performance hardening
/// boilerplate shared across all interactive MIDI widgets:
///
/// - **App lifecycle observation**: Automatically suspends all managed tickers
///   when the app is backgrounded and resumes them if the widget requests it.
/// - **Managed VRR tickers**: Create tickers via [createManagedTicker]; all
///   tickers are stopped and disposed together on unmount.
/// - **Managed Riverpod subscriptions**: Register manual subscriptions via
///   [addManagedSubscription]; all are closed on [dispose].
///
/// ### Usage
/// ```dart
/// class _MyWidgetState extends ConsumerState<MyWidget>
///     with TickerProviderStateMixin, PerformanceTickerMixin {
///   late Ticker _vrrTicker;
///
///   @override
///   void initState() {
///     super.initState();
///     initPerformanceMixin();  // ← required call
///     _vrrTicker = createManagedTicker(_onTick);
///     addManagedSubscription(ref.listenManual(...));
///   }
/// }
/// ```
///
/// **Note**: The state must also mix in [TickerProviderStateMixin] so that
/// [createManagedTicker] has a [TickerProvider] to call through to.
mixin PerformanceTickerMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, WidgetsBindingObserver {
  final List<Ticker> _managedTickers = [];
  final List<ProviderSubscription<dynamic>> _managedSubscriptions = [];

  /// Must be called at the top of [State.initState] (after `super.initState()`)
  /// to register this widget as a [WidgetsBindingObserver].
  void initPerformanceMixin() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Creates a [Ticker] and registers it for centralised lifecycle management.
  ///
  /// The caller is responsible for starting the ticker; this mixin only stops
  /// and disposes it on [dispose] / app backgrounding.
  Ticker createManagedTicker(TickerCallback onTick) {
    // Forward to the TickerProviderStateMixin's createTicker so the ticker
    // is correctly linked to the widget's [TickerProvider].
    final ticker = (this as TickerProvider).createTicker(onTick);
    _managedTickers.add(ticker);
    return ticker;
  }

  /// Registers a manual Riverpod [ProviderSubscription] for centralised
  /// disposal. Call this immediately after `ref.listenManual(...)`.
  void addManagedSubscription(ProviderSubscription<dynamic> sub) {
    _managedSubscriptions.add(sub);
  }

  /// Safely starts a ticker, guarding against 'already active' or 'disposed'
  /// exceptions. This is the preferred way to start any [_vrrTicker].
  void safeStartTicker(Ticker? ticker) {
    if (ticker != null && !ticker.isActive && !ticker.muted) {
      ticker.start();
    }
  }

  /// Clears all managed tickers and subscriptions without removing the observer.
  /// Useful for re-configuring a widget reactively.
  void clearManagedResources() {
    for (final ticker in _managedTickers) {
      ticker.dispose();
    }
    _managedTickers.clear();
    for (final sub in _managedSubscriptions) {
      sub.close();
    }
    _managedSubscriptions.clear();
  }

  // ---------------------------------------------------------------------------
  // WidgetsBindingObserver
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      // Suspend all tickers to eliminate render-loop drain while backgrounded.
      for (final ticker in _managedTickers) {
        ticker.stop();
      }
    }
    // Tickers are NOT restarted here — each widget is responsible for
    // restarting its own ticker on the next interaction event. This prevents
    // spurious polls when the app foregrounds without user input.
  }

  // ---------------------------------------------------------------------------
  // Centralised disposal
  // ---------------------------------------------------------------------------

  /// **Must** be called from the widget's [State.dispose] *before*
  /// `super.dispose()`.
  void disposePerformanceMixin() {
    WidgetsBinding.instance.removeObserver(this);
    for (final ticker in _managedTickers) {
      ticker.dispose();
    }
    _managedTickers.clear();
    for (final sub in _managedSubscriptions) {
      sub.close();
    }
    _managedSubscriptions.clear();
  }
}

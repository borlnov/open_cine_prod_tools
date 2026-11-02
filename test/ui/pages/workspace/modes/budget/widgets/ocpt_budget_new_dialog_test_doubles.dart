// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';

/// The navigator [wrap] mounts, so [RecordingRouterManager.pop] can close a dialog opened through
/// `showDialog` (step 2's own trailing create row) on top of the wizard itself — mirrors
/// `budget_mode_test_doubles.dart`'s own instance of this pattern.
final navigatorKey = GlobalKey<NavigatorState>();

/// A router manager whose [pop] records the last call and its value — mirrors
/// `ocpt_budget_entry_dialog_test.dart`'s own instance of this pattern — **and** pops
/// [navigatorKey]'s own navigator when there is a route left to pop, so a nested dialog's own
/// `Save` actually closes it and resolves the `Future` the wizard awaits it through. The wizard
/// itself is pumped as the app's home content rather than pushed as a route, so its own top-level
/// `pop` finds nothing left to pop and only records, exactly as every other test here already
/// relies on.
class RecordingRouterManager extends OcptRouterManager {
  /// Whether the dialog popped.
  bool popped = false;

  /// The value the dialog popped with.
  Object? poppedValue;

  /// Record the pop and its value, then pop the route of the test's own navigator, when it can pop.
  @override
  void pop<Y extends Object?>([Y? result]) {
    popped = true;
    poppedValue = result;

    final navigator = navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop(result);
    }
  }
}

/// Wraps [child] with the localization delegates and [navigatorKey] so [Tr.of] lookups resolve in
/// tests and a nested dialog can be popped.
Widget wrap(Widget child) => MaterialApp(
  navigatorKey: navigatorKey,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: child,
);

/// A minimal account, everything but [id]/[label]/[lines] neutral.
OcptBudgetAccount testAccount({
  required String id,
  required String label,
  List<OcptBudgetLine> lines = const [],
}) => OcptBudgetAccount(
  id: id,
  code: "1",
  label: label,
  simpleLabel: null,
  estimateToCompleteCents: null,
  sortKey: "a0",
  lines: lines,
);

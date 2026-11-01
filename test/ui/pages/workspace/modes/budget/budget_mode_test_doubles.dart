// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';

/// The navigator [wrapWithLocalization] mounts, so [RecordingRouterManager.pop] can close a
/// dialog opened through `showDialog` — mirrors `schedule_mode_test.dart`'s own instance of this
/// pattern.
final navigatorKey = GlobalKey<NavigatorState>();

/// A router manager whose [pop] pops [navigatorKey]'s own navigator.
class RecordingRouterManager extends OcptRouterManager {
  @override
  void pop<Y extends Object?>([Y? result]) {
    final navigator = navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop(result);
    }
  }
}

/// Wraps [child] with the localization delegates, [navigatorKey], [ocpt_theme.ocptTheme]'s light theme and a
/// bare [Scaffold] — mirrors `schedule_mode_test.dart`'s own `wrapWithLocalization`.
Widget wrapWithLocalization(Widget child) => MaterialApp(
  navigatorKey: navigatorKey,
  theme: ocpt_theme.ocptTheme.lightThemeData,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: child),
);

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve (the shell's own
/// toolbar reads them for its tooltips), a wide test surface so the docks row has room for both
/// docks plus the centre floor, and a [Scaffold] (as the real workspace page already provides):
/// the episode selector's trigger is a [PopupMenuButton] built with its own `child`, which wraps
/// it in a plain [InkWell] rather than a self-contained button, so it needs a [Material] ancestor
/// to paint into.
///
/// [theme] is the application's own only where a test measures the chrome: the stock theme's
/// [Divider] is 16 px tall, which alone takes the toolbar's own band down from 44 px to 28, so a
/// height read under it is not the height the app draws.
Widget wrapInApp(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: child),
);

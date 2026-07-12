// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';

/// Builds the root [MaterialApp] shell of the application.
class MainAppUi extends StatelessWidget {
  /// Creates the main app widget.
  const MainAppUi({super.key});

  @override
  Widget build(BuildContext context) {
    final router = globalGetIt().get<OcptRouterManager>().router;

    return MaterialApp.router(
      // The app title is the one displayed in the window title bar.
      onGenerateTitle: (context) => Tr.of(context).appTitle,
      routerConfig: router,
      theme: ocpt_theme.ocptTheme.lightThemeData,
      darkTheme: ocpt_theme.ocptTheme.darkThemeData,
      localizationsDelegates: const [
        Tr.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: Tr.delegate.supportedLocales,
      builder: (context, child) {
        OcptGlobalManager.instance.initInFirstView(context);

        return child ?? const SizedBox.shrink();
      },
    );
  }
}

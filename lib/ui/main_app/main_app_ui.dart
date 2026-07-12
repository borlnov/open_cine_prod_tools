// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/app_constants.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_page.dart';

/// Builds the root [MaterialApp] shell of the application.
///
/// Routing is not wired yet: it arrives once the router manager is added, at
/// which point the `home` property will be replaced by a `routerConfig`.
class MainAppUi extends StatelessWidget {
  /// Creates the main app widget.
  const MainAppUi({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: appTitle,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      useMaterial3: true,
    ),
    home: const HomePage(),
    builder: (context, child) {
      OcptGlobalManager.instance.initInFirstView(context);

      return child ?? const SizedBox.shrink();
    },
  );
}

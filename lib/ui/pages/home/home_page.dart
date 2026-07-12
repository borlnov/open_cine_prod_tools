// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/app_constants.dart';

/// Displays the application name as a temporary landing page.
///
/// This is a placeholder home screen; it will be replaced by real navigation
/// and content once routing is introduced.
class HomePage extends StatelessWidget {
  /// Creates the home page.
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Text(appTitle),
    ),
  );
}

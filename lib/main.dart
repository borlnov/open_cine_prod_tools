// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// The display name of the application, shown on the home screen.
const String appName = 'Open Cine Prod Tools';

/// Starts the application.
void main() {
  runApp(const MainApp());
}

/// The root widget of the application.
///
/// This is a placeholder shell that will be replaced by the real application
/// as the production tools are implemented.
class MainApp extends StatelessWidget {
  /// Constructs the [MainApp] widget.
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: appName,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const Scaffold(
          body: Center(
            child: Text(appName),
          ),
        ),
      );
}

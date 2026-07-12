// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// Displays a full-screen error when the global manager fails to initialize.
///
/// Since the normal manager infrastructure (config, logger, ...) may not be
/// available at this point, this widget is self-contained: it builds its own
/// minimal [MaterialApp] and uses hardcoded strings.
class FatalErrorPage extends StatelessWidget {
  /// The error that caused the initialization to fail.
  final Object error;

  /// Creates a fatal error page reporting the given [error].
  const FatalErrorPage({super.key, required this.error});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong while starting the app',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SelectableText(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

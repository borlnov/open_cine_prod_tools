// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// Displays a full-screen error when the global manager fails to initialize.
///
/// Since the normal manager infrastructure (config, logger, router, ...) may not be available at
/// this point, this widget is self-contained: it builds its own minimal [MaterialApp].
class FatalErrorPage extends StatelessWidget {
  /// The error that caused the initialization to fail.
  final Object error;

  /// Creates a fatal error page reporting the given [error].
  const FatalErrorPage({super.key, required this.error});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ocpt_theme.ocptTheme.lightThemeData,
    darkTheme: ocpt_theme.ocptTheme.darkThemeData,
    localizationsDelegates: const [
      Tr.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: Tr.delegate.supportedLocales,
    home: Builder(
      builder: (context) {
        final tr = Tr.of(context);
        final colorScheme = Theme.of(context).colorScheme;

        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: colorScheme.error, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    tr.fatalErrorTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr.fatalErrorMessage,
                    textAlign: TextAlign.center,
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
        );
      },
    ),
  );
}

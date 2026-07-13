// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// Displays the settings as a temporary landing page.
///
/// This is a placeholder page; it will be replaced by the real settings
/// content once the feature is implemented.
class SettingsPage extends StatelessWidget {
  /// Creates the settings page.
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Text(Tr.of(context).settingsPageTitle),
    ),
  );
}

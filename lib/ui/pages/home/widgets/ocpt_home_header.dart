// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_logo.dart';

/// The side of the application logo standing next to the home page's title: big enough to read as
/// the app's mark on the one page that has room for it, small enough to stay under the title's own
/// line height.
const double _logoSize = 32;

/// The top region of the home page: the app logo and title, and the two primary actions of the
/// page.
class OcptHomeHeader extends StatelessWidget {
  /// Called when the user taps the "New project" action.
  final VoidCallback onNewProject;

  /// Called when the user taps the "Open…" action.
  final VoidCallback onOpenProject;

  /// Called when the user taps the "Import…" action, opening `OcptHomeImportDialog`.
  final VoidCallback onImport;

  /// Called when the user taps the settings gear action.
  final VoidCallback onOpenSettings;

  /// Class constructor
  const OcptHomeHeader({
    required this.onNewProject,
    required this.onOpenProject,
    required this.onImport,
    required this.onOpenSettings,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Row(
      children: [
        const OcptLogo(size: _logoSize),
        const SizedBox(width: 12),
        Expanded(
          child: Text(tr.appTitle, style: Theme.of(context).textTheme.headlineSmall),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: onOpenSettings,
          icon: const Icon(Icons.settings_outlined),
          tooltip: tr.homeSettingsTooltip,
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: onImport,
          icon: const Icon(Icons.file_download_outlined),
          label: Text(tr.homeImportAction),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: onOpenProject,
          icon: const Icon(Icons.folder_open_outlined),
          label: Text(tr.homeOpenProjectAction),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: onNewProject,
          icon: const Icon(Icons.add),
          label: Text(tr.homeNewProjectAction),
        ),
      ],
    );
  }
}

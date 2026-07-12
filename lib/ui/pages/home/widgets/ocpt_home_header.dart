// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The top region of the home page: the app title, and the two primary actions of the page.
class OcptHomeHeader extends StatelessWidget {
  /// Called when the user taps the "New project" action.
  final VoidCallback onNewProject;

  /// Called when the user taps the "Open…" action.
  final VoidCallback onOpenProject;

  /// Class constructor
  const OcptHomeHeader({required this.onNewProject, required this.onOpenProject, super.key});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(tr.appTitle, style: Theme.of(context).textTheme.headlineSmall),
        ),
        const SizedBox(width: 16),
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

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_logo.dart';
import 'package:open_cine_prod_tools/utils/ocpt_responsive.dart';

/// The side of the application logo standing next to the home page's title: big enough to read as
/// the app's mark on the one page that has room for it, small enough to stay under the title's own
/// line height.
const double _logoSize = 32;

/// The top region of the home page: the app logo and title, and the two primary actions of the
/// page.
class OcptHomeHeader extends StatelessWidget {
  /// Called when the user taps the "New project" action.
  ///
  /// Only wired at wide width — [ocptCompactWidthBreakpoint] and above — where "New project"
  /// still shows in the header itself; at compact width the page's own floating action button
  /// takes over that action and this field is unused by [build].
  final VoidCallback onNewProject;

  /// Called when the user taps the "Open…" action.
  final VoidCallback onOpenProject;

  /// Called when the user taps the "Import…" action, opening `OcptHomeImportDialog`.
  final VoidCallback onImport;

  /// Called when the user taps the "Join a shared project…" action, navigating to the Rejoindre
  /// screen (`OcptRoute.joining`).
  final VoidCallback onJoinSharedProject;

  /// Called when the user taps the settings gear action.
  final VoidCallback onOpenSettings;

  /// Class constructor
  const OcptHomeHeader({
    required this.onNewProject,
    required this.onOpenProject,
    required this.onImport,
    required this.onJoinSharedProject,
    required this.onOpenSettings,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = ocptIsCompactWidth(constraints.maxWidth);

        return Row(
          children: [
            const OcptLogo(size: _logoSize),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr.appTitle,
                style: Theme.of(context).textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 16),
            if (isCompact)
              ..._buildCompactActions(tr)
            else
              ..._buildWideActions(tr),
          ],
        );
      },
    );
  }

  /// The wide layout: today's five actions side by side, unchanged.
  List<Widget> _buildWideActions(Tr tr) => [
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
      onPressed: onJoinSharedProject,
      icon: const Icon(Icons.qr_code_scanner_outlined),
      label: Text(tr.homeJoinSharedProjectAction),
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
  ];

  /// The compact layout: every action collapses into a single overflow menu, and "New project"
  /// itself is dropped — the home page shows it as a floating action button instead, which reaches
  /// further down a phone-sized screen than a header button would.
  List<Widget> _buildCompactActions(Tr tr) => [
    MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.folder_open_outlined),
          onPressed: onOpenProject,
          child: Text(tr.homeOpenProjectAction),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.file_download_outlined),
          onPressed: onImport,
          child: Text(tr.homeImportAction),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.qr_code_scanner_outlined),
          onPressed: onJoinSharedProject,
          child: Text(tr.homeJoinSharedProjectAction),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.settings_outlined),
          onPressed: onOpenSettings,
          child: Text(tr.homeSettingsTooltip),
        ),
      ],
      builder: (context, controller, child) => IconButton(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.more_vert),
        // Flutter's own generic "Show menu" string, not a bespoke ARB key: this button behaves
        // exactly like `PopupMenuButton`'s default trigger, just built from `MenuAnchor` so the
        // menu items stay `MenuItemButton`s.
        tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      ),
    ),
  ];
}

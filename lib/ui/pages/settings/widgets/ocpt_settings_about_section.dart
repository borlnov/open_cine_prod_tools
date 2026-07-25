// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:url_launcher/url_launcher.dart';

/// The URL of the application's GitHub repository, opened by the "GitHub repository" row.
const _githubRepositoryUrl = "https://github.com/borlnov/open_cine_prod_tools";

/// The settings page's "About" section card: the app name, its version, its license, a link to
/// the GitHub repository, and a row opening the third-party licenses page.
class OcptSettingsAboutSection extends StatelessWidget {
  /// The application version, as resolved by the settings bloc.
  final String appVersion;

  /// Class constructor
  const OcptSettingsAboutSection({required this.appVersion, super.key});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr.settingsAboutSectionTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(tr.appTitle, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text(tr.settingsAboutVersionLabel(appVersion), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              // SPDX identifiers aren't translated content, unlike every other string here.
              "Apache-2.0",
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            _OcptAboutRow(
              icon: Icons.open_in_new,
              label: tr.settingsAboutGithubRepositoryAction,
              onTap: _openGithubRepository,
            ),
            const SizedBox(height: 8),
            _OcptAboutRow(
              icon: Icons.chevron_right,
              label: tr.settingsAboutLicensesAction,
              onTap: () => globalGetIt().get<OcptRouterManager>().push(OcptRoute.licenses),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the GitHub repository URL in the system browser.
  ///
  /// This is fire-and-forget, UI-only navigation to an external application: it doesn't go
  /// through the router manager (which only handles in-app navigation) or the bloc.
  static Future<void> _openGithubRepository() async {
    await launchUrl(Uri.parse(_githubRepositoryUrl), mode: LaunchMode.externalApplication);
  }
}

/// A single tappable row of [OcptSettingsAboutSection], styled like a link.
class _OcptAboutRow extends StatelessWidget {
  /// The icon shown at the start of the row.
  final IconData icon;

  /// The label shown next to [icon].
  final String label;

  /// Called when the row is tapped.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptAboutRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: colorScheme.primary)),
          ],
        ),
      ),
    );
  }
}

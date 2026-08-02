// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_version_summary_line.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';

/// The separator between the banner's headline and the previewed version's own note, matching the
/// dash the mock-up joins them with.
const _headlineSeparator = " — ";

/// The full-width band announcing that what the workspace shows is a project version being
/// previewed read-only, sitting between the toolbar and the docks row (the shell's `banner` slot).
///
/// It is the one place that says *which* version is on screen: the headline names it and quotes the
/// user's note, and the line under it repeats the very summary the version's own card carries — the
/// date it was created, and the counters measured at that moment (see
/// [ocptProjectVersionSummaryLine]).
///
/// Built once here and used by **every** production mode, like the versions panel it belongs with:
/// a preview is a state of the project, not of the mode looking at it, so the same band appears
/// whichever mode the user switches to while one is up.
///
/// Painted in [ocptWarningColor] rather than the error colour: previewing a version is a deliberate
/// state to be aware of and to come back from, not something that went wrong.
///
/// `Start from this version` — the fork the mock-up puts next to [onExitPreview] — is deliberately
/// absent: forking rewrites the project, and it lands with the restore operation itself.
class OcptWorkspaceReadOnlyBanner extends StatelessWidget {
  /// The version currently being previewed read-only.
  final OcptProjectVersion version;

  /// Called when `Back to the current version` is clicked, putting the working copy back on
  /// screen.
  final VoidCallback onExitPreview;

  /// Class constructor
  const OcptWorkspaceReadOnlyBanner({
    super.key,
    required this.version,
    required this.onExitPreview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final color = ocptWarningColor(context);

    return Container(
      width: double.infinity,
      color: color.withValues(alpha: ocptSelectedStateAlpha),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _headline(tr),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  ocptProjectVersionSummaryLine(context, version),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Filled with the banner's own warning colour rather than the accent, so the way out
          // reads as the answer to the state it sits in; the label takes the theme's `surface`,
          // exactly as the shot list's `Needs checking` callout does with the same pair of colours.
          FilledButton(
            onPressed: onExitPreview,
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: theme.colorScheme.surface,
            ),
            child: Text(tr.workspaceReadOnlyBannerExitAction),
          ),
        ],
      ),
    );
  }

  /// The banner's headline: `Read only — <version name>`, followed by the user's own note when
  /// they wrote one, exactly as the mock-up reads it (`Read only — v3 — Before the seq. 1
  /// rewrite`).
  String _headline(Tr tr) => [
    tr.workspaceReadOnlyBannerTitle(version.name),
    if (version.note.isNotEmpty) version.note,
  ].join(_headlineSeparator);
}

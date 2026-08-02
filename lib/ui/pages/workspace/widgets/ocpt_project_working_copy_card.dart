// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_working_copy_state.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_version_summary_line.dart';

/// The `Versions` dock tab's first entry: not a sealed version but the working copy itself, the
/// present the sealed history underneath is measured against.
///
/// Same gabarit as `OcptProjectVersionCard` — the same `Card`, padding, status dot and
/// title/summary/footer rhythm — so the two read as one list, but this one carries no badge and is
/// not clickable: there is nothing to preview here, it is what is already on screen. Three mutually
/// exclusive state lines, read from [OcptProjectWorkingCopyState.isModifiedSinceBase] and
/// [baseVersionName]:
///
/// - `Identical to "<base name>"` — the working copy's content matches the version it descends
///   from.
/// - `Modified since "<base name>"` — it has drifted from that version.
/// - `Not based on any version` — the project has never had one, so there is nothing to compare
///   against.
///
/// `Create a version` is this card's own action rather than the panel's: capturing the working copy
/// is precisely what turns it into the next sealed entry of the list.
class OcptProjectWorkingCopyCard extends StatelessWidget {
  /// The working copy's live state: its counters and how it compares to its base.
  final OcptProjectWorkingCopyState workingCopy;

  /// The name of the version [OcptProjectWorkingCopyState.baseVersionId] names, or null when the
  /// working copy has no base (a project that never had a version, or whose base was deleted from
  /// under it).
  final String? baseVersionName;

  /// Called when `Create a version` is clicked.
  final VoidCallback onCreateRequested;

  /// Class constructor
  const OcptProjectWorkingCopyCard({
    super.key,
    required this.workingCopy,
    required this.baseVersionName,
    required this.onCreateRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr.projectWorkingCopyTitle,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              ocptProjectVersionSummaryLine(context, summary: workingCopy.summary),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _stateLine(tr),
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onCreateRequested,
                icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                label: Text(tr.projectVersionsCreateAction),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The state line under the counters: whether the working copy still matches [baseVersionName],
  /// or that it has none to compare against at all.
  String _stateLine(Tr tr) {
    final baseVersionName = this.baseVersionName;
    if (baseVersionName == null) {
      return tr.projectWorkingCopyNoBaseHint;
    }

    return workingCopy.isModifiedSinceBase
        ? tr.projectWorkingCopyModifiedHint(baseVersionName)
        : tr.projectWorkingCopyIdenticalHint(baseVersionName);
  }
}

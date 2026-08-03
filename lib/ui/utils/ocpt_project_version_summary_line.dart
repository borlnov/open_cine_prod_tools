// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version_summary.dart';

/// The separator joining the parts of a version's summary line, matching the one every other
/// summary line of the workspace joins with.
const _summarySeparator = " · ";

/// The line summarising [summary]: the counters measured at the moment it was captured, e.g.
/// `41 pages · 3 sequences broken down`, preceded by [createdAt] when the caller has one to show
/// — e.g. `12 Mar 2026, 18:42 · 41 pages · 3 sequences broken down`.
///
/// Shared by the version card, the working copy card and the read-only preview banner: a
/// version's counters read the same wherever they are shown. Only a stored version has a creation
/// date to lead with; the working copy is measured right now, so its card leaves [createdAt] null
/// and the line starts directly with the counters.
///
/// The date is absolute rather than relative (unlike a home-page project card's own): a version is
/// production history, read months later, where "3 days ago" says nothing.
String ocptProjectVersionSummaryLine(
  BuildContext context, {
  required OcptProjectVersionSummary summary,
  DateTime? createdAt,
}) {
  final tr = Tr.of(context);

  return [
    if (createdAt != null)
      DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_Hm().format(createdAt),
    tr.editorStatsPages(summary.pageCount),
    tr.projectVersionSequencesBrokenDown(summary.brokenDownSequenceCount),
  ].join(_summarySeparator);
}

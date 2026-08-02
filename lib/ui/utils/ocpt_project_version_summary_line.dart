// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_version.dart';

/// The separator joining the parts of a version's summary line, matching the one every other
/// summary line of the workspace joins with.
const _summarySeparator = " · ";

/// The line summarising [version]: when it was created, then the counters measured at that very
/// moment — e.g. `12 Mar 2026, 18:42 · 41 pages · 3 sequences broken down`.
///
/// Shared by the version card and the read-only preview banner, which the mock-up gives the very
/// same line: a version summarises itself the same way wherever it is shown.
///
/// The date is absolute rather than relative (unlike a home-page project card's own): a version is
/// production history, read months later, where "3 days ago" says nothing.
String ocptProjectVersionSummaryLine(BuildContext context, OcptProjectVersion version) {
  final tr = Tr.of(context);

  return [
    DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_Hm().format(version.createdAt),
    tr.editorStatsPages(version.summary.pageCount),
    tr.projectVersionSequencesBrokenDown(version.summary.brokenDownSequenceCount),
  ].join(_summarySeparator);
}

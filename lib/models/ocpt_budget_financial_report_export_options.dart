// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// The options a one-off financial report export runs with: the physical page [format], its
/// [margins], and whether the title page is printed.
///
/// [margins] is always carried through unedited from the `OcptPageSetup` the export dialog was
/// opened with, exactly as `OcptDayOutOfDaysExportOptions.margins` is, and these options are never
/// persisted — they only exist for the single export they were built for.
///
/// **No tax basis here**, unlike `OcptBudgetQuoteExportOptions`: this report reads the quote
/// against what has actually moved — paid, committed, and the financing plan's own resources — and
/// every one of those is read tax-inclusive always (`docs/architecture/budget.md`), the very
/// reading `OcptBudgetDashboard`'s own needs/resources balance already gives the quote for the same
/// comparison. Offering a basis toggle here would let the quoted column disagree with the actual
/// figures it is measured against while looking like it measured the same thing.
///
/// Deliberately its own class rather than one of its siblings with fields added, for the reason
/// `OcptDayOutOfDaysExportOptions`'s own doc comment already gives: each export is dispatched by its
/// own event, and a shared options class would let one dialog produce something another service
/// silently ignores.
class OcptBudgetFinancialReportExportOptions extends Equatable {
  /// The physical page format to typeset the exported document with.
  final OcptPageFormat format;

  /// The page margins to typeset the exported document with, carried through unedited from the page
  /// setup the export dialog was opened with.
  final FountainPageMargins margins;

  /// Whether the title page (the document's own name and the moment it was produced) is printed
  /// first.
  final bool includeTitlePage;

  /// Class constructor
  const OcptBudgetFinancialReportExportOptions({
    required this.format,
    required this.margins,
    required this.includeTitlePage,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetFinancialReportExportOptions(format: $format, margins: $margins, "
      "includeTitlePage: $includeTitlePage)";

  /// Object properties
  @override
  List<Object?> get props => [format, margins, includeTitlePage];
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// The options a one-off financing plan export runs with: the physical page [format], its
/// [margins], and whether the title page is printed.
///
/// [margins] is always carried through unedited from the `OcptPageSetup` the export dialog was
/// opened with, exactly as `OcptDayOutOfDaysExportOptions.margins` is, and these options are never
/// persisted — they only exist for the single export they were built for.
///
/// **No tax basis here**, unlike `OcptBudgetQuoteExportOptions`: a financing resource is money
/// coming in, always read tax-inclusive (`docs/architecture/budget.md`'s own "Money that has moved
/// is read tax-inclusive, always"), so there is no second basis for this document to offer a choice
/// between.
///
/// Deliberately its own class rather than one of its siblings with fields added, for the reason
/// `OcptDayOutOfDaysExportOptions`'s own doc comment already gives: each export is dispatched by its
/// own event, and a shared options class would let one dialog produce something another service
/// silently ignores.
class OcptBudgetFinancingPlanExportOptions extends Equatable {
  /// The physical page format to typeset the exported document with.
  final OcptPageFormat format;

  /// The page margins to typeset the exported document with, carried through unedited from the page
  /// setup the export dialog was opened with.
  final FountainPageMargins margins;

  /// Whether the title page (the document's own name and the moment it was produced) is printed
  /// first.
  final bool includeTitlePage;

  /// Class constructor
  const OcptBudgetFinancingPlanExportOptions({
    required this.format,
    required this.margins,
    required this.includeTitlePage,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetFinancingPlanExportOptions(format: $format, margins: $margins, "
      "includeTitlePage: $includeTitlePage)";

  /// Object properties
  @override
  List<Object?> get props => [format, margins, includeTitlePage];
}

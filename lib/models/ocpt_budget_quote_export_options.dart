// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// The options a one-off quote export runs with: the physical page [format], its [margins], whether
/// the title page is printed, and the tax basis every line and total is printed in.
///
/// [margins] is always carried through unedited from the `OcptPageSetup` the export dialog was
/// opened with, exactly as `OcptDayOutOfDaysExportOptions.margins` is, and these options are never
/// persisted — they only exist for the single export they were built for.
///
/// [taxBasis] mirrors the header's own excluding/including-tax toggle
/// (`docs/architecture/budget.md`): a quote is a plan, read either way depending on who is looking
/// at it, so the export asks the same question the screen already does rather than picking one for
/// the reader.
///
/// Deliberately its own class rather than one of its siblings with fields added, for the reason
/// `OcptDayOutOfDaysExportOptions`'s own doc comment already gives: each export is dispatched by its
/// own event, and a shared options class would let one dialog produce something another service
/// silently ignores.
class OcptBudgetQuoteExportOptions extends Equatable {
  /// The physical page format to typeset the exported document with.
  final OcptPageFormat format;

  /// The page margins to typeset the exported document with, carried through unedited from the page
  /// setup the export dialog was opened with.
  final FountainPageMargins margins;

  /// Whether the title page (the document's own name and the moment it was produced) is printed
  /// first.
  final bool includeTitlePage;

  /// The tax basis every line and every total is read in, mirroring the header's own toggle.
  final OcptBudgetTaxBasis taxBasis;

  /// Class constructor
  const OcptBudgetQuoteExportOptions({
    required this.format,
    required this.margins,
    required this.includeTitlePage,
    required this.taxBasis,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetQuoteExportOptions(format: $format, margins: $margins, "
      "includeTitlePage: $includeTitlePage, taxBasis: $taxBasis)";

  /// Object properties
  @override
  List<Object?> get props => [format, margins, includeTitlePage, taxBasis];
}

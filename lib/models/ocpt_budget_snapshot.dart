// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';

/// The whole budget mode's read, in one object: the [postes] with their lines, the project's own
/// [defaultVatRateBasisPoints] and [currencyCode], and the two counts the status bar shows
/// — `N postes · N lines`.
///
/// Built the same way `OcptResourcesSnapshot.build` is: a pure function of already-loaded lists,
/// with no database access of its own. `OcptBudgetQuoteService.loadPostes` is what loads [postes];
/// combining that read with the project's own settings into this one object is the mode's job.
class OcptBudgetSnapshot extends Equatable {
  /// Every poste of the project, in display order, each with its own quote lines.
  final List<OcptBudgetPoste> postes;

  /// The project's default VAT rate, in basis points, or null meaning "nobody has recorded a
  /// rate" — `OcptProjectInfoTable.defaultVatRateBasisPoints`.
  final int? defaultVatRateBasisPoints;

  /// The ISO 4217 code of the currency the project counts its costs in.
  final String currencyCode;

  /// `postes.length`.
  final int posteCount;

  /// The total number of quote lines across every poste.
  final int lineCount;

  /// Class constructor
  const OcptBudgetSnapshot({
    required this.postes,
    required this.defaultVatRateBasisPoints,
    required this.currencyCode,
    required this.posteCount,
    required this.lineCount,
  });

  /// Builds an [OcptBudgetSnapshot] from [postes], the project's [defaultVatRateBasisPoints] and
  /// [currencyCode], deriving the two counts from them.
  factory OcptBudgetSnapshot.build({
    required List<OcptBudgetPoste> postes,
    required int? defaultVatRateBasisPoints,
    required String currencyCode,
  }) => OcptBudgetSnapshot(
    postes: postes,
    defaultVatRateBasisPoints: defaultVatRateBasisPoints,
    currencyCode: currencyCode,
    posteCount: postes.length,
    lineCount: postes.fold(0, (sum, poste) => sum + poste.lines.length),
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptBudgetSnapshot(posteCount: $posteCount, lineCount: $lineCount, "
      "defaultVatRateBasisPoints: $defaultVatRateBasisPoints, currencyCode: $currencyCode)";

  /// Object properties
  @override
  List<Object?> get props => [
    postes,
    defaultVatRateBasisPoints,
    currencyCode,
    posteCount,
    lineCount,
  ];
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/constants/ocpt_budget_cnc_postes.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste_seed.dart';

/// The placeholder shown in place of a budget figure that cannot be read at all — this mode's own
/// instance of `ocptResourcesEmptyValue`: an empty cell reads as a rendering bug, an em dash reads
/// as "nothing here yet". Used for the excluding-tax sub-line a poste's lines carry no known rate
/// for, for the `Consumed` column of a poste with no quote at all (a ratio would be a division by
/// zero, not a figure), and for a cash-journal amount that cannot be read tax-inclusive — never
/// `0 €`/`0 %`, which would claim a figure the data does not support.
const ocptBudgetEmptyValue = "—";

/// The pattern [ocptBudgetQuantityLabel] and [ocptBudgetQuantityMilliOf] read and write a quantity
/// through: up to three fractional digits, grouped — the milli precision `quantityMilli` itself
/// carries, dropped past its own last significant digit by [NumberFormat]'s own trailing-zero rule.
final NumberFormat _ocptBudgetQuantityFormat = NumberFormat("#,##0.###");

/// Every kind of space a typed or pasted quantity may be grouped with — the ordinary one, and the
/// no-break ones a spreadsheet's own formatting carries into a paste, mirroring `ocptCostCentsOf`'s
/// own `_spaces`.
final RegExp _ocptBudgetQuantitySpaces = RegExp(r"\s");

/// The decimal separator [ocptBudgetQuantityMilliOf] accepts alongside the comma, mirroring
/// `ocptCostCentsOf`'s own pair.
const String _ocptBudgetQuantityDecimalPoint = ".";

/// The comma a French keyboard produces for the same separator.
const String _ocptBudgetQuantityDecimalComma = ",";

/// How many thousandths make up one whole unit — what turns a typed `1.5` into the `1500`
/// `budget_lines.quantityMilli` stores.
const int _ocptBudgetQuantityMilliPerUnit = 1000;

/// [tr]'s localized label for one of `ocptBudgetCncPostes`' own ARB key names — the exhaustive
/// switch `ocptCrewPositionLabel` already is for a crew position, here pairing every constant's own
/// `labelKey`/`simpleLabelKey` with the `Tr` getter of the same name.
///
/// **A poste added to `ocptBudgetCncPostes` (`lib/constants/`) must be added here too**: the
/// catalogue itself stays free of `Tr`, so this switch is the single place that resolves one of its
/// key names into a word. A key this switch does not recognise (a constant renamed here without its
/// own case following, which should not happen but must not go blank either) falls back to the key
/// itself, so the seed still reads as *something* rather than nothing at all.
String _ocptBudgetCncPosteKeyLabel(Tr tr, String key) => switch (key) {
  "budgetCncPosteArtisticRights" => tr.budgetCncPosteArtisticRights,
  "budgetCncPosteSimpleArtisticRights" => tr.budgetCncPosteSimpleArtisticRights,
  "budgetCncPostePersonnel" => tr.budgetCncPostePersonnel,
  "budgetCncPosteSimplePersonnel" => tr.budgetCncPosteSimplePersonnel,
  "budgetCncPosteCast" => tr.budgetCncPosteCast,
  "budgetCncPosteSimpleCast" => tr.budgetCncPosteSimpleCast,
  "budgetCncPosteSocialCharges" => tr.budgetCncPosteSocialCharges,
  "budgetCncPosteSimpleSocialCharges" => tr.budgetCncPosteSimpleSocialCharges,
  "budgetCncPosteSetsAndCostumes" => tr.budgetCncPosteSetsAndCostumes,
  "budgetCncPosteSimpleSetsAndCostumes" => tr.budgetCncPosteSimpleSetsAndCostumes,
  "budgetCncPosteTransportPerDiemsLogistics" => tr.budgetCncPosteTransportPerDiemsLogistics,
  "budgetCncPosteSimpleTransportPerDiemsLogistics" =>
    tr.budgetCncPosteSimpleTransportPerDiemsLogistics,
  "budgetCncPosteTechnicalEquipment" => tr.budgetCncPosteTechnicalEquipment,
  "budgetCncPosteSimpleTechnicalEquipment" => tr.budgetCncPosteSimpleTechnicalEquipment,
  "budgetCncPosteLaboratoryAndPostProduction" => tr.budgetCncPosteLaboratoryAndPostProduction,
  "budgetCncPosteSimpleLaboratoryAndPostProduction" =>
    tr.budgetCncPosteSimpleLaboratoryAndPostProduction,
  "budgetCncPosteInsuranceAndMiscellaneous" => tr.budgetCncPosteInsuranceAndMiscellaneous,
  "budgetCncPosteSimpleInsuranceAndMiscellaneous" =>
    tr.budgetCncPosteSimpleInsuranceAndMiscellaneous,
  "budgetCncPosteOverheads" => tr.budgetCncPosteOverheads,
  "budgetCncPosteSimpleOverheads" => tr.budgetCncPosteSimpleOverheads,
  _ => key,
};

/// [ocptBudgetCncPostes] resolved into the seed `OcptBudgetQuoteService.loadPostes` asks for,
/// through [_ocptBudgetCncPosteKeyLabel] — the one place a constant's `labelKey`/`simpleLabelKey`
/// becomes a word, since neither `lib/constants/` nor the manager layer beneath it may see a `Tr`.
///
/// Read **once**, by `OcptBudgetMode` when it creates `OcptBudgetBloc`, and handed in as a
/// constructor argument rather than watched: see that bloc's own doc comment for why.
List<OcptBudgetPosteSeed> ocptBudgetCncPosteSeeds(Tr tr) => [
  for (final poste in ocptBudgetCncPostes)
    OcptBudgetPosteSeed(
      id: poste.id,
      code: poste.code,
      label: _ocptBudgetCncPosteKeyLabel(tr, poste.labelKey),
      simpleLabel: _ocptBudgetCncPosteKeyLabel(tr, poste.simpleLabelKey),
    ),
];

/// [cents] formatted as a **displayed** amount in [currencyCode]: grouped, carrying the currency
/// symbol — `NumberFormat.simpleCurrency`, the precedent `OcptElementSheetSourcingCard` sets for
/// reaching into `intl` rather than an ARB key.
///
/// The app's one formatting of an amount somebody is only ever **reading** — the `Quote`/`Paid`/
/// `Committed`/`Remaining`/`Variance`/`Consumed` columns, the dashboard's KPIs. This is not
/// `ocptCostTextOf`, which writes the bare, ungrouped text of an editable *field* and carries
/// neither symbol nor grouping: a value read back into a text field must be exactly what the field
/// accepts again, which a grouped, symbol-carrying string is not.
String ocptBudgetAmountLabel(int cents, String currencyCode) =>
    NumberFormat.simpleCurrency(name: currencyCode).format(cents / 100);

/// [quantityMilli] written back as the figure somebody typed: `1500` is `1.5`, `1484000` is
/// `1,484` (grouped, and the locale's own separators) — `budget_lines.quantityMilli`'s own display
/// reading, the milli precision dropped past its last significant digit.
String ocptBudgetQuantityLabel(int quantityMilli) =>
    _ocptBudgetQuantityFormat.format(quantityMilli / _ocptBudgetQuantityMilliPerUnit);

/// Reads [text], typed into a quantity field, as a figure in thousandths — the app's one place that
/// turns what somebody typed into `budget_lines.quantityMilli`, so the quote-line card can never
/// disagree with [ocptBudgetQuantityLabel] about what `1,5` means.
///
/// Mirrors `ocptCostCentsOf`'s own forgiving-about-shape, strict-about-value reading: both decimal
/// separators are accepted, spaces (including a paste's own no-break ones) are dropped, and
/// anything left that is not a non-negative number reads as **no quantity at all** — null, never
/// zero, which the field's own flush handler skips the write for rather than overwriting
/// `quantityMilli` (never nullable) with a figure nobody actually typed.
int? ocptBudgetQuantityMilliOf(String text) {
  final normalized = text
      .replaceAll(_ocptBudgetQuantitySpaces, "")
      .replaceAll(_ocptBudgetQuantityDecimalComma, _ocptBudgetQuantityDecimalPoint);
  if (normalized.isEmpty) {
    return null;
  }

  final quantity = double.tryParse(normalized);
  if (quantity == null || quantity < 0) {
    return null;
  }

  return (quantity * _ocptBudgetQuantityMilliPerUnit).round();
}

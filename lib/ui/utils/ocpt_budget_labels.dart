// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart' show BuildContext, Color, ColorScheme;
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/constants/ocpt_budget_cnc_postes.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_cash_journal_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financial_report_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_financing_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste_seed.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_quote_labels.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_allowance_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_provision_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_family.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_percent_permille.dart';

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

/// [poste]'s own displayed name under the header's simplified/detailed switch —
/// `OcptBudgetCostTracking`'s own reading of [OcptBudgetPoste.simpleLabel]/[OcptBudgetPoste.label],
/// lifted here so a second view (the cash journal's own poste column and filter caption) reads a
/// poste's name exactly the same way rather than re-deriving the fallback itself: [isSimplified]
/// true answers [OcptBudgetPoste.simpleLabel], falling back to [OcptBudgetPoste.label] when that is
/// null, and false answers [OcptBudgetPoste.label] outright.
String ocptBudgetPosteDisplayLabel(OcptBudgetPoste poste, {required bool isSimplified}) =>
    isSimplified ? (poste.simpleLabel ?? poste.label) : poste.label;

/// [status]'s own localized word — shared between the committed-spending view's own status badge
/// and the commitment dialog's own status picker, lifted here so both always agree on the wording
/// rather than each resolving it independently.
String ocptBudgetCommitmentStatusLabel(Tr tr, OcptBudgetCommitmentStatus status) => switch (status) {
  OcptBudgetCommitmentStatus.quoteAccepted => tr.budgetCommittedStatusQuoteAcceptedLabel,
  OcptBudgetCommitmentStatus.contractSigned => tr.budgetCommittedStatusContractSignedLabel,
  OcptBudgetCommitmentStatus.invoiceReceived => tr.budgetCommittedStatusInvoiceReceivedLabel,
  OcptBudgetCommitmentStatus.declared => tr.budgetCommittedStatusDeclaredLabel,
};

/// [status]'s own accent colour, read off [colorScheme] alone — never a hard-coded hex — from the
/// lightest step (a mere quote accepted) to the one nearest to being paid (declared).
///
/// Reads [OcptBudgetCommitmentStatus.index] as the weight to paint: that enum's own doc comment
/// already orders its four values exactly as the mockup's own four steps do, each one further along
/// the road to being money out of the door than the last, so this mirrors that declared order
/// rather than re-deriving which of two statuses reads heavier.
Color ocptBudgetCommitmentStatusAccentColor(
  ColorScheme colorScheme,
  OcptBudgetCommitmentStatus status,
) => switch (status) {
  OcptBudgetCommitmentStatus.quoteAccepted => colorScheme.onSurfaceVariant,
  OcptBudgetCommitmentStatus.contractSigned => colorScheme.secondary,
  OcptBudgetCommitmentStatus.invoiceReceived => colorScheme.tertiary,
  OcptBudgetCommitmentStatus.declared => colorScheme.primary,
};

/// [kind]'s own localized word — the financing view's own group card headers, and the resource
/// dialog's own group-kind picker, always reading the same three words.
String ocptBudgetResourceGroupKindLabel(Tr tr, OcptBudgetResourceGroupKind kind) => switch (kind) {
  OcptBudgetResourceGroupKind.subsidy => tr.budgetFinancingGroupSubsidyLabel,
  OcptBudgetResourceGroupKind.cash => tr.budgetFinancingGroupCashLabel,
  OcptBudgetResourceGroupKind.inKind => tr.budgetFinancingGroupInKindLabel,
};

/// [family]'s own localized word — the resources tree's own three family rows, in the order they
/// draw: subsidies, contributions, takings.
String ocptBudgetResourceFamilyLabel(Tr tr, OcptBudgetResourceFamily family) => switch (family) {
  OcptBudgetResourceFamily.subsidies => tr.budgetFinancingFamilySubsidiesLabel,
  OcptBudgetResourceFamily.contributions => tr.budgetFinancingFamilyContributionsLabel,
  OcptBudgetResourceFamily.takings => tr.budgetFinancingFamilyTakingsLabel,
};

/// [status]'s own localized word **for a [kind] resource** — shared between the financing view's
/// own status pill and the resource dialog's own status picker, lifted here for the very reason
/// [ocptBudgetCommitmentStatusLabel] already is: both always agree on the wording rather than each
/// resolving it independently.
///
/// **[kind] is not decoration: the word is the group's, only the step is the enum's** —
/// `OcptBudgetResourceStatus`'s own doc comment argues why. A subsidy is applied for, notified,
/// secured; a cash contribution requested, agreed, contracted; a contribution in kind promised,
/// valued, signed. Nine words, three steps, one stored column.
String ocptBudgetResourceStatusLabel(
  Tr tr,
  OcptBudgetResourceGroupKind kind,
  OcptBudgetResourceStatus status,
) => switch ((kind, status)) {
  (OcptBudgetResourceGroupKind.subsidy, OcptBudgetResourceStatus.pending) =>
    tr.budgetFinancingStatusSubsidyPendingLabel,
  (OcptBudgetResourceGroupKind.subsidy, OcptBudgetResourceStatus.agreed) =>
    tr.budgetFinancingStatusSubsidyAgreedLabel,
  (OcptBudgetResourceGroupKind.subsidy, OcptBudgetResourceStatus.confirmed) =>
    tr.budgetFinancingStatusSubsidyConfirmedLabel,
  (OcptBudgetResourceGroupKind.cash, OcptBudgetResourceStatus.pending) =>
    tr.budgetFinancingStatusCashPendingLabel,
  (OcptBudgetResourceGroupKind.cash, OcptBudgetResourceStatus.agreed) =>
    tr.budgetFinancingStatusCashAgreedLabel,
  (OcptBudgetResourceGroupKind.cash, OcptBudgetResourceStatus.confirmed) =>
    tr.budgetFinancingStatusCashConfirmedLabel,
  (OcptBudgetResourceGroupKind.inKind, OcptBudgetResourceStatus.pending) =>
    tr.budgetFinancingStatusInKindPendingLabel,
  (OcptBudgetResourceGroupKind.inKind, OcptBudgetResourceStatus.agreed) =>
    tr.budgetFinancingStatusInKindAgreedLabel,
  (OcptBudgetResourceGroupKind.inKind, OcptBudgetResourceStatus.confirmed) =>
    tr.budgetFinancingStatusInKindConfirmedLabel,
};

/// [status]'s own accent colour, read off [colorScheme] alone — never a hard-coded hex — mirroring
/// [ocptBudgetCommitmentStatusAccentColor]'s own reading: [OcptBudgetResourceStatus.index] already
/// orders its three steps from the lightest (merely in play) to the one nearest to actually
/// financing the production (held on paper), so this mirrors that declared order rather than
/// re-deriving which of two statuses reads heavier.
///
/// **Takes no `OcptBudgetResourceGroupKind`, unlike [ocptBudgetResourceStatusLabel]**: what a step
/// is *called* belongs to the group, but how far along it is does not — a contribution in kind that
/// is signed and a subsidy that is secured stand at the same place, and the eye should read them
/// the same.
Color ocptBudgetResourceStatusAccentColor(ColorScheme colorScheme, OcptBudgetResourceStatus status) =>
    switch (status) {
      OcptBudgetResourceStatus.pending => colorScheme.onSurfaceVariant,
      OcptBudgetResourceStatus.agreed => colorScheme.tertiary,
      OcptBudgetResourceStatus.confirmed => colorScheme.primary,
    };

/// [kind]'s own localized word — the régie view's own defrayal table and its dialog, always
/// reading the same four words, mirroring [ocptBudgetResourceStatusLabel]'s own reason for living
/// here.
String ocptBudgetAllowanceKindLabel(Tr tr, OcptBudgetAllowanceKind kind) => switch (kind) {
  OcptBudgetAllowanceKind.travel => tr.budgetAllowanceKindTravelLabel,
  OcptBudgetAllowanceKind.accommodation => tr.budgetAllowanceKindAccommodationLabel,
  OcptBudgetAllowanceKind.meal => tr.budgetAllowanceKindMealLabel,
  OcptBudgetAllowanceKind.other => tr.budgetAllowanceKindOtherLabel,
};

/// [kind]'s own localized word — the wording the provisioning writes onto the quote line it mints
/// for that nature, and the one it compares against to tell a hand edit from a stale figure.
///
/// **A defrayed meal and a catering meal read differently on purpose**: the first is what one
/// person is paid back for a meal the production did not provide, the second what the production
/// fed the unit on a shooting day, and a quote holding both must not read the same word twice.
String ocptBudgetProvisionKindLabel(Tr tr, OcptBudgetProvisionKind kind) => switch (kind) {
  OcptBudgetProvisionKind.meal => tr.budgetProvisionLineMealsLabel,
  OcptBudgetProvisionKind.snack => tr.budgetProvisionLineSnacksLabel,
  OcptBudgetProvisionKind.travelAllowance => tr.budgetProvisionLineTravelLabel,
  OcptBudgetProvisionKind.accommodationAllowance => tr.budgetProvisionLineAccommodationLabel,
  OcptBudgetProvisionKind.mealAllowance => tr.budgetProvisionLineMealAllowanceLabel,
  OcptBudgetProvisionKind.otherAllowance => tr.budgetProvisionLineOtherLabel,
};

/// Every nature's own wording, as `ocptBudgetProvisionPlanOf` wants it handed in: a mode resolves
/// every word and passes a labels map, no util of this app ever seeing a `Tr`.
Map<OcptBudgetProvisionKind, String> ocptBudgetProvisionLabelsOf(Tr tr) => {
  for (final kind in OcptBudgetProvisionKind.values) kind: ocptBudgetProvisionKindLabel(tr, kind),
};

/// [status]'s own localized word — the sharing view's own `Takings received` card and the revenue
/// dialog's own status picker, always reading the same three words, mirroring
/// [ocptBudgetResourceStatusLabel].
String ocptBudgetRevenueStatusLabel(Tr tr, OcptBudgetRevenueStatus status) => switch (status) {
  OcptBudgetRevenueStatus.expected => tr.budgetSharingRevenueStatusExpectedLabel,
  OcptBudgetRevenueStatus.confirmed => tr.budgetSharingRevenueStatusConfirmedLabel,
  OcptBudgetRevenueStatus.invoiced => tr.budgetSharingRevenueStatusInvoicedLabel,
};

/// [status]'s own accent colour, read off [colorScheme] alone — mirrors
/// [ocptBudgetResourceStatusAccentColor]'s own reading, [OcptBudgetRevenueStatus.index] ordering
/// its three values from the lightest step (merely announced) to the one nearest to being paid
/// (invoiced).
Color ocptBudgetRevenueStatusAccentColor(ColorScheme colorScheme, OcptBudgetRevenueStatus status) =>
    switch (status) {
      OcptBudgetRevenueStatus.expected => colorScheme.onSurfaceVariant,
      OcptBudgetRevenueStatus.confirmed => colorScheme.secondary,
      OcptBudgetRevenueStatus.invoiced => colorScheme.primary,
    };

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

/// [permille] formatted as a **displayed** percentage: `400` reads `40%`, `455` reads `45.5%` —
/// the sharing view's own `Share` column, over [ocptPermillePercentTextOf]'s own bare figure, a
/// `%` sign appended the very same way [ocptBudgetAmountLabel] appends a currency symbol
/// `ocptCostTextOf` never carries.
String ocptBudgetSharePercentLabel(int permille) => "${ocptPermillePercentTextOf(permille)}%";

/// A total's own coverage read-out template, still fully localizable and yet handed to the
/// manager layer as a plain string it can `.replaceAll` the real figures into
/// (`lib/managers/export/services/ocpt_budget_pdf_shared.dart`'s own `ocptBudgetExportCoveredAmountText`,
/// which no service under `lib/managers/` may ask `Tr` to interpolate itself).
///
/// Calling [Tr.budgetExportCoverageReadOutTemplate] with the placeholder names themselves as its
/// own string arguments resolves the current locale's own word order around them (a French
/// translation may read the figures in a different order than the English one) while leaving the
/// literal `{amount}`/`{coveredCount}`/`{totalCount}` tokens in the returned string exactly where
/// that word order puts them — which is what the manager's own second pass replaces with the real
/// figures at export time. Shared by [ocptBudgetQuoteLabelsOf], [ocptBudgetFinancingPlanLabelsOf]
/// and [ocptBudgetFinancialReportLabelsOf], all three documents reading the very same template.
String _ocptBudgetExportCoverageReadOutTemplate(Tr tr) =>
    tr.budgetExportCoverageReadOutTemplate("{amount}", "{coveredCount}", "{totalCount}");

/// The needs/resources balance's own shortfall verdict template, still fully localizable — mirrors
/// [_ocptBudgetExportCoverageReadOutTemplate]'s own reasoning and reused by both
/// [ocptBudgetFinancingPlanLabelsOf] and [ocptBudgetFinancialReportLabelsOf].
String _ocptBudgetExportBalanceShortfallMessageTemplate(Tr tr) =>
    tr.budgetExportBalanceShortfallMessageTemplate("{amount}");

/// Every localized string the exported quote carries, resolved once here so `OcptBudgetMode` hands
/// the manager a labels object rather than a `Tr` it must never see (`AGENTS.md`).
OcptBudgetQuoteLabels ocptBudgetQuoteLabelsOf(BuildContext context) {
  final tr = Tr.of(context);

  return OcptBudgetQuoteLabels(
    fileNameSuffix: tr.budgetExportQuoteFileNameSuffix,
    documentTitle: tr.budgetExportQuoteDocumentTitle,
    versionLabel: tr.budgetExportVersionLabel,
    lineLabelHeader: tr.budgetExportQuoteLineLabelHeader,
    quantityHeader: tr.budgetExportQuoteQuantityHeader,
    unitPriceHeader: tr.budgetExportQuoteUnitPriceHeader,
    lineTotalHeader: tr.budgetExportQuoteLineTotalHeader,
    posteSubtotalLabel: tr.budgetExportQuotePosteSubtotalLabel,
    projectTotalLabel: tr.budgetExportQuoteProjectTotalLabel,
    includingTaxCaption: tr.budgetExportQuoteIncludingTaxCaption,
    excludingTaxCaption: tr.budgetExportQuoteExcludingTaxCaption,
    noLinesLabel: tr.budgetExportQuoteNoLinesLabel,
    emptyDocumentNote: tr.budgetExportQuoteEmptyDocumentNote,
    coverageReadOutTemplate: _ocptBudgetExportCoverageReadOutTemplate(tr),
  );
}

/// Every localized string the exported financing plan carries — mirrors [ocptBudgetQuoteLabelsOf].
///
/// `groupTitles`/`statusLabels` reuse [ocptBudgetResourceGroupKindLabel]/
/// [ocptBudgetResourceStatusLabel] rather than resolving their own words, so the exported document
/// never disagrees with the screen about what a group or a status is called.
/// `balanceNeedsLabel`/`balanceResourcesLabel`/`balanceNoQuoteMessage`/`balanceBalancedMessage`
/// reuse the dashboard's own balance bar strings for the same reason — see
/// `OcptBudgetFinancingPlanLabels`'s own doc comment.
OcptBudgetFinancingPlanLabels ocptBudgetFinancingPlanLabelsOf(BuildContext context) {
  final tr = Tr.of(context);

  return OcptBudgetFinancingPlanLabels(
    fileNameSuffix: tr.budgetExportFinancingPlanFileNameSuffix,
    documentTitle: tr.budgetExportFinancingPlanDocumentTitle,
    versionLabel: tr.budgetExportVersionLabel,
    groupTitles: {
      for (final kind in OcptBudgetResourceGroupKind.values)
        kind: ocptBudgetResourceGroupKindLabel(tr, kind),
    },
    statusLabels: {
      for (final kind in OcptBudgetResourceGroupKind.values)
        kind: {
          for (final status in OcptBudgetResourceStatus.values)
            status: ocptBudgetResourceStatusLabel(tr, kind, status),
        },
    },
    labelHeader: tr.budgetExportFinancingPlanLabelHeader,
    statusHeader: tr.budgetExportFinancingPlanStatusHeader,
    amountHeader: tr.budgetExportFinancingPlanAmountHeader,
    receivedHeader: tr.budgetExportFinancingPlanReceivedHeader,
    outstandingHeader: tr.budgetExportFinancingPlanOutstandingHeader,
    groupSubtotalLabel: tr.budgetExportFinancingPlanGroupSubtotalLabel,
    projectTotalLabel: tr.budgetExportFinancingPlanProjectTotalLabel,
    emptyDocumentNote: tr.budgetExportFinancingPlanEmptyDocumentNote,
    balanceNeedsLabel: tr.budgetDashboardBalanceNeedsLabel,
    balanceResourcesLabel: tr.budgetDashboardBalanceResourcesLabel,
    balanceNoQuoteMessage: tr.budgetDashboardBalanceNoQuoteMessage,
    balanceBalancedMessage: tr.budgetDashboardBalanceBalancedMessage,
    balanceShortfallMessageTemplate: _ocptBudgetExportBalanceShortfallMessageTemplate(tr),
    coverageReadOutTemplate: _ocptBudgetExportCoverageReadOutTemplate(tr),
  );
}

/// Every localized string the exported cash journal workbook carries — mirrors
/// [ocptBudgetQuoteLabelsOf].
OcptBudgetCashJournalXlsxLabels ocptBudgetCashJournalXlsxLabelsOf(BuildContext context) {
  final tr = Tr.of(context);

  return OcptBudgetCashJournalXlsxLabels(
    sheetName: tr.budgetExportCashJournalSheetName,
    dateHeader: tr.budgetExportCashJournalDateHeader,
    voucherHeader: tr.budgetExportCashJournalVoucherHeader,
    labelHeader: tr.budgetExportCashJournalLabelHeader,
    posteHeader: tr.budgetExportCashJournalPosteHeader,
    settlesHeader: tr.budgetExportCashJournalSettlesHeader,
    debitHeader: tr.budgetExportCashJournalDebitHeader,
    creditHeader: tr.budgetExportCashJournalCreditHeader,
    balanceHeader: tr.budgetExportCashJournalBalanceHeader,
    totalsRowLabel: tr.budgetExportCashJournalTotalsRowLabel,
  );
}

/// Every localized string the exported financial report carries — mirrors
/// [ocptBudgetFinancingPlanLabelsOf], reusing the very same dashboard balance strings for the very
/// same reason, and reusing `tr.budgetCostTrackingOffQuoteLabel` — the cost-tracking table's own
/// off-quote row label — so the report never invents a second word for the very row the screen
/// already draws.
OcptBudgetFinancialReportLabels ocptBudgetFinancialReportLabelsOf(BuildContext context) {
  final tr = Tr.of(context);

  return OcptBudgetFinancialReportLabels(
    fileNameSuffix: tr.budgetExportFinancialReportFileNameSuffix,
    documentTitle: tr.budgetExportFinancialReportDocumentTitle,
    versionLabel: tr.budgetExportVersionLabel,
    posteHeader: tr.budgetExportFinancialReportPosteHeader,
    quotedHeader: tr.budgetExportFinancialReportQuotedHeader,
    paidHeader: tr.budgetExportFinancialReportPaidHeader,
    committedHeader: tr.budgetExportFinancialReportCommittedHeader,
    remainingHeader: tr.budgetExportFinancialReportRemainingHeader,
    varianceHeader: tr.budgetExportFinancialReportVarianceHeader,
    projectTotalsLabel: tr.budgetExportFinancialReportProjectTotalsLabel,
    offQuoteLabel: tr.budgetCostTrackingOffQuoteLabel,
    financingPlanTotalLabel: tr.budgetExportFinancialReportFinancingPlanTotalLabel,
    emptyDocumentNote: tr.budgetExportFinancialReportEmptyDocumentNote,
    coverageReadOutTemplate: _ocptBudgetExportCoverageReadOutTemplate(tr),
    balanceNeedsLabel: tr.budgetDashboardBalanceNeedsLabel,
    balanceResourcesLabel: tr.budgetDashboardBalanceResourcesLabel,
    balanceNoQuoteMessage: tr.budgetDashboardBalanceNoQuoteMessage,
    balanceBalancedMessage: tr.budgetDashboardBalanceBalancedMessage,
    balanceShortfallMessageTemplate: _ocptBudgetExportBalanceShortfallMessageTemplate(tr),
  );
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_budget_covered_total.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_tax_basis.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_detail.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a band wide
/// enough that every field of the detail panel is drawn with no overflow.
Widget wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 420, height: 1400, child: child)),
);

/// Grows the test surface tall enough that every one of the detail panel's own actions sits inside
/// the hit-testable area — the detail panel's own body scrolls, but the surface itself still has to
/// be at least as tall as what a test means to tap.
void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// A `fieldValueOf` reading every field straight off its own stored value — no pending edit ever
/// overrides it, which is all these tests need.
String storedFieldValueOf(String targetId, OcptBudgetField field, String storedValue) =>
    storedValue;

/// A quote line priced at 10.00 €, tax-inclusive, pricing no breakdown element.
const testLine = OcptBudgetLine(
  id: "line-1",
  accountId: "poste-1",
  label: "Crown",
  quantityMilli: 1000,
  unit: "u",
  unitPrice: OcptMoney(amountCents: 1000, isTaxInclusive: true, vatRateBasisPoints: null),
  elementId: null,
  inKindResourceId: null,
  provisionKey: null,
  provisionDigest: null,
  notes: "",
  sortKey: "a0",
);

/// The account every test below reads, holding [testLine] alone.
const testAccount = OcptBudgetAccount(
  id: "poste-1",
  code: "5",
  label: "Sets and costumes",
  simpleLabel: null,
  estimateToCompleteCents: null,
  sortKey: "a0",
  lines: [testLine],
);

/// Builds a commitment against [testAccount], everything but what a test actually varies neutral —
/// settlement is read off whichever entries the test hands in alongside it, never a field of the
/// commitment itself any more.
OcptBudgetCommitment buildCommitment({
  String id = "commitment-1",
  String? lineId,
  int amountCents = 1000,
  DateTime? dueDate,
}) => OcptBudgetCommitment(
  id: id,
  dueDate: dueDate,
  label: "Glass workshop",
  accountId: "poste-1",
  amount: OcptMoney(amountCents: amountCents, isTaxInclusive: true, vatRateBasisPoints: null),
  status: OcptBudgetCommitmentStatus.invoiceReceived,
  lineId: lineId,
  sortKey: "a0",
);

/// Builds a journal entry, everything but what a test actually varies neutral.
OcptBudgetEntry buildEntry({
  String id = "entry-1",
  String? accountId = "poste-1",
  int debitCents = 0,
  int creditCents = 0,
  String? resourceId,
  String? revenueId,
  String? commitmentId,
}) => OcptBudgetEntry(
  id: id,
  date: DateTime(2026, 8, 18),
  label: "Invoice",
  accountId: accountId,
  debitCents: debitCents,
  creditCents: creditCents,
  isTaxInclusive: true,
  vatRateBasisPoints: null,
  voucherNumber: "J-001",
  sortKey: "a0",
  resourceId: resourceId,
  revenueId: revenueId,
  shareId: null,
  commitmentId: commitmentId,
  personId: null,
);

/// Builds a financing resource, everything but what a test actually varies neutral.
OcptBudgetResource buildResource({
  String id = "resource-1",
  OcptBudgetResourceGroupKind groupKind = OcptBudgetResourceGroupKind.cash,
  int amountCents = 200000,
  OcptBudgetResourceStatus status = OcptBudgetResourceStatus.agreed,
}) => OcptBudgetResource(
  id: id,
  groupKind: groupKind,
  personId: null,
  label: "Region grant",
  amountCents: amountCents,
  status: status,
  isReimbursable: false,
  notes: "",
  sortKey: "a0",
);

/// The detail panel's own no-op parameters, spread across every test below so each only overrides
/// what it actually cares about.
OcptBudgetDetail testDetail({
  OcptBudgetSelection? selection,
  List<OcptBudgetAccount> accounts = const [testAccount],
  List<OcptBudgetCommitment> commitments = const [],
  List<OcptBudgetEntry> entries = const [],
  List<OcptBudgetResource> resources = const [],
  List<OcptBudgetRevenue> revenues = const [],
  bool isReadOnly = false,
  Map<String, OcptBudgetCoveredTotal> receivedByResourceId = const {},
  Map<String, OcptBudgetCoveredTotal> receivedByRevenueId = const {},
  ValueChanged<String>? onLineCommitRequested,
  ValueChanged<String>? onLinePayDirectlyRequested,
  ValueChanged<String>? onLineSettleRequested,
  ValueChanged<String>? onLineShowCommitmentRequested,
  ValueChanged<String>? onLineUncommitRequested,
  ValueChanged<String>? onLineDeletionRequested,
  ValueChanged<OcptBudgetCommitment>? onCommitmentSettleRequested,
  ValueChanged<OcptBudgetCommitment>? onCommitmentEditRequested,
  ValueChanged<String>? onCommitmentDeletionRequested,
  VoidCallback? onCommitmentPromoteToQuoteRequested,
  ValueChanged<OcptBudgetEntry>? onEntryEditRequested,
  ValueChanged<String>? onEntryDeletionRequested,
  VoidCallback? onEntryPromoteToQuoteRequested,
  VoidCallback? onEntryMoveOffQuoteRequested,
  ValueChanged<OcptBudgetResource>? onResourceReceiptRequested,
  ValueChanged<OcptBudgetResource>? onResourceEditRequested,
  ValueChanged<String>? onResourceDeletionRequested,
  ValueChanged<OcptBudgetRevenue>? onRevenueReceiptRequested,
  ValueChanged<OcptBudgetRevenue>? onRevenueEditRequested,
  ValueChanged<String>? onRevenueDeletionRequested,
}) => OcptBudgetDetail(
  selection: selection,
  accounts: accounts,
  commitments: commitments,
  entries: entries,
  resources: resources,
  revenues: revenues,
  taxBasis: OcptBudgetTaxBasis.includingTax,
  defaultVatRateBasisPoints: null,
  currencyCode: "EUR",
  isSimplified: false,
  isReadOnly: isReadOnly,
  elementNameByElementId: const {},
  receiptsByEntryId: const {},
  receivedByResourceId: receivedByResourceId,
  receivedByRevenueId: receivedByRevenueId,
  fieldValueOf: storedFieldValueOf,
  onFieldChanged: (_, __, ___) {},
  onAccountEstimateToCompleteDerivedRequested: (_) {},
  onLineTaxInclusiveChanged: (_, {required isTaxInclusive}) {},
  onLineVatRateInheritedRequested: (_) {},
  onLineCommitRequested: onLineCommitRequested,
  onLinePayDirectlyRequested: onLinePayDirectlyRequested,
  onLineSettleRequested: onLineSettleRequested,
  onLineShowCommitmentRequested: onLineShowCommitmentRequested,
  onLineUncommitRequested: onLineUncommitRequested,
  onLineDeletionRequested: onLineDeletionRequested,
  onCommitmentSettleRequested: onCommitmentSettleRequested,
  onCommitmentEditRequested: onCommitmentEditRequested,
  onCommitmentDeletionRequested: onCommitmentDeletionRequested,
  onCommitmentPromoteToQuoteRequested: onCommitmentPromoteToQuoteRequested,
  onEntryEditRequested: onEntryEditRequested,
  onEntryDeletionRequested: onEntryDeletionRequested,
  onEntryPromoteToQuoteRequested: onEntryPromoteToQuoteRequested,
  onEntryMoveOffQuoteRequested: onEntryMoveOffQuoteRequested,
  onResourceReceiptRequested: onResourceReceiptRequested,
  onResourceEditRequested: onResourceEditRequested,
  onResourceDeletionRequested: onResourceDeletionRequested,
  onRevenueReceiptRequested: onRevenueReceiptRequested,
  onRevenueEditRequested: onRevenueEditRequested,
  onRevenueDeletionRequested: onRevenueDeletionRequested,
);

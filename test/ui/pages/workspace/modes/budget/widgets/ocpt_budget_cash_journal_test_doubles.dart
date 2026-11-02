// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_account.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a wide, tall
/// enough band that the whole table is drawn with no scroll needed to find a cell.
Widget wrap(Widget child, {double width = 1400}) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(
    body: SizedBox(width: width, height: 700, child: child),
  ),
);

/// A minimal account, everything but [id]/[label] neutral.
OcptBudgetAccount testAccount({required String id, required String label}) => OcptBudgetAccount(
  id: id,
  code: "1",
  label: label,
  simpleLabel: null,
  estimateToCompleteCents: null,
  sortKey: "a0",
  lines: const [],
);

/// A minimal journal entry, everything but what each test actually varies neutral.
OcptBudgetEntry testEntry({
  required String id,
  required DateTime date,
  String label = "Camera rental",
  String? accountId,
  int debitCents = 0,
  int creditCents = 0,
  bool isTaxInclusive = true,
  int? vatRateBasisPoints,
  String voucherNumber = "J-001",
  String sortKey = "a0",
}) => OcptBudgetEntry(
  id: id,
  date: date,
  label: label,
  accountId: accountId,
  debitCents: debitCents,
  creditCents: creditCents,
  isTaxInclusive: isTaxInclusive,
  vatRateBasisPoints: vatRateBasisPoints,
  voucherNumber: voucherNumber,
  sortKey: sortKey,
  resourceId: null,
  revenueId: null,
  shareId: null,
  commitmentId: null,
  personId: null,
);

/// A minimal commitment, everything but what each test actually varies neutral.
OcptBudgetCommitment testCommitment({
  required String id,
  DateTime? dueDate,
  String label = "Camera rental — balance",
  String accountId = "poste-1",
  int amountCents = 1000,
  bool isTaxInclusive = true,
  int? vatRateBasisPoints,
  OcptBudgetCommitmentStatus status = OcptBudgetCommitmentStatus.quoteAccepted,
  String? lineId,
  String sortKey = "a0",
}) => OcptBudgetCommitment(
  id: id,
  dueDate: dueDate,
  label: label,
  accountId: accountId,
  amount: OcptMoney(
    amountCents: amountCents,
    isTaxInclusive: isTaxInclusive,
    vatRateBasisPoints: vatRateBasisPoints,
  ),
  status: status,
  lineId: lineId,
  sortKey: sortKey,
);

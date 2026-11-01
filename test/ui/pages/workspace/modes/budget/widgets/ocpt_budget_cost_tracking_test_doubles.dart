// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a
/// [width]×[height] band — wide enough by default that every column of the table is drawn with
/// no horizontal scroll at all; a test of the scrolling pane itself, or of the compact card list,
/// passes a narrower [width]. [testTestWidgets] widens the real test surface past
/// `flutter_test`'s own default 800×600 window before every test in this file, so this
/// [SizedBox] is never silently clamped back down to it the way it would be under a plain
/// [testWidgets].
Widget wrap(Widget child, {double width = 1400, double height = 600}) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(
    body: SizedBox(width: width, height: height, child: child),
  ),
);

/// A [testWidgets] that first widens the real test surface to a size comfortably past every [wrap]
/// call in this file's own widest use (1400×600) — `flutter_test`'s own default 800×600 window
/// would otherwise silently clamp a wider [SizedBox] back down to it, moving every column past 800
/// px off the real, tappable surface even though the widget tree still lays it out — exactly the
/// gap that made the desktop-vs-compact branch this file now tests (`ocptIsCompactWidth` reading
/// the real constraint) impossible to tell apart from a genuinely compact window. Restored through
/// [addTearDown] so no test leaks its own surface size into the next one.
void testTestWidgets(String description, WidgetTesterCallback callback) {
  testWidgets(description, (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await callback(tester);
  });
}

/// A quote line priced at [amountCents] (10.00 € by default), tax-inclusive, whose rate is known
/// only when `vatRateBasisPoints` is given.
OcptBudgetLine testLine({
  required String id,
  required String posteId,
  int? vatRateBasisPoints,
  int amountCents = 1000,
  String label = "",
  String? inKindResourceId,
}) => OcptBudgetLine(
  id: id,
  posteId: posteId,
  label: label.isEmpty ? "Line $id" : label,
  quantityMilli: 1000,
  unit: "u",
  unitPrice: OcptMoney(
    amountCents: amountCents,
    isTaxInclusive: true,
    vatRateBasisPoints: vatRateBasisPoints,
  ),
  elementId: null,
  inKindResourceId: inKindResourceId,
  provisionKey: null,
  provisionDigest: null,
  notes: "",
  sortKey: "a0",
);

/// A journal entry of [debitCents] (10.00 € by default), tax-inclusive, against [posteId], paying
/// [commitmentId] or none.
OcptBudgetEntry testEntry({
  required String id,
  String? posteId,
  int debitCents = 1000,
  String label = "",
  String voucherNumber = "J-001",
  String? commitmentId,
}) => OcptBudgetEntry(
  id: id,
  date: DateTime(2026),
  label: label.isEmpty ? "Entry $id" : label,
  posteId: posteId,
  debitCents: debitCents,
  creditCents: 0,
  isTaxInclusive: true,
  vatRateBasisPoints: null,
  voucherNumber: voucherNumber,
  sortKey: "a0",
  resourceId: null,
  revenueId: null,
  shareId: null,
  commitmentId: commitmentId,
  personId: null,
);

/// A `committedCentsOf` reading everything as zero — the default of `buildTable`'s own optional
/// parameter.
int testZero(String posteId) => 0;

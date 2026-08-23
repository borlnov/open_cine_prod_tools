// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_capture_band.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_date_field.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_match.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve.
Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: child),
);

/// A minimal commitment, everything but [id]/[label]/[posteId]/[amountCents]/[dueDate] neutral —
/// mirrors `ocpt_budget_entry_dialog_test.dart`'s own test doubles.
OcptBudgetCommitment _commitment({
  required String id,
  required String label,
  required String posteId,
  required int amountCents,
  DateTime? dueDate,
  bool isTaxInclusive = true,
  int? vatRateBasisPoints,
}) => OcptBudgetCommitment(
  id: id,
  dueDate: dueDate,
  label: label,
  posteId: posteId,
  amount: OcptMoney(
    amountCents: amountCents,
    isTaxInclusive: isTaxInclusive,
    vatRateBasisPoints: vatRateBasisPoints,
  ),
  status: OcptBudgetCommitmentStatus.quoteAccepted,
  settledEntryId: null,
  lineId: null,
  sortKey: "a0",
);

/// A minimal poste, everything but [id]/[label] neutral.
OcptBudgetPoste _poste({required String id, required String label}) => OcptBudgetPoste(
  id: id,
  code: "5",
  label: label,
  simpleLabel: null,
  estimateToCompleteCents: null,
  sortKey: "a0",
  lines: const [],
);

void main() {
  /// Widens the test surface so the fields row is drawn on one line — see
  /// `OcptBudgetCaptureBand`'s own `_ocptBudgetCaptureBandFieldsMinWidth`.
  void useWideWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Pumps [OcptBudgetCaptureBand] with every prop at a sensible default, overridable one at a
  /// time — no candidate of any kind and every callback recording nothing unless the test itself
  /// cares.
  Future<Tr> pumpBand(
    WidgetTester tester, {
    bool initialIsDebit = true,
    List<OcptBudgetCommitment> commitments = const [],
    List<OcptBudgetPoste> postes = const [],
    ValueChanged<OcptBudgetEntryFormFields>? onEntryCaptured,
    void Function(OcptBudgetMatchSuggestion suggestion, OcptBudgetEntryFormFields fields)?
    onSuggestionAccepted,
    ValueChanged<OcptBudgetEntryFormFields>? onOtherRequested,
  }) async {
    await tester.pumpWidget(
      _wrap(
        OcptBudgetCaptureBand(
          initialIsDebit: initialIsDebit,
          commitments: commitments,
          allowances: const [],
          resources: const [],
          revenues: const [],
          receivedByResourceId: const {},
          receivedByRevenueId: const {},
          projectVatRateBasisPoints: null,
          postes: postes,
          currencyCode: "EUR",
          onEntryCaptured: onEntryCaptured,
          onSuggestionAccepted: onSuggestionAccepted,
          onOtherRequested: onOtherRequested,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return Tr.of(tester.element(find.byType(OcptBudgetCaptureBand)));
  }

  /// Types [amount] into the amount field and [wording] into the wording field.
  Future<void> typeDraft(WidgetTester tester, {required String amount, required String wording}) async {
    await tester.enterText(find.byKey(const Key("ocptBudgetCaptureBandAmountField")), amount);
    await tester.enterText(find.byKey(const Key("ocptBudgetCaptureBandWordingField")), wording);
    await tester.pumpAndSettle();
  }

  testWidgets("renders its five controls", (tester) async {
    useWideWindow(tester);
    final tr = await pumpBand(tester);

    expect(find.text(tr.budgetCaptureBandOutOption), findsOneWidget);
    expect(find.text(tr.budgetCaptureBandInOption), findsOneWidget);
    expect(find.byKey(const Key("ocptBudgetCaptureBandAmountField")), findsOneWidget);
    expect(find.byKey(const Key("ocptBudgetCaptureBandWordingField")), findsOneWidget);
    expect(find.byType(OcptPersonSheetDateField), findsOneWidget);
    expect(find.byKey(const Key("ocptBudgetCaptureBandSaveButton")), findsOneWidget);
  });

  testWidgets("shows no suggestion while the draft is incomplete", (tester) async {
    useWideWindow(tester);
    final commitment = _commitment(
      id: "c1",
      label: "Couronne rental",
      posteId: "p1",
      amountCents: 25000,
      dueDate: DateTime(2026, 1, 15),
    );
    final tr = await pumpBand(tester, commitments: [commitment]);

    // Nothing typed at all.
    expect(find.text(tr.budgetCaptureBandNoSuggestionHint), findsOneWidget);

    // Wording alone.
    await tester.enterText(find.byKey(const Key("ocptBudgetCaptureBandWordingField")), "Couronne");
    await tester.pumpAndSettle();
    expect(find.text(tr.budgetCaptureBandNoSuggestionHint), findsOneWidget);

    // Amount alone, wording cleared.
    await tester.enterText(find.byKey(const Key("ocptBudgetCaptureBandWordingField")), "");
    await tester.enterText(find.byKey(const Key("ocptBudgetCaptureBandAmountField")), "250.00");
    await tester.pumpAndSettle();
    expect(find.text(tr.budgetCaptureBandNoSuggestionHint), findsOneWidget);

    // A zero amount does not read as positive either, even with wording filled.
    await tester.enterText(find.byKey(const Key("ocptBudgetCaptureBandWordingField")), "Couronne");
    await tester.enterText(find.byKey(const Key("ocptBudgetCaptureBandAmountField")), "0");
    await tester.pumpAndSettle();
    expect(find.text(tr.budgetCaptureBandNoSuggestionHint), findsOneWidget);
  });

  testWidgets("shows a suggestion once amount and wording are filled, naming the right candidate", (
    tester,
  ) async {
    useWideWindow(tester);
    final commitment = _commitment(
      id: "c1",
      label: "Couronne rental",
      posteId: "p1",
      amountCents: 25000,
      dueDate: DateTime(2026, 1, 15),
    );
    final poste = _poste(id: "p1", label: "Décors et costumes");
    final tr = await pumpBand(tester, commitments: [commitment], postes: [poste]);

    await typeDraft(tester, amount: "250.00", wording: "Couronne");

    expect(find.text(tr.budgetCaptureBandNoSuggestionHint), findsNothing);
    expect(find.byKey(const Key("ocptBudgetCaptureBandAcceptButton-c1")), findsOneWidget);
    expect(find.textContaining("Couronne rental"), findsOneWidget);
    expect(find.textContaining("Décors et costumes"), findsOneWidget);
  });

  testWidgets("C'est ça calls onSuggestionAccepted with the matched suggestion", (tester) async {
    useWideWindow(tester);
    final commitment = _commitment(
      id: "c1",
      label: "Couronne rental",
      posteId: "p1",
      amountCents: 25000,
      dueDate: DateTime(2026, 1, 15),
    );

    OcptBudgetMatchSuggestion? acceptedSuggestion;
    OcptBudgetEntryFormFields? acceptedFields;
    await pumpBand(
      tester,
      commitments: [commitment],
      onSuggestionAccepted: (suggestion, fields) {
        acceptedSuggestion = suggestion;
        acceptedFields = fields;
      },
    );

    await typeDraft(tester, amount: "250.00", wording: "Couronne");
    await tester.tap(find.byKey(const Key("ocptBudgetCaptureBandAcceptButton-c1")));
    await tester.pumpAndSettle();

    expect(acceptedSuggestion?.candidateId, "c1");
    expect(acceptedSuggestion?.kind, OcptBudgetMatchCandidateKind.commitment);
    // The fields handed back are the draft's own — the mode is the one that adds the
    // commitment's posteId, tax basis and VAT rate before dispatching.
    expect(acceptedFields?.label, "Couronne");
    expect(acceptedFields?.amountCents, 25000);
    expect(acceptedFields?.isDebit, isTrue);
    expect(acceptedFields?.posteId, isNull);
  });

  testWidgets("Autre chose… calls onOtherRequested with the typed fields", (tester) async {
    useWideWindow(tester);
    final commitment = _commitment(
      id: "c1",
      label: "Couronne rental",
      posteId: "p1",
      amountCents: 25000,
      dueDate: DateTime(2026, 1, 15),
    );

    OcptBudgetEntryFormFields? otherFields;
    final tr = await pumpBand(
      tester,
      commitments: [commitment],
      onOtherRequested: (fields) => otherFields = fields,
    );

    await typeDraft(tester, amount: "250.00", wording: "Couronne");
    await tester.tap(find.text(tr.budgetCaptureBandOtherAction));
    await tester.pumpAndSettle();

    expect(otherFields, isNotNull);
    expect(otherFields!.label, "Couronne");
    expect(otherFields!.amountCents, 25000);
  });

  testWidgets("plain Save calls onEntryCaptured with the typed fields, ignoring any suggestion", (
    tester,
  ) async {
    useWideWindow(tester);
    final commitment = _commitment(
      id: "c1",
      label: "Couronne rental",
      posteId: "p1",
      amountCents: 25000,
      dueDate: DateTime(2026, 1, 15),
    );

    OcptBudgetEntryFormFields? capturedFields;
    await pumpBand(
      tester,
      commitments: [commitment],
      onEntryCaptured: (fields) => capturedFields = fields,
    );

    await typeDraft(tester, amount: "250.00", wording: "Couronne");
    await tester.tap(find.byKey(const Key("ocptBudgetCaptureBandSaveButton")));
    await tester.pumpAndSettle();

    expect(capturedFields, isNotNull);
    expect(capturedFields!.label, "Couronne");
    expect(capturedFields!.amountCents, 25000);
    expect(capturedFields!.posteId, isNull);
    expect(capturedFields!.isTaxInclusive, isTrue);
    expect(capturedFields!.vatRateBasisPoints, isNull);
  });

  testWidgets("refuses to save a blank wording", (tester) async {
    useWideWindow(tester);
    OcptBudgetEntryFormFields? capturedFields;
    final tr = await pumpBand(tester, onEntryCaptured: (fields) => capturedFields = fields);

    await tester.enterText(find.byKey(const Key("ocptBudgetCaptureBandAmountField")), "42.00");
    await tester.tap(find.byKey(const Key("ocptBudgetCaptureBandSaveButton")));
    await tester.pumpAndSettle();

    expect(capturedFields, isNull);
    expect(find.text(tr.budgetEntryDialogLabelRequiredError), findsOneWidget);
  });

  testWidgets("clears the draft once Save reports it", (tester) async {
    useWideWindow(tester);
    final tr = await pumpBand(tester, onEntryCaptured: (_) {});

    await typeDraft(tester, amount: "42.00", wording: "Taxi");
    await tester.tap(find.byKey(const Key("ocptBudgetCaptureBandSaveButton")));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, "42.00"), findsNothing);
    expect(find.widgetWithText(TextFormField, "Taxi"), findsNothing);
    expect(find.text(tr.budgetCaptureBandNoSuggestionHint), findsOneWidget);
  });

  testWidgets("clears the draft once a suggestion is accepted", (tester) async {
    useWideWindow(tester);
    final commitment = _commitment(
      id: "c1",
      label: "Couronne rental",
      posteId: "p1",
      amountCents: 25000,
      dueDate: DateTime(2026, 1, 15),
    );
    final tr = await pumpBand(
      tester,
      commitments: [commitment],
      onSuggestionAccepted: (_, _) {},
    );

    await typeDraft(tester, amount: "250.00", wording: "Couronne");
    await tester.tap(find.byKey(const Key("ocptBudgetCaptureBandAcceptButton-c1")));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, "250.00"), findsNothing);
    expect(find.text(tr.budgetCaptureBandNoSuggestionHint), findsOneWidget);
  });

  testWidgets("the narrow-width layout does not overflow, and every control stays reachable", (
    tester,
  ) async {
    // The width the right dock leaves the centre on an ordinary window — the same narrow case
    // `OcptBudgetHeader`'s own tests use, and one the fields row's own two-line fallback is meant
    // to cover: the four fields plus `Save` do not fit one one line under this.
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    OcptBudgetEntryFormFields? capturedFields;
    await pumpBand(tester, onEntryCaptured: (fields) => capturedFields = fields);
    expect(tester.takeException(), isNull);

    expect(find.byKey(const Key("ocptBudgetCaptureBandAmountField")), findsOneWidget);
    expect(find.byKey(const Key("ocptBudgetCaptureBandWordingField")), findsOneWidget);
    expect(find.byType(OcptPersonSheetDateField), findsOneWidget);
    expect(find.byKey(const Key("ocptBudgetCaptureBandSaveButton")), findsOneWidget);

    await typeDraft(tester, amount: "42.00", wording: "Taxi");
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key("ocptBudgetCaptureBandSaveButton")));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(capturedFields?.label, "Taxi");
  });
}

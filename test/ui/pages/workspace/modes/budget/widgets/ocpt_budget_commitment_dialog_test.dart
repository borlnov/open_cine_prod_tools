// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_commitment_dialog.dart';

/// A router manager whose [pop] only records the last call and its value — mirrors
/// `ocpt_budget_entry_dialog_test.dart`'s own instance of this pattern.
class _RecordingRouterManager extends OcptRouterManager {
  /// Whether [pop] was called.
  bool popped = false;

  /// The value [pop] was last called with.
  Object? poppedValue;

  @override
  void pop<Y extends Object?>([Y? result]) {
    popped = true;
    poppedValue = result;
  }
}

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve in tests.
Widget _wrapWithLocalization(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: child,
);

/// A minimal poste, everything but [id]/[label] neutral.
OcptBudgetPoste _poste({required String id, required String label}) =>
    OcptBudgetPoste(id: id, code: "1", label: label, simpleLabel: null, estimateToCompleteCents: null, sortKey: "a0", lines: const []);

/// A minimal existing commitment, everything but what each test actually varies neutral.
OcptBudgetCommitment _existingCommitment({
  String id = "commitment-1",
  DateTime? dueDate,
  String label = "Camera deposit",
  String posteId = "poste-1",
  int amountCents = 1250,
  bool isTaxInclusive = true,
  int? vatRateBasisPoints,
  OcptBudgetCommitmentStatus status = OcptBudgetCommitmentStatus.quoteAccepted,
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
  status: status,
  lineId: null,
  sortKey: "a0",
);

void main() {
  late _RecordingRouterManager routerManager;

  setUpAll(() {
    OcptGlobalManager.instance;
  });

  setUp(() async {
    final managers = globalGetIt();
    if (managers.isRegistered<OcptRouterManager>()) {
      await managers.unregister<OcptRouterManager>();
    }

    routerManager = _RecordingRouterManager();
    managers.registerSingleton<OcptRouterManager>(routerManager);
  });

  /// Pumps [OcptBudgetCommitmentDialog] directly (no `.show`), creating a new commitment unless
  /// [existing] is given.
  Future<Tr> pumpDialog(
    WidgetTester tester, {
    OcptBudgetCommitment? existing,
    List<OcptBudgetPoste> postes = const [],
    int? defaultVatRateBasisPoints,
  }) async {
    // The default test surface is too short for the dialog's own scrollable content to lay every
    // field out without one ending up outside the hit-testable area.
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptBudgetCommitmentDialog(
          existing: existing,
          postes: postes,
          currencyCode: "EUR",
          defaultVatRateBasisPoints: defaultVatRateBasisPoints,
          isSimplified: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    return Tr.of(tester.element(find.byType(OcptBudgetCommitmentDialog)));
  }

  testWidgets("Save is withheld until both the label and the poste are filled", (tester) async {
    final poste = _poste(id: "poste-1", label: "Camera");
    final tr = await pumpDialog(tester, postes: [poste]);

    expect(find.text(tr.budgetCommitmentDialogMissingLabelAndPosteHint), findsOneWidget);
    var saveButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, tr.budgetEntryDialogConfirmAction));
    expect(saveButton.onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Camera deposit",
    );
    await tester.pump();
    expect(find.text(tr.budgetCommitmentDialogMissingPosteHint), findsOneWidget);
    saveButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, tr.budgetEntryDialogConfirmAction));
    expect(saveButton.onPressed, isNull);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Camera").last);
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetCommitmentDialogMissingLabelAndPosteHint), findsNothing);
    expect(find.text(tr.budgetCommitmentDialogMissingPosteHint), findsNothing);
    saveButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, tr.budgetEntryDialogConfirmAction));
    expect(saveButton.onPressed, isNotNull);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "10",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final fields = routerManager.poppedValue! as OcptBudgetCommitmentFormFields;
    expect(fields.label, "Camera deposit");
    expect(fields.posteId, "poste-1");
  });

  testWidgets("editing pre-fills every field, the poste picker included", (tester) async {
    final existing = _existingCommitment(vatRateBasisPoints: 550, status: OcptBudgetCommitmentStatus.declared);
    final poste = _poste(id: "poste-1", label: "Camera");
    final tr = await pumpDialog(tester, existing: existing, postes: [poste]);

    expect(find.widgetWithText(TextFormField, "Camera deposit"), findsOneWidget);
    expect(find.widgetWithText(TextFormField, "12.50"), findsOneWidget);
    expect(find.text("Camera"), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final fields = routerManager.poppedValue! as OcptBudgetCommitmentFormFields;
    expect(fields.amountCents, 1250);
    expect(fields.posteId, "poste-1");
    expect(fields.vatRateBasisPoints, 550);
    expect(fields.status, OcptBudgetCommitmentStatus.declared);
  });

  testWidgets("editing can move a commitment to another poste", (tester) async {
    final existing = _existingCommitment();
    final tr = await pumpDialog(
      tester,
      existing: existing,
      postes: [_poste(id: "poste-1", label: "Camera"), _poste(id: "poste-2", label: "Sound")],
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Sound").last);
    await tester.pumpAndSettle();

    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    final fields = routerManager.poppedValue! as OcptBudgetCommitmentFormFields;
    expect(fields.posteId, "poste-2");
  });

  testWidgets("an empty due date is a real state, not a placeholder for today", (tester) async {
    final poste = _poste(id: "poste-1", label: "Camera");
    final tr = await pumpDialog(tester, postes: [poste]);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Camera deposit",
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Camera").last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "10",
    );

    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    final fields = routerManager.poppedValue! as OcptBudgetCommitmentFormFields;
    expect(fields.dueDate, isNull);
  });

  testWidgets("an empty VAT field pops with a null override, meaning inherit", (tester) async {
    final poste = _poste(id: "poste-1", label: "Camera");
    final tr = await pumpDialog(tester, postes: [poste]);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Camera deposit",
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Camera").last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "10",
    );

    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    final fields = routerManager.poppedValue! as OcptBudgetCommitmentFormFields;
    expect(fields.vatRateBasisPoints, isNull);
  });

  testWidgets("the status picker defaults to quote accepted and reports the pick", (tester) async {
    final poste = _poste(id: "poste-1", label: "Camera");
    final tr = await pumpDialog(tester, postes: [poste]);

    expect(find.text(tr.budgetCommittedStatusQuoteAcceptedLabel), findsOneWidget);

    await tester.tap(find.text(tr.budgetCommittedStatusDeclaredLabel));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Camera deposit",
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Camera").last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "10",
    );

    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    final fields = routerManager.poppedValue! as OcptBudgetCommitmentFormFields;
    expect(fields.status, OcptBudgetCommitmentStatus.declared);
  });

  testWidgets("cancelling pops with nothing", (tester) async {
    final tr = await pumpDialog(tester);

    await tester.tap(find.text(tr.budgetEntryDialogCancelAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    expect(routerManager.poppedValue, isNull);
  });
}

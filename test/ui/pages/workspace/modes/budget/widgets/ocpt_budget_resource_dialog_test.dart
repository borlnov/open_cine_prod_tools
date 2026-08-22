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
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource_form_fields.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_resource_dialog.dart';

/// A router manager whose [pop] only records the last call and its value — mirrors
/// `ocpt_budget_commitment_dialog_test.dart`'s own instance of this pattern.
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

/// A minimal existing resource, everything but what each test actually varies neutral.
OcptBudgetResource _existingResource({
  String id = "resource-1",
  OcptBudgetResourceGroupKind groupKind = OcptBudgetResourceGroupKind.subsidy,
  String label = "Regional grant",
  int amountCents = 500000,
  OcptBudgetResourceStatus status = OcptBudgetResourceStatus.applied,
  bool isReimbursable = false,
  String notes = "",
}) => OcptBudgetResource(
  id: id,
  groupKind: groupKind,
  label: label,
  amountCents: amountCents,
  status: status,
  isReimbursable: isReimbursable,
  notes: notes,
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

  /// Pumps [OcptBudgetResourceDialog] directly (no `.show`), creating a new resource unless
  /// [existing] is given.
  Future<Tr> pumpDialog(WidgetTester tester, {OcptBudgetResource? existing}) async {
    // The default test surface is too short for the dialog's own scrollable content to lay every
    // field out without one ending up outside the hit-testable area.
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptBudgetResourceDialog(existing: existing, currencyCode: "EUR"),
      ),
    );
    await tester.pumpAndSettle();

    return Tr.of(tester.element(find.byType(OcptBudgetResourceDialog)));
  }

  testWidgets("Save is withheld until the label is filled", (tester) async {
    final tr = await pumpDialog(tester);

    var saveButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, tr.budgetEntryDialogConfirmAction));
    expect(saveButton.onPressed, isNotNull);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "10",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetEntryDialogLabelRequiredError), findsOneWidget);
    expect(routerManager.popped, isFalse);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Regional grant",
    );
    saveButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, tr.budgetEntryDialogConfirmAction));
    expect(saveButton.onPressed, isNotNull);

    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final fields = routerManager.poppedValue! as OcptBudgetResourceFormFields;
    expect(fields.label, "Regional grant");
    expect(fields.amountCents, 1000);
  });

  testWidgets("defaults to the first group, applied and not reimbursable", (tester) async {
    final tr = await pumpDialog(tester);

    expect(find.text(tr.budgetFinancingGroupSubsidyLabel), findsOneWidget);
    expect(find.text(tr.budgetFinancingStatusAppliedLabel), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Regional grant",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "10",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    final fields = routerManager.poppedValue! as OcptBudgetResourceFormFields;
    expect(fields.groupKind, OcptBudgetResourceGroupKind.subsidy);
    expect(fields.status, OcptBudgetResourceStatus.applied);
    expect(fields.isReimbursable, isFalse);
  });

  testWidgets("editing pre-fills every field", (tester) async {
    final existing = _existingResource(
      groupKind: OcptBudgetResourceGroupKind.inKind,
      status: OcptBudgetResourceStatus.valued,
      isReimbursable: true,
      notes: "Camera lent by the lab",
    );
    final tr = await pumpDialog(tester, existing: existing);

    expect(find.widgetWithText(TextFormField, "Regional grant"), findsOneWidget);
    expect(find.widgetWithText(TextFormField, "5000.00"), findsOneWidget);
    expect(find.widgetWithText(TextFormField, "Camera lent by the lab"), findsOneWidget);

    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final fields = routerManager.poppedValue! as OcptBudgetResourceFormFields;
    expect(fields.groupKind, OcptBudgetResourceGroupKind.inKind);
    expect(fields.status, OcptBudgetResourceStatus.valued);
    expect(fields.isReimbursable, isTrue);
    expect(fields.notes, "Camera lent by the lab");
    expect(fields.amountCents, 500000);
  });

  testWidgets("picking a different group and status reports the pick", (tester) async {
    final tr = await pumpDialog(tester);

    await tester.tap(find.text(tr.budgetFinancingGroupInKindLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.budgetFinancingStatusValuedLabel));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Camera loan",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "10",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    final fields = routerManager.poppedValue! as OcptBudgetResourceFormFields;
    expect(fields.groupKind, OcptBudgetResourceGroupKind.inKind);
    expect(fields.status, OcptBudgetResourceStatus.valued);
  });

  testWidgets("the reimbursable choice reports the pick", (tester) async {
    final tr = await pumpDialog(tester);

    await tester.tap(find.text(tr.budgetResourceDialogReimbursableOption));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Cash contribution",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "10",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    final fields = routerManager.poppedValue! as OcptBudgetResourceFormFields;
    expect(fields.isReimbursable, isTrue);
  });

  testWidgets("cancelling pops with nothing", (tester) async {
    final tr = await pumpDialog(tester);

    await tester.tap(find.text(tr.budgetEntryDialogCancelAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    expect(routerManager.poppedValue, isNull);
  });
}

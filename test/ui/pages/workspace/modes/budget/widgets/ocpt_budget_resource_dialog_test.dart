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
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
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
  OcptBudgetResourceStatus status = OcptBudgetResourceStatus.pending,
  bool isReimbursable = false,
  String notes = "",
}) => OcptBudgetResource(
  id: id,
  groupKind: groupKind,
  personId: null,
  label: label,
  amountCents: amountCents,
  status: status,
  isReimbursable: isReimbursable,
  notes: notes,
  sortKey: "a0",
);

/// A minimal person, the few fields these tests read, everything else neutral — mirrors
/// `ocpt_budget_share_dialog_test.dart`'s own instance of this pattern.
OcptPerson _person({required String id, String firstName = "Alice", String lastName = "Martin"}) => OcptPerson(
  id: id,
  firstName: firstName,
  lastName: lastName,
  email: "",
  phone: "",
  addressLine1: "",
  addressLine2: "",
  postalCode: "",
  city: "",
  region: "",
  country: "",
  colorIndex: 0,
  birthDate: null,
  minorNotes: "",
  maxDailyPresenceMinutes: null,
  isTransportAutonomous: null,
  accommodationNotes: "",
  travelNotes: "",
  dietaryNotes: "",
  allergies: "",
  measurementHeight: "",
  measurementChest: "",
  measurementWaist: "",
  measurementHips: "",
  sizeTop: "",
  sizeBottom: "",
  sizeShoes: "",
  hmcNotes: "",
  imageRightsStatus: OcptImageRightsStatus.notApplicable,
  imageRightsDate: null,
  imageRightsAssetId: null,
  imageRightsDocument: null,
  photoAssetId: null,
  photo: null,
  notes: "",
  commuteKmMilli: null,
  mileageRateId: null,
  positions: const [],
  skills: const [],
  unavailabilities: const [],
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

  /// Pumps [OcptBudgetResourceDialog] directly (no `.show`), creating a new resource of
  /// [groupKind] unless [existing] is given.
  Future<Tr> pumpDialog(
    WidgetTester tester, {
    OcptBudgetResource? existing,
    OcptBudgetResourceGroupKind groupKind = OcptBudgetResourceGroupKind.subsidy,
    List<OcptPerson> people = const [],
  }) async {
    // The default test surface is too short for the dialog's own scrollable content to lay every
    // field out without one ending up outside the hit-testable area.
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapWithLocalization(
        OcptBudgetResourceDialog(
          existing: existing,
          groupKind: groupKind,
          people: people,
          currencyCode: "EUR",
        ),
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

  testWidgets("creating fixes the group to the one picked, applied and not reimbursable", (tester) async {
    final tr = await pumpDialog(tester);

    // The `Group` picker is hidden while creating — the kind is already decided by which of the
    // three creation gestures opened this dialog, so it is not asked for again here.
    expect(find.text(tr.budgetFinancingGroupSubsidyLabel), findsNothing);
    expect(find.text(tr.budgetResourceDialogCreateSubsidyTitle), findsOneWidget);
    expect(find.text(tr.budgetFinancingStatusSubsidyPendingLabel), findsOneWidget);

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
    expect(fields.personId, isNull);
    expect(fields.status, OcptBudgetResourceStatus.pending);
    expect(fields.isReimbursable, isFalse);
  });

  testWidgets("the title names a fresh cash contribution", (tester) async {
    final tr = await pumpDialog(tester, groupKind: OcptBudgetResourceGroupKind.cash);
    expect(find.text(tr.budgetResourceDialogCreateCashTitle), findsOneWidget);
  });

  testWidgets("the title names a fresh in-kind contribution", (tester) async {
    final tr = await pumpDialog(tester, groupKind: OcptBudgetResourceGroupKind.inKind);
    expect(find.text(tr.budgetResourceDialogCreateInKindTitle), findsOneWidget);
  });

  testWidgets("the status picker reads in the kind's own vocabulary", (tester) async {
    // The same three steps, worded by the group the resource sits in: a subsidy is applied for,
    // notified, secured, and never — as it once could be — "valued" like a lent camera.
    final tr = await pumpDialog(tester);

    expect(find.text(tr.budgetFinancingStatusSubsidyPendingLabel), findsOneWidget);
    expect(find.text(tr.budgetFinancingStatusSubsidyAgreedLabel), findsOneWidget);
    expect(find.text(tr.budgetFinancingStatusSubsidyConfirmedLabel), findsOneWidget);
    expect(find.text(tr.budgetFinancingStatusInKindAgreedLabel), findsNothing);
    expect(find.text(tr.budgetFinancingStatusCashConfirmedLabel), findsNothing);
  });

  testWidgets("a fresh in-kind contribution is promised, valued, signed", (tester) async {
    final tr = await pumpDialog(tester, groupKind: OcptBudgetResourceGroupKind.inKind);

    expect(find.text(tr.budgetFinancingStatusInKindPendingLabel), findsOneWidget);
    expect(find.text(tr.budgetFinancingStatusInKindAgreedLabel), findsOneWidget);
    expect(find.text(tr.budgetFinancingStatusInKindConfirmedLabel), findsOneWidget);
    expect(find.text(tr.budgetFinancingStatusSubsidyPendingLabel), findsNothing);
  });

  testWidgets("editing pre-fills every field, title kept generic", (tester) async {
    final existing = _existingResource(
      groupKind: OcptBudgetResourceGroupKind.inKind,
      status: OcptBudgetResourceStatus.agreed,
      isReimbursable: true,
      notes: "Camera lent by the lab",
    );
    final tr = await pumpDialog(tester, existing: existing);

    // Editing is where the `Group` picker stays, unlike creation — a production is free to
    // reclassify a resource it already created.
    expect(find.text(tr.budgetResourceDialogEditTitle), findsOneWidget);
    expect(find.text(tr.budgetFinancingGroupInKindLabel), findsOneWidget);
    expect(find.widgetWithText(TextFormField, "Regional grant"), findsOneWidget);
    expect(find.widgetWithText(TextFormField, "5000.00"), findsOneWidget);
    expect(find.widgetWithText(TextFormField, "Camera lent by the lab"), findsOneWidget);

    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final fields = routerManager.poppedValue! as OcptBudgetResourceFormFields;
    expect(fields.groupKind, OcptBudgetResourceGroupKind.inKind);
    expect(fields.status, OcptBudgetResourceStatus.agreed);
    expect(fields.isReimbursable, isTrue);
    expect(fields.notes, "Camera lent by the lab");
    expect(fields.amountCents, 500000);
  });

  testWidgets("editing can pick a different group and status", (tester) async {
    final existing = _existingResource();
    final tr = await pumpDialog(tester, existing: existing);

    await tester.tap(find.text(tr.budgetFinancingGroupInKindLabel));
    await tester.pumpAndSettle();

    // Picking the in-kind group has just re-worded the status chips: the middle step reads
    // `Valued` here, where the subsidy this resource was a moment ago called it `Notified`.
    await tester.tap(find.text(tr.budgetFinancingStatusInKindAgreedLabel));
    await tester.pumpAndSettle();

    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    final fields = routerManager.poppedValue! as OcptBudgetResourceFormFields;
    expect(fields.groupKind, OcptBudgetResourceGroupKind.inKind);
    expect(fields.status, OcptBudgetResourceStatus.agreed);
  });

  testWidgets("picking a different status while creating reports the pick", (tester) async {
    final tr = await pumpDialog(tester);

    await tester.tap(find.text(tr.budgetFinancingStatusSubsidyAgreedLabel));
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
    expect(fields.groupKind, OcptBudgetResourceGroupKind.subsidy);
    expect(fields.status, OcptBudgetResourceStatus.agreed);
  });

  testWidgets("picking a person reports the pick", (tester) async {
    final person = _person(id: "p1");
    final tr = await pumpDialog(tester, people: [person]);

    expect(find.text(tr.budgetShareDialogNoPersonLabel), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(person.displayName).last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Cash from Alice",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogAmountFieldLabel),
      "10",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    final fields = routerManager.poppedValue! as OcptBudgetResourceFormFields;
    expect(fields.personId, "p1");
  });

  testWidgets("the amount field is worded for an in-kind contribution", (tester) async {
    final tr = await pumpDialog(tester, groupKind: OcptBudgetResourceGroupKind.inKind);

    expect(find.text(tr.budgetResourceDialogValuedAtFieldLabel), findsOneWidget);
    expect(find.text(tr.budgetResourceDialogAmountHelperInKind), findsOneWidget);
    expect(find.text(tr.budgetEntryDialogAmountFieldLabel), findsNothing);
  });

  testWidgets("the amount field is worded for a subsidy", (tester) async {
    final tr = await pumpDialog(tester);

    expect(find.text(tr.budgetEntryDialogAmountFieldLabel), findsOneWidget);
    expect(find.text(tr.budgetResourceDialogAmountHelperSubsidy), findsOneWidget);
    expect(find.text(tr.budgetResourceDialogValuedAtFieldLabel), findsNothing);
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

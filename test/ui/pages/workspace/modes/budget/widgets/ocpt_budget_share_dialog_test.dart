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
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share_form_fields.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_share_dialog.dart';

/// A router manager whose [pop] only records the last call and its value — mirrors
/// `ocpt_budget_resource_dialog_test.dart`'s own instance of this pattern.
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

/// A minimal existing share, everything but what each test actually varies neutral.
OcptBudgetShare _existingShare({
  String id = "share-1",
  String? personId,
  String label = "Production",
  int sharePermille = 400,
  int reinvestPermille = 0,
  String notes = "",
}) => OcptBudgetShare(
  id: id,
  personId: personId,
  label: label,
  sharePermille: sharePermille,
  reinvestPermille: reinvestPermille,
  notes: notes,
  sortKey: "a0",
);

/// A minimal person, the few fields these tests read, everything else neutral.
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

  /// Pumps [OcptBudgetShareDialog] directly (no `.show`), creating a new share unless [existing]
  /// is given.
  Future<Tr> pumpDialog(
    WidgetTester tester, {
    OcptBudgetShare? existing,
    List<OcptPerson> people = const [],
  }) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrapWithLocalization(OcptBudgetShareDialog(existing: existing, people: people)),
    );
    await tester.pumpAndSettle();

    return Tr.of(tester.element(find.byType(OcptBudgetShareDialog)));
  }

  testWidgets("Save is withheld until the label is filled", (tester) async {
    final tr = await pumpDialog(tester);

    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetEntryDialogLabelRequiredError), findsOneWidget);
    expect(routerManager.popped, isFalse);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Production",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final fields = routerManager.poppedValue! as OcptBudgetShareFormFields;
    expect(fields.label, "Production");
  });

  testWidgets("defaults to no person, 0% share and 0% reinvest", (tester) async {
    final tr = await pumpDialog(tester);

    expect(find.text(tr.budgetShareDialogNoPersonLabel), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Production",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    final fields = routerManager.poppedValue! as OcptBudgetShareFormFields;
    expect(fields.personId, isNull);
    expect(fields.sharePermille, 0);
    expect(fields.reinvestPermille, 0);
  });

  testWidgets("editing pre-fills every field", (tester) async {
    final existing = _existingShare(
      personId: "p1",
      reinvestPermille: 250,
      notes: "Agreed in the co-production contract",
    );
    final tr = await pumpDialog(tester, existing: existing, people: [_person(id: "p1")]);

    expect(find.widgetWithText(TextFormField, "Production"), findsOneWidget);
    expect(find.widgetWithText(TextFormField, "40"), findsOneWidget);
    expect(find.widgetWithText(TextFormField, "25"), findsOneWidget);
    expect(find.widgetWithText(TextFormField, "Agreed in the co-production contract"), findsOneWidget);

    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    final fields = routerManager.poppedValue! as OcptBudgetShareFormFields;
    expect(fields.personId, "p1");
    expect(fields.sharePermille, 400);
    expect(fields.reinvestPermille, 250);
  });

  testWidgets("picking a person reports the pick", (tester) async {
    final person = _person(id: "p1");
    final tr = await pumpDialog(tester, people: [person]);

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(person.displayName).last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Director",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    final fields = routerManager.poppedValue! as OcptBudgetShareFormFields;
    expect(fields.personId, "p1");
  });

  testWidgets("an invalid share percentage is refused, and nothing is popped", (tester) async {
    final tr = await pumpDialog(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetEntryDialogLabelFieldLabel),
      "Production",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, tr.budgetShareDialogShareFieldLabel),
      "not a number",
    );
    await tester.tap(find.text(tr.budgetEntryDialogConfirmAction));
    await tester.pumpAndSettle();

    expect(find.text(tr.budgetShareDialogPercentInvalidError), findsOneWidget);
    expect(routerManager.popped, isFalse);
  });

  testWidgets("cancelling pops with nothing", (tester) async {
    final tr = await pumpDialog(tester);

    await tester.tap(find.text(tr.budgetEntryDialogCancelAction));
    await tester.pumpAndSettle();

    expect(routerManager.popped, isTrue);
    expect(routerManager.poppedValue, isNull);
  });
}

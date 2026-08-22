// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_revenue.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_revenue_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_sharing.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_shares.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_totals.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a wide, tall
/// enough band that both columns lay out side by side with no scroll needed to find a cell.
Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 1400, height: 900, child: child)),
);

/// A minimal taking, everything but what each test actually varies neutral.
OcptBudgetRevenue _revenue({
  required String id,
  DateTime? date,
  String label = "Festival prize",
  int amountCents = 10000,
  OcptBudgetRevenueStatus status = OcptBudgetRevenueStatus.expected,
  String notes = "",
}) => OcptBudgetRevenue(
  id: id,
  date: date ?? DateTime(2026, 3),
  label: label,
  amountCents: amountCents,
  status: status,
  notes: notes,
  sortKey: "a0",
);

/// A minimal share, everything but what each test actually varies neutral.
OcptBudgetShare _share({
  required String id,
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

/// A minimal person, the few fields these tests read, everything else neutral — mirrors
/// `ocpt_budget_regie_test.dart`'s own `_buildPerson`.
OcptPerson _person({required String id, String firstName = "Jane", String lastName = "Doe"}) => OcptPerson(
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

/// A zero-amount, fully-covered total — the default reading of an amount nothing names.
const _zeroTotal = OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0);

void main() {
  /// Pumps [OcptBudgetSharing] with every callback a no-op unless overridden.
  Future<void> pumpView(
    WidgetTester tester, {
    List<OcptBudgetRevenue> revenues = const [],
    List<OcptBudgetShare> shares = const [],
    Map<String, OcptBudgetCoveredTotal> receivedByRevenueId = const {},
    OcptBudgetSharingPot? sharingPot,
    List<OcptBudgetShareSplit>? shareSplits,
    List<OcptPerson> people = const [],
    String? selectedRevenueId,
    String? selectedShareId,
    bool isReadOnly = false,
    VoidCallback? onRevenueCreationRequested,
    ValueChanged<String>? onRevenueSelected,
    ValueChanged<OcptBudgetRevenue>? onRevenueEditRequested,
    ValueChanged<OcptBudgetRevenue>? onRevenueReceiptRequested,
    void Function(String revenueId, {required bool moveUp})? onRevenueReorderRequested,
    ValueChanged<String>? onRevenueDeletionRequested,
    VoidCallback? onShareCreationRequested,
    ValueChanged<String>? onShareSelected,
    ValueChanged<OcptBudgetShare>? onShareEditRequested,
    ValueChanged<OcptBudgetShare>? onSharePayoutRequested,
    void Function(String shareId, {required bool moveUp})? onShareReorderRequested,
    ValueChanged<String>? onShareDeletionRequested,
  }) async {
    final pot =
        sharingPot ??
        const OcptBudgetSharingPot(received: _zeroTotal, reimbursableCents: 0, repaid: _zeroTotal);
    final splits =
        shareSplits ??
        ocptBudgetShareSplitsOf(
          shares: shares,
          pot: pot,
          paidByShareId: const {},
        );

    // The default test surface is narrower than `_ocptSharingWrapWidth`, which would stack the
    // two columns instead of laying them out side by side.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        OcptBudgetSharing(
          revenues: revenues,
          shares: shares,
          receivedByRevenueId: receivedByRevenueId,
          sharingPot: pot,
          shareSplits: splits,
          people: people,
          currencyCode: "EUR",
          selectedRevenueId: selectedRevenueId,
          selectedShareId: selectedShareId,
          isReadOnly: isReadOnly,
          onRevenueCreationRequested: onRevenueCreationRequested ?? () {},
          onRevenueSelected: onRevenueSelected ?? (_) {},
          onRevenueEditRequested: onRevenueEditRequested ?? (_) {},
          onRevenueReceiptRequested: onRevenueReceiptRequested ?? (_) {},
          onRevenueReorderRequested: onRevenueReorderRequested ?? (_, {required moveUp}) {},
          onRevenueDeletionRequested: onRevenueDeletionRequested ?? (_) {},
          onShareCreationRequested: onShareCreationRequested ?? () {},
          onShareSelected: onShareSelected ?? (_) {},
          onShareEditRequested: onShareEditRequested ?? (_) {},
          onSharePayoutRequested: onSharePayoutRequested ?? (_) {},
          onShareReorderRequested: onShareReorderRequested ?? (_, {required moveUp}) {},
          onShareDeletionRequested: onShareDeletionRequested ?? (_) {},
        ),
      ),
    );
  }

  testWidgets(
    "a taking whose received figure differs from its expected one prints both",
    (tester) async {
      final revenue = _revenue(id: "r1", amountCents: 5000);

      await pumpView(
        tester,
        revenues: [revenue],
        receivedByRevenueId: const {
          "r1": OcptBudgetCoveredTotal(amountCents: 3000, coveredLineCount: 1, lineCount: 1),
        },
      );

      expect(find.text(ocptBudgetAmountLabel(3000, "EUR")), findsWidgets);
      expect(find.text(ocptBudgetAmountLabel(5000, "EUR")), findsWidgets);
    },
  );

  testWidgets(
    "a taking whose received figure matches its expected one prints it only once",
    (tester) async {
      final revenue = _revenue(id: "r1", amountCents: 5000);

      await pumpView(
        tester,
        revenues: [revenue],
        receivedByRevenueId: const {
          "r1": OcptBudgetCoveredTotal(amountCents: 5000, coveredLineCount: 1, lineCount: 1),
        },
      );

      // Once for the row's own received figure, once for the footer total — never a third time as
      // a quiet "expected" caption, since the two amounts agree.
      expect(find.text(ocptBudgetAmountLabel(5000, "EUR")), findsNWidgets(2));
    },
  );

  testWidgets("the takings coverage read-out appears while some takings carry no known rate", (
    tester,
  ) async {
    final revenue = _revenue(id: "r1", amountCents: 5000);

    await pumpView(
      tester,
      revenues: [revenue],
      receivedByRevenueId: const {
        "r1": OcptBudgetCoveredTotal(amountCents: 5000, coveredLineCount: 0, lineCount: 1),
      },
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetSharing)));
    expect(
      find.text(tr.budgetSharingTakingsCoverageReadOut(ocptBudgetAmountLabel(5000, "EUR"), 0, 1)),
      findsOneWidget,
    );
  });

  testWidgets("the takings coverage read-out disappears once every taking is fully known", (
    tester,
  ) async {
    final revenue = _revenue(id: "r1", amountCents: 5000);

    await pumpView(
      tester,
      revenues: [revenue],
      receivedByRevenueId: const {
        "r1": OcptBudgetCoveredTotal(amountCents: 5000, coveredLineCount: 1, lineCount: 1),
      },
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetSharing)));
    expect(find.text(tr.budgetSharingTakingsCoverageReadOut(ocptBudgetAmountLabel(5000, "EUR"), 1, 1)), findsNothing);
  });

  testWidgets("the shares mismatch line appears when the live shares do not sum to 1000", (
    tester,
  ) async {
    final shares = [_share(id: "s1")];

    await pumpView(tester, shares: shares);

    final tr = Tr.of(tester.element(find.byType(OcptBudgetSharing)));
    expect(
      find.text(
        tr.budgetSharingSharesMismatchReadOut(
          ocptBudgetAmountLabel(0, "EUR"),
          ocptBudgetAmountLabel(0, "EUR"),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets("the shares mismatch line disappears once the live shares sum to exactly 1000", (
    tester,
  ) async {
    final shares = [_share(id: "s1", sharePermille: 600), _share(id: "s2")];

    await pumpView(tester, shares: shares);

    final tr = Tr.of(tester.element(find.byType(OcptBudgetSharing)));
    expect(
      find.text(
        tr.budgetSharingSharesMismatchReadOut(
          ocptBudgetAmountLabel(0, "EUR"),
          ocptBudgetAmountLabel(0, "EUR"),
        ),
      ),
      findsNothing,
    );
  });

  testWidgets("a share naming a person prints that person's own name as a quiet second line", (
    tester,
  ) async {
    final person = _person(id: "p1", firstName: "Alice", lastName: "Martin");
    final share = _share(id: "s1", personId: "p1", label: "Director");

    await pumpView(tester, shares: [share], people: [person]);

    expect(find.text("Director"), findsOneWidget);
    expect(find.textContaining("Alice"), findsOneWidget);
  });

  testWidgets("clicking a taking row selects it, and only that", (tester) async {
    final revenue = _revenue(id: "r1", label: "Regional prize");
    String? selected;

    await pumpView(tester, revenues: [revenue], onRevenueSelected: (id) => selected = id);

    await tester.tap(find.text("Regional prize"));

    expect(selected, "r1");
  });

  testWidgets("clicking a share row selects it, and only that", (tester) async {
    final share = _share(id: "s1", label: "Regional co-producer");
    String? selected;

    await pumpView(tester, shares: [share], onShareSelected: (id) => selected = id);

    await tester.tap(find.text("Regional co-producer"));

    expect(selected, "s1");
  });

  testWidgets("a taking row's ⋮ menu Delete entry asks through the callback rather than deleting", (
    tester,
  ) async {
    final revenue = _revenue(id: "r1", label: "Regional prize");
    String? deletionRequested;

    await pumpView(
      tester,
      revenues: [revenue],
      onRevenueDeletionRequested: (id) => deletionRequested = id,
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetSharing)));
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.budgetCommittedDeleteAction));
    await tester.pumpAndSettle();

    expect(deletionRequested, "r1");
    expect(find.text("Regional prize"), findsOneWidget);
  });

  testWidgets("a share row's ⋮ menu offers Record a payout, reporting the share it names", (
    tester,
  ) async {
    final share = _share(id: "s1", label: "Regional co-producer");
    OcptBudgetShare? payoutRequested;

    await pumpView(
      tester,
      shares: [share],
      onSharePayoutRequested: (share) => payoutRequested = share,
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetSharing)));
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.budgetSharingRecordPayoutAction));
    await tester.pumpAndSettle();

    expect(payoutRequested?.id, "s1");
  });

  testWidgets("every writing affordance is withheld under a read-only preview", (tester) async {
    final revenue = _revenue(id: "r1", label: "Regional prize");
    final share = _share(id: "s1", label: "Regional co-producer");

    await pumpView(tester, revenues: [revenue], shares: [share], isReadOnly: true);

    final tr = Tr.of(tester.element(find.byType(OcptBudgetSharing)));
    expect(find.text(tr.budgetSharingRevenueCreationAction), findsNothing);
    expect(find.text(tr.budgetSharingShareCreationAction), findsNothing);
    // No menu at all: every one of its own entries would be withheld.
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });
}

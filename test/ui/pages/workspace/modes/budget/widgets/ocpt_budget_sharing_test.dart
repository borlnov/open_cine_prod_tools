// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_share.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
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
    List<OcptBudgetShare> shares = const [],
    OcptBudgetSharingPot? sharingPot,
    List<OcptBudgetRepaymentLine> repaymentLines = const [],
    List<OcptBudgetShareSplit>? shareSplits,
    List<OcptPerson> people = const [],
    String? selectedShareId,
    bool isReadOnly = false,
    VoidCallback? onShareCreationRequested,
    ValueChanged<String>? onShareSelected,
    ValueChanged<OcptBudgetShare>? onShareEditRequested,
    ValueChanged<OcptBudgetShare>? onSharePayoutRequested,
    void Function(String shareId, {required bool moveUp})? onShareReorderRequested,
    ValueChanged<String>? onShareDeletionRequested,
    ValueChanged<OcptBudgetRepaymentLine>? onRepaymentRequested,
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
          shares: shares,
          sharingPot: pot,
          repaymentLines: repaymentLines,
          shareSplits: splits,
          people: people,
          currencyCode: "EUR",
          selectedShareId: selectedShareId,
          isReadOnly: isReadOnly,
          onShareCreationRequested: onShareCreationRequested ?? () {},
          onShareSelected: onShareSelected ?? (_) {},
          onShareEditRequested: onShareEditRequested ?? (_) {},
          onSharePayoutRequested: onSharePayoutRequested ?? (_) {},
          onShareReorderRequested: onShareReorderRequested ?? (_, {required moveUp}) {},
          onShareDeletionRequested: onShareDeletionRequested ?? (_) {},
          onRepaymentRequested: onRepaymentRequested,
        ),
      ),
    );
  }

  testWidgets("the view draws no takings row at all — the resources tree owns them now", (
    tester,
  ) async {
    await pumpView(tester);

    // Nothing left of the `Takings received` card: no title, no `+ Taking` creation footer. Only
    // two cards remain — `Repaying the contributions` and `Distribution` — where a third,
    // `Takings received`, used to sit above them.
    final tr = Tr.of(tester.element(find.byType(OcptBudgetSharing)));
    expect(find.text("Takings received"), findsNothing);
    expect(find.text("+ Taking"), findsNothing);
    expect(find.byType(Card), findsNWidgets(2));
    expect(find.text(tr.budgetSharingRepayingTitle), findsOneWidget);
    expect(find.text(tr.budgetSharingDistributionTitle), findsOneWidget);
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

  testWidgets("clicking a share row selects it, and only that", (tester) async {
    final share = _share(id: "s1", label: "Regional co-producer");
    String? selected;

    await pumpView(tester, shares: [share], onShareSelected: (id) => selected = id);

    await tester.tap(find.text("Regional co-producer"));

    expect(selected, "s1");
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

  testWidgets("the repayment card shows a muted hint while no resource is reimbursable", (tester) async {
    await pumpView(tester);

    final tr = Tr.of(tester.element(find.byType(OcptBudgetSharing)));
    expect(find.text(tr.budgetSharingRepaymentEmptyHint), findsOneWidget);
    expect(find.text(tr.budgetSharingRepaymentColumnLender.toUpperCase()), findsNothing);
  });

  testWidgets("the contributions card details who put in what, and what is owed", (tester) async {
    await pumpView(
      tester,
      repaymentLines: const [
        OcptBudgetRepaymentLine(
          personId: "p1",
          label: "Avance Marie",
          contributedCents: 50000,
          reimbursableCents: 30000,
          repaid: OcptBudgetCoveredTotal(amountCents: 10000, coveredLineCount: 1, lineCount: 1),
        ),
      ],
      people: [_person(id: "p1", firstName: "Marie", lastName: "Dupont")],
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetSharing)));
    expect(find.text(tr.budgetSharingRepaymentColumnLender.toUpperCase()), findsOneWidget);
    expect(find.text("Marie Dupont"), findsOneWidget);
    // What she put in, how much of it has to come back, what has gone back, what is still owed.
    expect(find.text(ocptBudgetAmountLabel(50000, "EUR")), findsOneWidget);
    expect(find.text(ocptBudgetAmountLabel(30000, "EUR")), findsOneWidget);
    expect(find.text(ocptBudgetAmountLabel(10000, "EUR")), findsOneWidget);
    expect(find.text(ocptBudgetAmountLabel(20000, "EUR")), findsOneWidget);
  });

  testWidgets("a gift reads a dash where a debt would be, and offers no repayment", (tester) async {
    await pumpView(
      tester,
      repaymentLines: const [
        OcptBudgetRepaymentLine(
          personId: null,
          label: "Caméra prêtée",
          contributedCents: 150000,
          reimbursableCents: 0,
          repaid: OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
        ),
      ],
      onRepaymentRequested: (_) {},
    );

    expect(find.text(ocptBudgetAmountLabel(150000, "EUR")), findsOneWidget);
    // Nothing is owed against a gift, which is not the same fact as a debt that came to zero.
    expect(find.text(ocptBudgetEmptyValue), findsWidgets);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });

  testWidgets("a contributor who also holds a share says so under their name", (tester) async {
    await pumpView(
      tester,
      repaymentLines: const [
        OcptBudgetRepaymentLine(
          personId: "p1",
          label: "Avance Marie",
          contributedCents: 30000,
          reimbursableCents: 30000,
          repaid: OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
        ),
      ],
      people: [_person(id: "p1", firstName: "Marie", lastName: "Dupont")],
      shares: [_share(id: "s1", personId: "p1", label: "Marie", sharePermille: 150)],
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetSharing)));
    expect(
      find.text(tr.budgetSharingRepaymentShareCaption(ocptBudgetSharePercentLabel(150))),
      findsOneWidget,
    );
  });

  testWidgets("Record a repayment reports the line it was asked on", (tester) async {
    OcptBudgetRepaymentLine? reported;
    await pumpView(
      tester,
      repaymentLines: const [
        OcptBudgetRepaymentLine(
          personId: "p1",
          label: "Avance Marie",
          contributedCents: 30000,
          reimbursableCents: 30000,
          repaid: OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
        ),
      ],
      people: [_person(id: "p1", firstName: "Marie", lastName: "Dupont")],
      onRepaymentRequested: (line) => reported = line,
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetSharing)));
    await tester.ensureVisible(find.byType(PopupMenuButton<String>).first);
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr.budgetSharingRepaymentRecordAction));
    await tester.pumpAndSettle();

    expect(reported?.personId, "p1");
  });

  testWidgets("a lender naming nobody prints its own label instead", (tester) async {
    await pumpView(
      tester,
      repaymentLines: const [
        OcptBudgetRepaymentLine(
          personId: null,
          label: "Région Île-de-France",
          contributedCents: 5000,
          reimbursableCents: 5000,
          repaid: OcptBudgetCoveredTotal(amountCents: 0, coveredLineCount: 0, lineCount: 0),
        ),
      ],
    );

    expect(find.text("Région Île-de-France"), findsOneWidget);
  });

  testWidgets("every writing affordance is withheld under a read-only preview", (tester) async {
    final share = _share(id: "s1", label: "Regional co-producer");

    await pumpView(tester, shares: [share], isReadOnly: true);

    final tr = Tr.of(tester.element(find.byType(OcptBudgetSharing)));
    expect(find.text(tr.budgetSharingShareCreationAction), findsNothing);
    // No menu at all: every one of its own entries would be withheld.
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });
}

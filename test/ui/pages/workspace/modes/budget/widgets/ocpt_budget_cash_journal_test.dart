// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a wide, tall
/// enough band that the whole table is drawn with no scroll needed to find a cell.
Widget _wrap(Widget child, {double width = 1400}) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: width, height: 700, child: child)),
);

/// A minimal poste, everything but [id]/[label] neutral.
OcptBudgetPoste _poste({required String id, required String label}) =>
    OcptBudgetPoste(id: id, code: "1", label: label, simpleLabel: null, estimateToCompleteCents: null, sortKey: "a0", lines: const []);

/// A minimal journal entry, everything but what each test actually varies neutral.
OcptBudgetEntry _entry({
  required String id,
  required DateTime date,
  String label = "Camera rental",
  String? posteId,
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
  posteId: posteId,
  debitCents: debitCents,
  creditCents: creditCents,
  isTaxInclusive: isTaxInclusive,
  vatRateBasisPoints: vatRateBasisPoints,
  voucherNumber: voucherNumber,
  sortKey: sortKey,
  resourceId: null,
  revenueId: null,
  shareId: null,
);

/// A minimal commitment, everything but what each test actually varies neutral.
OcptBudgetCommitment _commitment({
  required String id,
  DateTime? dueDate,
  String label = "Camera rental — balance",
  String posteId = "poste-1",
  int amountCents = 1000,
  bool isTaxInclusive = true,
  int? vatRateBasisPoints,
  OcptBudgetCommitmentStatus status = OcptBudgetCommitmentStatus.quoteAccepted,
  String? settledEntryId,
  String? lineId,
  String sortKey = "a0",
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
  settledEntryId: settledEntryId,
  lineId: lineId,
  sortKey: sortKey,
);

/// A minimal voucher naming [path], everything else neutral.
OcptAssetRef _receipt({String id = "asset-1", required String path}) => OcptAssetRef(
  id: id,
  kind: OcptAssetKind.receipt,
  path: path,
  label: "",
  addedAt: DateTime(2026),
  personId: null,
  locationId: null,
  elementId: null,
  budgetEntryId: "e1",
  validFrom: null,
  validUntil: null,
);

void main() {
  testWidgets("the table scrolls sideways rather than overflowing a narrow centre", (tester) async {
    // 760 logical pixels is roughly what the centre is left with on a laptop screen once the right
    // dock is open, and it is under the sum of the table's own fixed columns: the `Label` column,
    // the only flexible one, used to be driven to nothing and the row overflowed.
    final entries = [_entry(id: "e1", date: DateTime(2026, 3, 2), debitCents: 11000)];

    await tester.pumpWidget(
      _wrap(
        OcptBudgetCashJournal(
          entries: entries,
          postes: const [],
          receiptsByEntryId: const {},
          commitments: const [],
          onCommitmentSelected: (_) {},
          selection: null,
          isSimplified: false,
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
          isReadOnly: false,
          onEntrySelected: (_) {},
          onEntryEditRequested: (_) {},
          onEntryDeletionRequested: (_) {},
        ),
        width: 760,
      ),
    );

    // No overflow was reported, the table is laid out at its own floor rather than at the width it
    // was given, and the entry is still drawn — nothing is dropped, it is scrolled to.
    expect(tester.takeException(), isNull);

    final horizontalScroll = find.byWidgetPredicate(
      (widget) => widget is SingleChildScrollView && widget.scrollDirection == Axis.horizontal,
    );
    expect(horizontalScroll, findsOneWidget);
    expect(
      tester.getSize(find.descendant(of: horizontalScroll, matching: find.byType(Column)).first).width,
      960,
    );
    expect(find.text("Camera rental"), findsOneWidget);
  });

  testWidgets("a project with no entry at all shows the shared empty state", (tester) async {
    await tester.pumpWidget(
      _wrap(
        OcptBudgetCashJournal(
          entries: const [],
          postes: const [],
          receiptsByEntryId: const {},
          commitments: const [],
          onCommitmentSelected: (_) {},
          selection: null,
          isSimplified: false,
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
          isReadOnly: false,
          onEntrySelected: (_) {},
          onEntryEditRequested: (_) {},
          onEntryDeletionRequested: (_) {},
        ),
      ),
    );

    expect(find.byType(OcptWorkspaceEmptyMode), findsOneWidget);
  });

  testWidgets("the empty journal drops the trade word under the simplified switch", (tester) async {
    await tester.pumpWidget(
      _wrap(
        OcptBudgetCashJournal(
          entries: const [],
          postes: const [],
          receiptsByEntryId: const {},
          commitments: const [],
          onCommitmentSelected: (_) {},
          selection: null,
          isSimplified: true,
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
          isReadOnly: false,
          onEntrySelected: (_) {},
          onEntryEditRequested: (_) {},
          onEntryDeletionRequested: (_) {},
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetCashJournal)));
    expect(find.text(tr.budgetCashJournalSimpleEmptyHint), findsOneWidget);
    expect(find.text(tr.budgetCashJournalEmptyHint), findsNothing);
  });

  testWidgets(
    "the running balance is the whole journal's, never reset at a poste's own boundary",
    (tester) async {
      // A poste-2 credit lands first, so poste-1's own two debits fall from +10000 rather than
      // from zero — the figure a balance wrongly reset at every poste's own boundary would show
      // instead. This page honours no poste filter of its own any more, but the two postes still
      // prove the balance is one column read top to bottom, not one per poste.
      final entries = [
        _entry(id: "e1", date: DateTime(2026), posteId: "poste-2", creditCents: 10000),
        _entry(id: "e2", date: DateTime(2026, 1, 2), posteId: "poste-1", debitCents: 4000),
        _entry(id: "e3", date: DateTime(2026, 1, 3), posteId: "poste-1", debitCents: 1000),
      ];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCashJournal(
            entries: entries,
            postes: [_poste(id: "poste-1", label: "Camera"), _poste(id: "poste-2", label: "Grant")],
            receiptsByEntryId: const {},
            commitments: const [],
            onCommitmentSelected: (_) {},
          selection: null,
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: false,
            onEntrySelected: (_) {},
          onEntryEditRequested: (_) {},
            onEntryDeletionRequested: (_) {},
          ),
        ),
      );

      expect(find.text(ocptBudgetAmountLabel(6000, "EUR")), findsWidgets);
      expect(find.text(ocptBudgetAmountLabel(5000, "EUR")), findsWidgets);
      // Neither poste-1 row is poisoned into starting over from zero: a balance reset at the
      // poste boundary would go negative from the very first one.
      expect(find.text(ocptBudgetAmountLabel(-4000, "EUR")), findsNothing);
      expect(find.text(ocptBudgetAmountLabel(-5000, "EUR")), findsNothing);
    },
  );

  testWidgets(
    "an entry that cannot be read tax-inclusive prints the em dash without breaking the rows "
    "below it",
    (tester) async {
      final entries = [
        _entry(id: "e1", date: DateTime(2026), debitCents: 2000),
        _entry(
          id: "e2",
          date: DateTime(2026, 1, 2),
          debitCents: 1000,
          isTaxInclusive: false,
        ),
        _entry(id: "e3", date: DateTime(2026, 1, 3), debitCents: 500),
      ];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCashJournal(
            entries: entries,
            postes: const [],
            receiptsByEntryId: const {},
            commitments: const [],
            onCommitmentSelected: (_) {},
          selection: null,
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: false,
            onEntrySelected: (_) {},
          onEntryEditRequested: (_) {},
            onEntryDeletionRequested: (_) {},
          ),
        ),
      );

      // The unreadable row's own debit and balance cells both print the em dash.
      expect(find.text(ocptBudgetEmptyValue), findsWidgets);
      // The row below it keeps counting from the balance the journal actually stood at
      // (-2000), not from a poisoned figure: -2000 - 500 = -2500.
      expect(find.text(ocptBudgetAmountLabel(-2500, "EUR")), findsWidgets);
    },
  );

  testWidgets("a debit row reads in the accent error colour", (tester) async {
    final entries = [_entry(id: "e1", date: DateTime(2026), debitCents: 1200)];

    await tester.pumpWidget(
      _wrap(
        OcptBudgetCashJournal(
          entries: entries,
          postes: const [],
          receiptsByEntryId: const {},
          commitments: const [],
          onCommitmentSelected: (_) {},
          selection: null,
          isSimplified: false,
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
          isReadOnly: false,
          onEntrySelected: (_) {},
          onEntryEditRequested: (_) {},
          onEntryDeletionRequested: (_) {},
        ),
      ),
    );

    final theme = Theme.of(tester.element(find.byType(OcptBudgetCashJournal)));
    // The amount also appears, uncoloured, in the top band's own whole-journal `Debit` figure: the
    // row's own cell is the last match in build order.
    final debitText = tester.widgetList<Text>(find.text(ocptBudgetAmountLabel(1200, "EUR"))).last;

    expect(debitText.style?.color, theme.colorScheme.error);
  });

  testWidgets(
    "a credit naming no poste, resource or revenue draws as an ordinary row, reachable like any "
    "other entry",
    (tester) async {
      // The regression case defect 1 leaves behind if this ever narrows again: a movement naming
      // nothing has exactly one place it can be reached from, and this is it.
      tester.view.physicalSize = const Size(1400, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      OcptBudgetEntry? edited;
      String? deletedId;
      String? selectedId;
      final entries = [
        _entry(id: "e1", date: DateTime(2026), debitCents: 1200),
        _entry(id: "e2", date: DateTime(2026, 1, 2), label: "Grant instalment", creditCents: 800),
      ];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCashJournal(
            entries: entries,
            postes: const [],
            receiptsByEntryId: const {},
            commitments: const [],
            onCommitmentSelected: (_) {},
            selection: null,
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: false,
            onEntrySelected: (entryId) => selectedId = entryId,
            onEntryEditRequested: (entry) => edited = entry,
            onEntryDeletionRequested: (entryId) => deletedId = entryId,
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCashJournal)));

      // The credit's own label reaches an ordinary row, its `Poste` cell reading the very same
      // wording a poste-less debit already reads.
      expect(find.text("Grant instalment"), findsOneWidget);
      expect(find.text(tr.budgetCashJournalNoPosteLabel), findsNWidgets(2));
      // Its amount is drawn in the `Credit` column — the amount also totals into the top band's
      // own whole-journal figure, hence the two matches.
      expect(find.text(ocptBudgetAmountLabel(800, "EUR")), findsNWidgets(2));

      // It selects like any other row.
      await tester.tap(find.text("Grant instalment"));
      await tester.pumpAndSettle();
      expect(selectedId, "e2");

      // It carries the very same `⋮` menu every other row does — `Edit` and `Delete`, each
      // dispatching this entry's own id.
      final menus = find.byType(PopupMenuButton<String>);
      expect(menus, findsNWidgets(2));

      await tester.tap(menus.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.budgetFinancingEditAction));
      await tester.pumpAndSettle();
      expect(edited?.id, "e2");

      await tester.tap(menus.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.budgetEntryDeleteAction));
      await tester.pumpAndSettle();
      expect(deletedId, "e2");
    },
  );

  testWidgets("an entry naming no poste reads as such rather than leaving the cell empty", (
    tester,
  ) async {
    final entries = [
      _entry(id: "e1", date: DateTime(2026), debitCents: 1000),
    ];

    await tester.pumpWidget(
      _wrap(
        OcptBudgetCashJournal(
          entries: entries,
          postes: const [],
          receiptsByEntryId: const {},
          commitments: const [],
          onCommitmentSelected: (_) {},
          selection: null,
          isSimplified: false,
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
          isReadOnly: false,
          onEntrySelected: (_) {},
          onEntryEditRequested: (_) {},
          onEntryDeletionRequested: (_) {},
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetCashJournal)));
    expect(find.text(tr.budgetCashJournalNoPosteLabel), findsOneWidget);
  });

  testWidgets("the coverage read-out appears while an entry carries no known rate, and disappears "
      "once every entry does", (tester) async {
    final entries = [
      _entry(id: "e1", date: DateTime(2026), debitCents: 1000),
      _entry(
        id: "e2",
        date: DateTime(2026, 1, 2),
        debitCents: 500,
        isTaxInclusive: false,
      ),
    ];

    await tester.pumpWidget(
      _wrap(
        OcptBudgetCashJournal(
          entries: entries,
          postes: const [],
          receiptsByEntryId: const {},
          commitments: const [],
          onCommitmentSelected: (_) {},
          selection: null,
          isSimplified: false,
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
          isReadOnly: false,
          onEntrySelected: (_) {},
          onEntryEditRequested: (_) {},
          onEntryDeletionRequested: (_) {},
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetCashJournal)));
    expect(find.text(tr.budgetCashJournalCoverageReadOut(1, 2)), findsOneWidget);

    // Give the second entry a known rate: every entry now covers, and the read-out goes away.
    await tester.pumpWidget(
      _wrap(
        OcptBudgetCashJournal(
          entries: [
            entries[0],
            _entry(
              id: "e2",
              date: DateTime(2026, 1, 2),
              debitCents: 500,
              isTaxInclusive: false,
              vatRateBasisPoints: 2000,
            ),
          ],
          postes: const [],
          receiptsByEntryId: const {},
          commitments: const [],
          onCommitmentSelected: (_) {},
          selection: null,
          isSimplified: false,
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
          isReadOnly: false,
          onEntrySelected: (_) {},
          onEntryEditRequested: (_) {},
          onEntryDeletionRequested: (_) {},
        ),
      ),
    );

    expect(find.text(tr.budgetCashJournalCoverageReadOut(1, 2)), findsNothing);
  });

  testWidgets(
    "withholds every writing affordance under a previewed version, but still selects",
    (tester) async {
      var written = false;
      var selected = false;
      final entries = [
        _entry(id: "e1", date: DateTime(2026), posteId: "poste-1", debitCents: 1000),
      ];
      final postes = [_poste(id: "poste-1", label: "Camera")];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCashJournal(
            entries: entries,
            postes: postes,
            receiptsByEntryId: const {},
            commitments: const [],
            onCommitmentSelected: (_) {},
            selection: null,
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: true,
            onEntrySelected: (_) => selected = true,
            onEntryEditRequested: (_) => written = true,
            onEntryDeletionRequested: (_) => written = true,
          ),
        ),
      );

      // The row's own `⋮` menu (Edit/Delete) is withheld whole rather than offered with nothing
      // left in it — this page carries no capture affordance of its own to withhold either way.
      expect(find.byType(PopupMenuButton<String>), findsNothing);

      // A row's own click never writes — it only selects, opening the right dock's fiche on it —
      // so it is never withheld under a previewed version.
      await tester.tap(find.text(entries.first.label));
      await tester.pumpAndSettle();
      expect(selected, isTrue);
      expect(written, isFalse);
    },
  );

  group("selecting a row and its own menu", () {
    testWidgets("clicking a row selects it, dispatching its own id", (tester) async {
      String? selectedId;
      final entries = [_entry(id: "e1", date: DateTime(2026), debitCents: 1000)];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCashJournal(
            entries: entries,
            postes: const [],
            receiptsByEntryId: const {},
            commitments: const [],
            onCommitmentSelected: (_) {},
            selection: null,
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: false,
            onEntrySelected: (entryId) => selectedId = entryId,
            onEntryEditRequested: (_) {},
            onEntryDeletionRequested: (_) {},
          ),
        ),
      );

      await tester.tap(find.text(entries.first.label));
      await tester.pumpAndSettle();

      expect(selectedId, "e1");
    });

    testWidgets("the row's own menu offers Edit and Delete, each dispatching in its own way", (
      tester,
    ) async {
      // Wide enough that the row's own trailing `⋮` menu sits inside the default 800×600 test
      // surface: the row's menu column is its very last one, past the date, voucher, poste,
      // label, debit and balance columns the [_wrap] default width already draws in full.
      tester.view.physicalSize = const Size(1400, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      OcptBudgetEntry? edited;
      String? deletedId;
      final entries = [_entry(id: "e1", date: DateTime(2026), debitCents: 1000)];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCashJournal(
            entries: entries,
            postes: const [],
            receiptsByEntryId: const {},
            commitments: const [],
            onCommitmentSelected: (_) {},
            selection: null,
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: false,
            onEntrySelected: (_) {},
            onEntryEditRequested: (entry) => edited = entry,
            onEntryDeletionRequested: (entryId) => deletedId = entryId,
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCashJournal)));
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.budgetFinancingEditAction));
      await tester.pumpAndSettle();

      expect(edited?.id, "e1");
      expect(deletedId, isNull);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tr.budgetEntryDeleteAction));
      await tester.pumpAndSettle();

      expect(deletedId, "e1");
    });

    testWidgets("a selected row's entry reads highlighted", (tester) async {
      final entries = [_entry(id: "e1", date: DateTime(2026), debitCents: 1000)];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCashJournal(
            entries: entries,
            postes: const [],
            receiptsByEntryId: const {},
            commitments: const [],
            onCommitmentSelected: (_) {},
            selection: const OcptBudgetEntrySelection("e1"),
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: false,
            onEntrySelected: (_) {},
            onEntryEditRequested: (_) {},
            onEntryDeletionRequested: (_) {},
          ),
        ),
      );

      final coloredBoxes = tester
          .widgetList<ColoredBox>(find.byType(ColoredBox))
          .where((box) => box.color != Colors.transparent);
      expect(coloredBoxes, isNotEmpty);
    });
  });

  group("an entry's own voucher marker", () {
    testWidgets("an entry with no voucher shows no marker at all", (tester) async {
      final entries = [_entry(id: "e1", date: DateTime(2026), debitCents: 1000)];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCashJournal(
            entries: entries,
            postes: const [],
            receiptsByEntryId: const {},
            commitments: const [],
            onCommitmentSelected: (_) {},
          selection: null,
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: false,
            onEntrySelected: (_) {},
          onEntryEditRequested: (_) {},
            onEntryDeletionRequested: (_) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.attach_file), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets("an entry whose voucher resolves shows the plain marker", (tester) async {
      final tempFile = File(
        "${Directory.systemTemp.path}/ocpt_budget_cash_journal_test_receipt.pdf",
      )..writeAsStringSync("stub");
      addTearDown(tempFile.deleteSync);

      final entries = [_entry(id: "e1", date: DateTime(2026), debitCents: 1000)];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCashJournal(
            entries: entries,
            postes: const [],
            receiptsByEntryId: {"e1": _receipt(path: tempFile.path)},
            commitments: const [],
            onCommitmentSelected: (_) {},
          selection: null,
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: false,
            onEntrySelected: (_) {},
          onEntryEditRequested: (_) {},
            onEntryDeletionRequested: (_) {},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCashJournal)));
      expect(find.byIcon(Icons.attach_file), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);

      await tester.longPress(find.byIcon(Icons.attach_file));
      await tester.pumpAndSettle();
      expect(find.text(tr.budgetCashJournalVoucherAttachedTooltip), findsOneWidget);
    });

    testWidgets("an entry whose voucher file no longer resolves says so", (tester) async {
      final entries = [_entry(id: "e1", date: DateTime(2026), debitCents: 1000)];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCashJournal(
            entries: entries,
            postes: const [],
            receiptsByEntryId: {"e1": _receipt(path: "/nowhere/facture.pdf")},
            commitments: const [],
            onCommitmentSelected: (_) {},
          selection: null,
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: false,
            onEntrySelected: (_) {},
          onEntryEditRequested: (_) {},
            onEntryDeletionRequested: (_) {},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCashJournal)));
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byIcon(Icons.attach_file), findsNothing);

      await tester.longPress(find.byIcon(Icons.error_outline));
      await tester.pumpAndSettle();
      expect(find.text(tr.budgetCashJournalVoucherFileMissingTooltip), findsOneWidget);
    });
  });

  group("the À venir section", () {
    testWidgets("absent while no unsettled commitment exists", (tester) async {
      final entries = [_entry(id: "e1", date: DateTime(2026), debitCents: 1000)];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCashJournal(
            entries: entries,
            postes: const [],
            receiptsByEntryId: const {},
            commitments: const [],
            onCommitmentSelected: (_) {},
            selection: null,
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: false,
            onEntrySelected: (_) {},
            onEntryEditRequested: (_) {},
            onEntryDeletionRequested: (_) {},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCashJournal)));
      expect(find.text(tr.budgetCashUpcomingSectionTitle), findsNothing);
    });

    testWidgets("present once at least one unsettled commitment exists", (tester) async {
      final entries = [_entry(id: "e1", date: DateTime(2026), debitCents: 1000)];
      final commitments = [_commitment(id: "c1", dueDate: DateTime(2026, 9, 5), amountCents: 5000)];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCashJournal(
            entries: entries,
            postes: const [],
            receiptsByEntryId: const {},
            commitments: commitments,
            onCommitmentSelected: (_) {},
            selection: null,
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: false,
            onEntrySelected: (_) {},
            onEntryEditRequested: (_) {},
            onEntryDeletionRequested: (_) {},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCashJournal)));
      expect(find.text(tr.budgetCashUpcomingSectionTitle), findsOneWidget);
    });

    testWidgets("a due row draws its date, label, poste and amount in the Debit column", (
      tester,
    ) async {
      final entries = [_entry(id: "e1", date: DateTime(2026), debitCents: 1000)];
      final postes = [_poste(id: "poste-1", label: "Camera")];
      final commitments = [
        _commitment(id: "c1", dueDate: DateTime(2026, 9, 5), amountCents: 5000),
        // A second, differently-amounted commitment so the footer's own total falling due —
        // which would otherwise coincide with a single row's amount — cannot be mistaken for it.
        _commitment(
          id: "c2",
          dueDate: DateTime(2026, 9, 10),
          posteId: "poste-2",
          label: "Sound gear rental",
          amountCents: 7000,
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCashJournal(
            entries: entries,
            postes: postes,
            receiptsByEntryId: const {},
            commitments: commitments,
            onCommitmentSelected: (_) {},
            selection: null,
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: false,
            onEntrySelected: (_) {},
            onEntryEditRequested: (_) {},
            onEntryDeletionRequested: (_) {},
          ),
        ),
      );

      expect(find.text("Camera rental — balance"), findsOneWidget);
      expect(find.text("Camera"), findsOneWidget);
      expect(find.text(ocptBudgetAmountLabel(5000, "EUR")), findsOneWidget);
    });

    testWidgets("a due commitment with no due date reads the shared no-due-date label", (
      tester,
    ) async {
      final entries = [_entry(id: "e1", date: DateTime(2026), debitCents: 1000)];
      final commitments = [_commitment(id: "c1", amountCents: 5000)];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCashJournal(
            entries: entries,
            postes: const [],
            receiptsByEntryId: const {},
            commitments: commitments,
            onCommitmentSelected: (_) {},
            selection: null,
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: false,
            onEntrySelected: (_) {},
            onEntryEditRequested: (_) {},
            onEntryDeletionRequested: (_) {},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCashJournal)));
      expect(find.text(tr.budgetCommittedNoDueDateLabel), findsOneWidget);
    });

    testWidgets("the footer row draws the total falling due and the projected balance", (
      tester,
    ) async {
      final entries = [_entry(id: "e1", date: DateTime(2026), creditCents: 20000)];
      final commitments = [
        _commitment(id: "c1", dueDate: DateTime(2026, 9, 5), amountCents: 5000),
        _commitment(id: "c2", dueDate: DateTime(2026, 9, 10), amountCents: 3000),
      ];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCashJournal(
            entries: entries,
            postes: const [],
            receiptsByEntryId: const {},
            commitments: commitments,
            onCommitmentSelected: (_) {},
            selection: null,
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: false,
            onEntrySelected: (_) {},
            onEntryEditRequested: (_) {},
            onEntryDeletionRequested: (_) {},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCashJournal)));
      expect(find.text(tr.budgetCashUpcomingProjectedBalanceLabel), findsOneWidget);
      // The journal opens at 20000, and 5000 + 3000 falls due: 12000 left.
      expect(find.text(ocptBudgetAmountLabel(8000, "EUR")), findsOneWidget);
      expect(find.text(ocptBudgetAmountLabel(12000, "EUR")), findsOneWidget);
    });

    testWidgets("the projected balance reads in the error colour once it goes negative", (
      tester,
    ) async {
      final entries = [_entry(id: "e1", date: DateTime(2026), debitCents: 1000)];
      final commitments = [_commitment(id: "c1", dueDate: DateTime(2026, 9, 5), amountCents: 5000)];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCashJournal(
            entries: entries,
            postes: const [],
            receiptsByEntryId: const {},
            commitments: commitments,
            onCommitmentSelected: (_) {},
            selection: null,
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: false,
            onEntrySelected: (_) {},
            onEntryEditRequested: (_) {},
            onEntryDeletionRequested: (_) {},
          ),
        ),
      );

      final theme = Theme.of(tester.element(find.byType(OcptBudgetCashJournal)));
      // The journal opens at -1000, and 5000 falls due: -6000, negative.
      final balanceText = tester.widget<Text>(find.text(ocptBudgetAmountLabel(-6000, "EUR")));
      expect(balanceText.style?.color, theme.colorScheme.error);
    });

    testWidgets(
      "the coverage read-out appears only while a commitment cannot be read tax-inclusive",
      (tester) async {
        final entries = [_entry(id: "e1", date: DateTime(2026), debitCents: 1000)];
        final commitments = [
          _commitment(id: "c1", dueDate: DateTime(2026, 9, 5), amountCents: 5000),
          _commitment(
            id: "c2",
            dueDate: DateTime(2026, 9, 10),
            amountCents: 3000,
            isTaxInclusive: false,
          ),
        ];

        await tester.pumpWidget(
          _wrap(
            OcptBudgetCashJournal(
              entries: entries,
              postes: const [],
              receiptsByEntryId: const {},
              commitments: commitments,
              onCommitmentSelected: (_) {},
              selection: null,
              isSimplified: false,
              defaultVatRateBasisPoints: null,
              currencyCode: "EUR",
              isReadOnly: false,
              onEntrySelected: (_) {},
              onEntryEditRequested: (_) {},
              onEntryDeletionRequested: (_) {},
            ),
          ),
        );

        final tr = Tr.of(tester.element(find.byType(OcptBudgetCashJournal)));
        expect(find.text(tr.budgetCashUpcomingCoverageReadOut(1, 2)), findsOneWidget);

        // Give the second commitment a known rate: every commitment now covers, and the read-out
        // goes away.
        await tester.pumpWidget(
          _wrap(
            OcptBudgetCashJournal(
              entries: entries,
              postes: const [],
              receiptsByEntryId: const {},
              commitments: [
                commitments[0],
                _commitment(
                  id: "c2",
                  dueDate: DateTime(2026, 9, 10),
                  amountCents: 3000,
                  isTaxInclusive: false,
                  vatRateBasisPoints: 2000,
                ),
              ],
              onCommitmentSelected: (_) {},
              selection: null,
              isSimplified: false,
              defaultVatRateBasisPoints: null,
              currencyCode: "EUR",
              isReadOnly: false,
              onEntrySelected: (_) {},
              onEntryEditRequested: (_) {},
              onEntryDeletionRequested: (_) {},
            ),
          ),
        );

        expect(find.text(tr.budgetCashUpcomingCoverageReadOut(1, 2)), findsNothing);
      },
    );

    testWidgets("a row tap reports the commitment's own id", (tester) async {
      String? selectedId;
      final entries = [_entry(id: "e1", date: DateTime(2026), debitCents: 1000)];
      final commitments = [_commitment(id: "c1", dueDate: DateTime(2026, 9, 5), amountCents: 5000)];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCashJournal(
            entries: entries,
            postes: const [],
            receiptsByEntryId: const {},
            commitments: commitments,
            onCommitmentSelected: (commitmentId) => selectedId = commitmentId,
            selection: null,
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: false,
            onEntrySelected: (_) {},
            onEntryEditRequested: (_) {},
            onEntryDeletionRequested: (_) {},
          ),
        ),
      );

      await tester.tap(find.text("Camera rental — balance"));
      await tester.pumpAndSettle();

      expect(selectedId, "c1");
    });

    testWidgets("draws identically under isReadOnly, its rows still selectable", (tester) async {
      String? selectedId;
      final entries = [_entry(id: "e1", date: DateTime(2026), debitCents: 1000)];
      final commitments = [_commitment(id: "c1", dueDate: DateTime(2026, 9, 5), amountCents: 5000)];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCashJournal(
            entries: entries,
            postes: const [],
            receiptsByEntryId: const {},
            commitments: commitments,
            onCommitmentSelected: (commitmentId) => selectedId = commitmentId,
            selection: null,
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: true,
            onEntrySelected: (_) {},
            onEntryEditRequested: (_) {},
            onEntryDeletionRequested: (_) {},
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCashJournal)));
      expect(find.text(tr.budgetCashUpcomingSectionTitle), findsOneWidget);
      expect(find.text("Camera rental — balance"), findsOneWidget);

      await tester.tap(find.text("Camera rental — balance"));
      await tester.pumpAndSettle();

      expect(selectedId, "c1");
    });
  });
}

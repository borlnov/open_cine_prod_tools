// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_selection.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';
import 'ocpt_budget_cash_journal_test_doubles.dart';

/// Run the tests of the budget cash journal table and balance.
void main() {
  testWidgets("the table scrolls sideways rather than overflowing a narrow centre", (tester) async {
    // 760 logical pixels is roughly what the centre is left with on a laptop screen once the right
    // dock is open, and it is under the sum of the table's own fixed columns: the `Label` column,
    // the only flexible one, used to be driven to nothing and the row overflowed.
    final entries = [testEntry(id: "e1", date: DateTime(2026, 3, 2), debitCents: 11000)];

    await tester.pumpWidget(
      wrap(
        OcptBudgetCashJournal(
          shareableCents: 0,
          onOpenSharing: null,
          entries: entries,
          accounts: const [],
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
      tester
          .getSize(find.descendant(of: horizontalScroll, matching: find.byType(Column)).first)
          .width,
      960,
    );
    expect(find.text("Camera rental"), findsOneWidget);
  });

  testWidgets("a project with no entry at all shows the shared empty state", (tester) async {
    await tester.pumpWidget(
      wrap(
        OcptBudgetCashJournal(
          shareableCents: 0,
          onOpenSharing: null,
          entries: const [],
          accounts: const [],
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

  testWidgets("a project owing money before paying any shows what it owes, not the empty state", (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        OcptBudgetCashJournal(
          shareableCents: 0,
          onOpenSharing: null,
          entries: const [],
          accounts: const [],
          receiptsByEntryId: const {},
          commitments: [testCommitment(id: "c1", dueDate: DateTime(2026, 9, 5), amountCents: 5000)],
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
    expect(find.byType(OcptWorkspaceEmptyMode), findsNothing);
    expect(find.text(tr.budgetCashUpcomingSectionTitle), findsOneWidget);
    expect(find.text("Camera rental — balance"), findsOneWidget);
  });

  testWidgets("the empty journal drops the trade word under the simplified switch", (tester) async {
    await tester.pumpWidget(
      wrap(
        OcptBudgetCashJournal(
          shareableCents: 0,
          onOpenSharing: null,
          entries: const [],
          accounts: const [],
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

  group("the shareable reminder under the closing balance", () {
    testWidgets("states the shareable amount and links to sharing while there is one", (
      tester,
    ) async {
      var opened = false;
      await tester.pumpWidget(
        wrap(
          OcptBudgetCashJournal(
            shareableCents: 420000,
            onOpenSharing: () => opened = true,
            entries: [testEntry(id: "e1", date: DateTime(2026, 3, 2), creditCents: 570000)],
            accounts: const [],
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
      expect(
        find.text(tr.budgetCashJournalShareableReminder(ocptBudgetAmountLabel(420000, "EUR"))),
        findsOneWidget,
      );

      // The link switches view rather than writing anything.
      final link = find.byKey(const Key("ocptBudgetCashShareableReminderLink"));
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();
      expect(opened, isTrue);
    });

    testWidgets("is withheld whole while there is nothing to share", (tester) async {
      await tester.pumpWidget(
        wrap(
          OcptBudgetCashJournal(
            shareableCents: 0,
            onOpenSharing: () {},
            entries: [testEntry(id: "e1", date: DateTime(2026, 3, 2), debitCents: 11000)],
            accounts: const [],
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

      expect(find.byKey(const Key("ocptBudgetCashShareableReminderLink")), findsNothing);
    });
  });

  testWidgets("the running balance is the whole journal's, never reset at a poste's own boundary", (
    tester,
  ) async {
    // An account-2 credit lands first, so account-1's own two debits fall from +10000 rather than
    // from zero — the figure a balance wrongly reset at every account's own boundary would show
    // instead. This page honours no account filter of its own any more, but the two accounts still
    // prove the balance is one column read top to bottom, not one per account.
    final entries = [
      testEntry(id: "e1", date: DateTime(2026), accountId: "poste-2", creditCents: 10000),
      testEntry(id: "e2", date: DateTime(2026, 1, 2), accountId: "poste-1", debitCents: 4000),
      testEntry(id: "e3", date: DateTime(2026, 1, 3), accountId: "poste-1", debitCents: 1000),
    ];

    await tester.pumpWidget(
      wrap(
        OcptBudgetCashJournal(
          shareableCents: 0,
          onOpenSharing: null,
          entries: entries,
          accounts: [
            testAccount(id: "poste-1", label: "Camera"),
            testAccount(id: "poste-2", label: "Grant"),
          ],
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
    // Neither account-1 row is poisoned into starting over from zero: a balance reset at the
    // account boundary would go negative from the very first one.
    expect(find.text(ocptBudgetAmountLabel(-4000, "EUR")), findsNothing);
    expect(find.text(ocptBudgetAmountLabel(-5000, "EUR")), findsNothing);
  });

  testWidgets(
    "an entry that cannot be read tax-inclusive prints the em dash without breaking the rows "
    "below it",
    (tester) async {
      final entries = [
        testEntry(id: "e1", date: DateTime(2026), debitCents: 2000),
        testEntry(id: "e2", date: DateTime(2026, 1, 2), debitCents: 1000, isTaxInclusive: false),
        testEntry(id: "e3", date: DateTime(2026, 1, 3), debitCents: 500),
      ];

      await tester.pumpWidget(
        wrap(
          OcptBudgetCashJournal(
            shareableCents: 0,
            onOpenSharing: null,
            entries: entries,
            accounts: const [],
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
    final entries = [testEntry(id: "e1", date: DateTime(2026), debitCents: 1200)];

    await tester.pumpWidget(
      wrap(
        OcptBudgetCashJournal(
          shareableCents: 0,
          onOpenSharing: null,
          entries: entries,
          accounts: const [],
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
        testEntry(id: "e1", date: DateTime(2026), debitCents: 1200),
        testEntry(
          id: "e2",
          date: DateTime(2026, 1, 2),
          label: "Grant instalment",
          creditCents: 800,
        ),
      ];

      await tester.pumpWidget(
        wrap(
          OcptBudgetCashJournal(
            shareableCents: 0,
            onOpenSharing: null,
            entries: entries,
            accounts: const [],
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
      // wording an account-less debit already reads.
      expect(find.text("Grant instalment"), findsOneWidget);
      expect(find.text(tr.budgetCashJournalNoAccountLabel), findsNWidgets(2));
      // Its amount is drawn in the `Credit` column, once: the statement's closing row states the
      // balance alone, so a credit's own figure is printed nowhere but on its own row.
      expect(find.text(ocptBudgetAmountLabel(800, "EUR")), findsOneWidget);

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
    final entries = [testEntry(id: "e1", date: DateTime(2026), debitCents: 1000)];

    await tester.pumpWidget(
      wrap(
        OcptBudgetCashJournal(
          shareableCents: 0,
          onOpenSharing: null,
          entries: entries,
          accounts: const [],
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
    expect(find.text(tr.budgetCashJournalNoAccountLabel), findsOneWidget);
  });

  testWidgets("the coverage read-out appears while an entry carries no known rate, and disappears "
      "once every entry does", (tester) async {
    final entries = [
      testEntry(id: "e1", date: DateTime(2026), debitCents: 1000),
      testEntry(id: "e2", date: DateTime(2026, 1, 2), debitCents: 500, isTaxInclusive: false),
    ];

    await tester.pumpWidget(
      wrap(
        OcptBudgetCashJournal(
          shareableCents: 0,
          onOpenSharing: null,
          entries: entries,
          accounts: const [],
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
      wrap(
        OcptBudgetCashJournal(
          shareableCents: 0,
          onOpenSharing: null,
          entries: [
            entries[0],
            testEntry(
              id: "e2",
              date: DateTime(2026, 1, 2),
              debitCents: 500,
              isTaxInclusive: false,
              vatRateBasisPoints: 2000,
            ),
          ],
          accounts: const [],
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

  testWidgets("withholds every writing affordance under a previewed version, but still selects", (
    tester,
  ) async {
    var written = false;
    var selected = false;
    final entries = [
      testEntry(id: "e1", date: DateTime(2026), accountId: "poste-1", debitCents: 1000),
    ];
    final accounts = [testAccount(id: "poste-1", label: "Camera")];

    await tester.pumpWidget(
      wrap(
        OcptBudgetCashJournal(
          shareableCents: 0,
          onOpenSharing: null,
          entries: entries,
          accounts: accounts,
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

    // A row's own click never writes — it only selects, opening the right dock's detail panel on it
    // — so it is never withheld under a previewed version.
    await tester.tap(find.text(entries.first.label));
    await tester.pumpAndSettle();
    expect(selected, isTrue);
    expect(written, isFalse);
  });

  group("selecting a row and its own menu", () {
    testWidgets("clicking a row selects it, dispatching its own id", (tester) async {
      String? selectedId;
      final entries = [testEntry(id: "e1", date: DateTime(2026), debitCents: 1000)];

      await tester.pumpWidget(
        wrap(
          OcptBudgetCashJournal(
            shareableCents: 0,
            onOpenSharing: null,
            entries: entries,
            accounts: const [],
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
      // surface: the row's menu column is its very last one, past the date, voucher, account,
      // label, debit and balance columns the [wrap] default width already draws in full.
      tester.view.physicalSize = const Size(1400, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      OcptBudgetEntry? edited;
      String? deletedId;
      final entries = [testEntry(id: "e1", date: DateTime(2026), debitCents: 1000)];

      await tester.pumpWidget(
        wrap(
          OcptBudgetCashJournal(
            shareableCents: 0,
            onOpenSharing: null,
            entries: entries,
            accounts: const [],
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
      final entries = [testEntry(id: "e1", date: DateTime(2026), debitCents: 1000)];

      await tester.pumpWidget(
        wrap(
          OcptBudgetCashJournal(
            shareableCents: 0,
            onOpenSharing: null,
            entries: entries,
            accounts: const [],
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
}

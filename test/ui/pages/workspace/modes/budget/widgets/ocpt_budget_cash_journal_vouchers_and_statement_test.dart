// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';
import 'ocpt_budget_cash_journal_test_doubles.dart';

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

/// Run the tests of the budget cash journal vouchers and statement.
void main() {
  group("an entry's own voucher marker", () {
    testWidgets("an entry with no voucher shows no marker at all", (tester) async {
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

      expect(find.byIcon(Icons.attach_file), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets("an entry whose voucher resolves shows the plain marker", (tester) async {
      final tempFile = File(
        "${Directory.systemTemp.path}/ocpt_budget_cash_journal_test_receipt.pdf",
      )..writeAsStringSync("stub");
      addTearDown(tempFile.deleteSync);

      final entries = [testEntry(id: "e1", date: DateTime(2026), debitCents: 1000)];

      await tester.pumpWidget(
        wrap(
          OcptBudgetCashJournal(
            shareableCents: 0,
            onOpenSharing: null,
            entries: entries,
            accounts: const [],
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
      final entries = [testEntry(id: "e1", date: DateTime(2026), debitCents: 1000)];

      await tester.pumpWidget(
        wrap(
          OcptBudgetCashJournal(
            shareableCents: 0,
            onOpenSharing: null,
            entries: entries,
            accounts: const [],
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
      expect(find.text(tr.budgetCashUpcomingSectionTitle), findsNothing);
    });

    testWidgets("present once at least one unsettled commitment exists", (tester) async {
      final entries = [testEntry(id: "e1", date: DateTime(2026), debitCents: 1000)];
      final commitments = [
        testCommitment(id: "c1", dueDate: DateTime(2026, 9, 5), amountCents: 5000),
      ];

      await tester.pumpWidget(
        wrap(
          OcptBudgetCashJournal(
            shareableCents: 0,
            onOpenSharing: null,
            entries: entries,
            accounts: const [],
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
      final entries = [testEntry(id: "e1", date: DateTime(2026), debitCents: 1000)];
      final accounts = [testAccount(id: "poste-1", label: "Camera")];
      final commitments = [
        testCommitment(id: "c1", dueDate: DateTime(2026, 9, 5), amountCents: 5000),
        // A second, differently-amounted commitment so the footer's own total falling due —
        // which would otherwise coincide with a single row's amount — cannot be mistaken for it.
        testCommitment(
          id: "c2",
          dueDate: DateTime(2026, 9, 10),
          accountId: "poste-2",
          label: "Sound gear rental",
          amountCents: 7000,
        ),
      ];

      await tester.pumpWidget(
        wrap(
          OcptBudgetCashJournal(
            shareableCents: 0,
            onOpenSharing: null,
            entries: entries,
            accounts: accounts,
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
      final entries = [testEntry(id: "e1", date: DateTime(2026), debitCents: 1000)];
      final commitments = [testCommitment(id: "c1", amountCents: 5000)];

      await tester.pumpWidget(
        wrap(
          OcptBudgetCashJournal(
            shareableCents: 0,
            onOpenSharing: null,
            entries: entries,
            accounts: const [],
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
      final entries = [testEntry(id: "e1", date: DateTime(2026), creditCents: 20000)];
      final commitments = [
        testCommitment(id: "c1", dueDate: DateTime(2026, 9, 5), amountCents: 5000),
        testCommitment(id: "c2", dueDate: DateTime(2026, 9, 10), amountCents: 3000),
      ];

      await tester.pumpWidget(
        wrap(
          OcptBudgetCashJournal(
            shareableCents: 0,
            onOpenSharing: null,
            entries: entries,
            accounts: const [],
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
      final entries = [testEntry(id: "e1", date: DateTime(2026), debitCents: 1000)];
      final commitments = [
        testCommitment(id: "c1", dueDate: DateTime(2026, 9, 5), amountCents: 5000),
      ];

      await tester.pumpWidget(
        wrap(
          OcptBudgetCashJournal(
            shareableCents: 0,
            onOpenSharing: null,
            entries: entries,
            accounts: const [],
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
        final entries = [testEntry(id: "e1", date: DateTime(2026), debitCents: 1000)];
        final commitments = [
          testCommitment(id: "c1", dueDate: DateTime(2026, 9, 5), amountCents: 5000),
          testCommitment(
            id: "c2",
            dueDate: DateTime(2026, 9, 10),
            amountCents: 3000,
            isTaxInclusive: false,
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
          wrap(
            OcptBudgetCashJournal(
              shareableCents: 0,
              onOpenSharing: null,
              entries: entries,
              accounts: const [],
              receiptsByEntryId: const {},
              commitments: [
                commitments[0],
                testCommitment(
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
      final entries = [testEntry(id: "e1", date: DateTime(2026), debitCents: 1000)];
      final commitments = [
        testCommitment(id: "c1", dueDate: DateTime(2026, 9, 5), amountCents: 5000),
      ];

      await tester.pumpWidget(
        wrap(
          OcptBudgetCashJournal(
            shareableCents: 0,
            onOpenSharing: null,
            entries: entries,
            accounts: const [],
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
      final entries = [testEntry(id: "e1", date: DateTime(2026), debitCents: 1000)];
      final commitments = [
        testCommitment(id: "c1", dueDate: DateTime(2026, 9, 5), amountCents: 5000),
      ];

      await tester.pumpWidget(
        wrap(
          OcptBudgetCashJournal(
            shareableCents: 0,
            onOpenSharing: null,
            entries: entries,
            accounts: const [],
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

  group("the statement's own closing row", () {
    testWidgets("closes on the last entry's date, and states the balance alone", (tester) async {
      final entries = [
        testEntry(
          id: "e1",
          date: DateTime(2026, 1, 4),
          label: "Grant instalment",
          creditCents: 800000,
        ),
        testEntry(
          id: "e2",
          date: DateTime(2026, 2, 23),
          label: "Camera deposit",
          debitCents: 120000,
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
            onEntrySelected: (_) {},
            onEntryEditRequested: (_) {},
            onEntryDeletionRequested: (_) {},
          ),
        ),
      );

      final context = tester.element(find.byType(OcptBudgetCashJournal));
      final tr = Tr.of(context);
      final closingDate = DateFormat.yMMMd(
        Localizations.localeOf(context).toString(),
      ).format(DateTime(2026, 2, 23));

      // The statement closes on its last movement, never on today.
      expect(find.text(tr.budgetCashJournalClosingBalanceLabel(closingDate)), findsOneWidget);

      // And it states the balance alone: the debit and credit totals the top band used to carry
      // are gone, so each entry's own figure is printed once, on its own row.
      // The closing balance is printed twice — once as the last row's own running balance, once
      // under the closing label — and every other figure exactly once, on the row that moved it.
      expect(find.text(ocptBudgetAmountLabel(680000, "EUR")), findsNWidgets(2));
      // The opening credit reads twice too, in its own `Credit` cell and as the running balance it
      // opened the account at.
      expect(find.text(ocptBudgetAmountLabel(800000, "EUR")), findsNWidgets(2));
      expect(find.text(ocptBudgetAmountLabel(120000, "EUR")), findsOneWidget);
    });

    testWidgets("a project owing money before paying any closes no statement", (tester) async {
      await tester.pumpWidget(
        wrap(
          OcptBudgetCashJournal(
            shareableCents: 0,
            onOpenSharing: null,
            entries: const [],
            accounts: const [],
            receiptsByEntryId: const {},
            commitments: [
              testCommitment(id: "c1", dueDate: DateTime(2026, 3, 10), amountCents: 50000),
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

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCashJournal)));

      // `À venir` is drawn, but nothing closes a statement with no movement in it — a closing row
      // would have no date to close on.
      expect(find.text(tr.budgetCashUpcomingSectionTitle), findsOneWidget);
      expect(find.textContaining(tr.budgetCashJournalClosingBalanceLabel("")), findsNothing);
    });
  });
}

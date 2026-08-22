// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_asset_ref.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/types/ocpt_asset_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_cash_journal.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a wide, tall
/// enough band that the whole table is drawn with no scroll needed to find a cell.
Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 1400, height: 700, child: child)),
);

/// A minimal poste, everything but [id]/[label] neutral.
OcptBudgetPoste _poste({required String id, required String label}) =>
    OcptBudgetPoste(id: id, code: "1", label: label, simpleLabel: null, sortKey: "a0", lines: const []);

/// A minimal journal entry, everything but what each test actually varies neutral.
OcptBudgetEntry _entry({
  required String id,
  required DateTime date,
  String label = "Entry",
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
  testWidgets("a project with no entry at all shows the shared empty state", (tester) async {
    await tester.pumpWidget(
      _wrap(
        OcptBudgetCashJournal(
          entries: const [],
          postes: const [],
          receiptsByEntryId: const {},
          selectedPosteId: null,
          isSimplified: false,
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
          isReadOnly: false,
          onFilterCleared: () {},
          onEntryCreationRequested: () {},
          onEntryTapped: (_) {},
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
          selectedPosteId: null,
          isSimplified: true,
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
          isReadOnly: false,
          onFilterCleared: () {},
          onEntryCreationRequested: () {},
          onEntryTapped: (_) {},
          onEntryDeletionRequested: (_) {},
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetCashJournal)));
    expect(find.text(tr.budgetCashJournalSimpleEmptyHint), findsOneWidget);
    expect(find.text(tr.budgetCashJournalEmptyHint), findsNothing);
  });

  testWidgets("an empty journal still offers the action that fills it", (tester) async {
    var created = 0;

    await tester.pumpWidget(
      _wrap(
        OcptBudgetCashJournal(
          entries: const [],
          postes: const [],
          receiptsByEntryId: const {},
          selectedPosteId: null,
          isSimplified: false,
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
          isReadOnly: false,
          onFilterCleared: () {},
          onEntryCreationRequested: () => created++,
          onEntryTapped: (_) {},
          onEntryDeletionRequested: (_) {},
        ),
      ),
    );

    final tr = Tr.of(tester.element(find.byType(OcptBudgetCashJournal)));
    await tester.tap(find.text(tr.budgetCashJournalEntryCreationAction));

    expect(created, 1);
  });

  testWidgets(
    "the running balance printed for a filtered row is the whole journal's, not the filtered "
    "subset's",
    (tester) async {
      // A poste-2 credit lands first, so poste-1's own two debits fall from +10000 rather than
      // from zero — the figure a wrongly-recomputed, filtered-only balance would show instead.
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
            selectedPosteId: "poste-1",
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: false,
            onFilterCleared: () {},
            onEntryCreationRequested: () {},
            onEntryTapped: (_) {},
            onEntryDeletionRequested: (_) {},
          ),
        ),
      );

      expect(find.text(ocptBudgetAmountLabel(6000, "EUR")), findsWidgets);
      expect(find.text(ocptBudgetAmountLabel(5000, "EUR")), findsWidgets);
      // Neither row is poisoned into starting the filtered subset over from zero: a wrongly
      // recomputed balance would go negative from the very first filtered row.
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
        _entry(id: "e3", date: DateTime(2026, 1, 3), creditCents: 500),
      ];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCashJournal(
            entries: entries,
            postes: const [],
            receiptsByEntryId: const {},
            selectedPosteId: null,
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: false,
            onFilterCleared: () {},
            onEntryCreationRequested: () {},
            onEntryTapped: (_) {},
            onEntryDeletionRequested: (_) {},
          ),
        ),
      );

      // The unreadable row's own debit, credit and balance cells all print the em dash.
      expect(find.text(ocptBudgetEmptyValue), findsWidgets);
      // The row below it keeps counting from the balance the journal actually stood at
      // (-2000), not from a poisoned figure: -2000 + 500 = -1500.
      expect(find.text(ocptBudgetAmountLabel(-1500, "EUR")), findsWidgets);
    },
  );

  testWidgets("a credit row reads in a different colour from a debit row", (tester) async {
    final entries = [
      _entry(id: "e1", date: DateTime(2026), debitCents: 1200),
      _entry(id: "e2", date: DateTime(2026, 1, 2), creditCents: 800),
    ];

    await tester.pumpWidget(
      _wrap(
        OcptBudgetCashJournal(
          entries: entries,
          postes: const [],
          receiptsByEntryId: const {},
          selectedPosteId: null,
          isSimplified: false,
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
          isReadOnly: false,
          onFilterCleared: () {},
          onEntryCreationRequested: () {},
          onEntryTapped: (_) {},
          onEntryDeletionRequested: (_) {},
        ),
      ),
    );

    final theme = Theme.of(tester.element(find.byType(OcptBudgetCashJournal)));
    // Both amounts also appear, uncoloured, in the top band's own whole-journal totals (the sum
    // of one entry each): the row's own cell is the last match in build order.
    final debitText = tester.widgetList<Text>(find.text(ocptBudgetAmountLabel(1200, "EUR"))).last;
    final creditText = tester.widgetList<Text>(find.text(ocptBudgetAmountLabel(800, "EUR"))).last;

    expect(debitText.style?.color, theme.colorScheme.error);
    expect(creditText.style?.color, theme.colorScheme.primary);
    expect(debitText.style?.color, isNot(creditText.style?.color));
  });

  testWidgets("an entry naming no poste reads as such rather than leaving the cell empty", (
    tester,
  ) async {
    final entries = [
      _entry(id: "e1", date: DateTime(2026), creditCents: 1000),
    ];

    await tester.pumpWidget(
      _wrap(
        OcptBudgetCashJournal(
          entries: entries,
          postes: const [],
          receiptsByEntryId: const {},
          selectedPosteId: null,
          isSimplified: false,
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
          isReadOnly: false,
          onFilterCleared: () {},
          onEntryCreationRequested: () {},
          onEntryTapped: (_) {},
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
          selectedPosteId: null,
          isSimplified: false,
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
          isReadOnly: false,
          onFilterCleared: () {},
          onEntryCreationRequested: () {},
          onEntryTapped: (_) {},
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
          selectedPosteId: null,
          isSimplified: false,
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
          isReadOnly: false,
          onFilterCleared: () {},
          onEntryCreationRequested: () {},
          onEntryTapped: (_) {},
          onEntryDeletionRequested: (_) {},
        ),
      ),
    );

    expect(find.text(tr.budgetCashJournalCoverageReadOut(1, 2)), findsNothing);
  });

  testWidgets("Remove filter clears the filter and is only drawn while one is on", (tester) async {
    var cleared = false;
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
          selectedPosteId: null,
          isSimplified: false,
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
          isReadOnly: false,
          onFilterCleared: () => cleared = true,
          onEntryCreationRequested: () {},
          onEntryTapped: (_) {},
          onEntryDeletionRequested: (_) {},
        ),
      ),
    );
    final tr = Tr.of(tester.element(find.byType(OcptBudgetCashJournal)));
    expect(find.text(tr.budgetCashJournalRemoveFilterAction), findsNothing);

    await tester.pumpWidget(
      _wrap(
        OcptBudgetCashJournal(
          entries: entries,
          postes: postes,
          receiptsByEntryId: const {},
          selectedPosteId: "poste-1",
          isSimplified: false,
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
          isReadOnly: false,
          onFilterCleared: () => cleared = true,
          onEntryCreationRequested: () {},
          onEntryTapped: (_) {},
          onEntryDeletionRequested: (_) {},
        ),
      ),
    );
    expect(find.text(tr.budgetCashJournalFilterCaption("Camera")), findsOneWidget);
    expect(find.text(tr.budgetCashJournalRemoveFilterAction), findsOneWidget);

    await tester.tap(find.text(tr.budgetCashJournalRemoveFilterAction));
    await tester.pumpAndSettle();

    expect(cleared, isTrue);
  });

  testWidgets(
    "withholds every writing affordance under a previewed version, Remove filter excepted",
    (tester) async {
      var tapped = false;
      var cleared = false;
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
            selectedPosteId: "poste-1",
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: true,
            onFilterCleared: () => cleared = true,
            onEntryCreationRequested: () => tapped = true,
            onEntryTapped: (_) => tapped = true,
            onEntryDeletionRequested: (_) => tapped = true,
          ),
        ),
      );

      final tr = Tr.of(tester.element(find.byType(OcptBudgetCashJournal)));
      expect(find.text(tr.budgetCashJournalEntryCreationAction), findsNothing);
      expect(find.byType(PopupMenuButton<String>), findsNothing);

      await tester.tap(find.text(entries.first.label));
      await tester.pumpAndSettle();
      expect(tapped, isFalse);

      // Remove filter writes nothing to the project, so it stays available even in preview.
      expect(find.text(tr.budgetCashJournalRemoveFilterAction), findsOneWidget);
      await tester.tap(find.text(tr.budgetCashJournalRemoveFilterAction));
      await tester.pumpAndSettle();
      expect(cleared, isTrue);
    },
  );

  group("an entry's own voucher marker", () {
    testWidgets("an entry with no voucher shows no marker at all", (tester) async {
      final entries = [_entry(id: "e1", date: DateTime(2026), debitCents: 1000)];

      await tester.pumpWidget(
        _wrap(
          OcptBudgetCashJournal(
            entries: entries,
            postes: const [],
            receiptsByEntryId: const {},
            selectedPosteId: null,
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: false,
            onFilterCleared: () {},
            onEntryCreationRequested: () {},
            onEntryTapped: (_) {},
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
            selectedPosteId: null,
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: false,
            onFilterCleared: () {},
            onEntryCreationRequested: () {},
            onEntryTapped: (_) {},
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
            selectedPosteId: null,
            isSimplified: false,
            defaultVatRateBasisPoints: null,
            currencyCode: "EUR",
            isReadOnly: false,
            onFilterCleared: () {},
            onEntryCreationRequested: () {},
            onEntryTapped: (_) {},
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
}

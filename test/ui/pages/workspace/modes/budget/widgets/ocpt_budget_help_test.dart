// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_document.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_sub_page.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/widgets/ocpt_budget_help.dart';

/// Wraps [child] with the localization delegates so [Tr.of] lookups resolve, inside a band wide
/// enough that the chain's own cells and the body's own paragraphs are drawn with no overflow.
Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    Tr.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: Tr.delegate.supportedLocales,
  home: Scaffold(body: SizedBox(width: 420, height: 1400, child: child)),
);

void main() {
  /// Pumps [OcptBudgetHelp] for the given route and returns its own [Tr], resolved from its own
  /// element — mirrors `ocpt_budget_fiche_test.dart`'s own `pumpFiche`.
  Future<Tr> pumpHelp(
    WidgetTester tester, {
    required OcptBudgetDocument document,
    OcptBudgetDocumentReading reading = OcptBudgetDocumentReading.byTree,
    OcptBudgetSubPage? subPage,
  }) async {
    await tester.pumpWidget(
      _wrap(
        OcptBudgetHelp(document: document, reading: reading, subPage: subPage),
      ),
    );
    await tester.pumpAndSettle();

    return Tr.of(tester.element(find.byType(OcptBudgetHelp)));
  }

  testWidgets("draws the expenses chain: Estimated, Committed, Paid", (tester) async {
    final tr = await pumpHelp(tester, document: OcptBudgetDocument.expenses);

    expect(find.text(tr.budgetFicheStepEstimatedLabel), findsOneWidget);
    expect(find.text(tr.budgetInspectorFigureCommitted), findsOneWidget);
    expect(find.text(tr.budgetInspectorFigurePaid), findsOneWidget);
    expect(find.text(tr.budgetHelpChainExpensesEstimatedCaption), findsOneWidget);
    expect(find.text(tr.budgetHelpChainExpensesCommittedCaption), findsOneWidget);
    expect(find.text(tr.budgetHelpChainExpensesPaidCaption), findsOneWidget);
    expect(find.text(tr.budgetHelpChainExpensesSentence), findsOneWidget);
  });

  testWidgets("draws the resources chain: Promised, Received", (tester) async {
    final tr = await pumpHelp(tester, document: OcptBudgetDocument.resources);

    expect(find.text(tr.budgetFicheStepPromisedLabel), findsOneWidget);
    expect(find.text(tr.budgetFinancingColumnReceived), findsOneWidget);
    expect(find.text(tr.budgetHelpChainResourcesPromisedCaption), findsOneWidget);
    expect(find.text(tr.budgetHelpChainResourcesReceivedCaption), findsOneWidget);
    expect(find.text(tr.budgetHelpChainResourcesSentence), findsOneWidget);
  });

  testWidgets("draws the sharing chain: Received, Already repaid, Left to share", (tester) async {
    final tr = await pumpHelp(tester, document: OcptBudgetDocument.sharing);

    expect(find.text(tr.budgetFinancingColumnReceived), findsOneWidget);
    expect(find.text(tr.budgetSharingRepaidLabel), findsOneWidget);
    expect(find.text(tr.budgetSharingLeftToShareLabel), findsOneWidget);
    expect(find.text(tr.budgetHelpChainSharingReceivedCaption), findsOneWidget);
    expect(find.text(tr.budgetHelpChainSharingRepaidCaption), findsOneWidget);
    expect(find.text(tr.budgetHelpChainSharingLeftToShareCaption), findsOneWidget);
    expect(find.text(tr.budgetHelpChainSharingSentence), findsOneWidget);
  });

  testWidgets("draws the committed-spending sub-page on the expenses chain", (tester) async {
    final tr = await pumpHelp(
      tester,
      document: OcptBudgetDocument.expenses,
      subPage: OcptBudgetSubPage.committedSpending,
    );

    expect(find.text(tr.budgetFicheStepEstimatedLabel), findsOneWidget);
    expect(find.text(tr.budgetInspectorFigureCommitted), findsOneWidget);
    expect(find.text(tr.budgetInspectorFigurePaid), findsOneWidget);
  });

  testWidgets("the régie sub-page draws no chain at all", (tester) async {
    final tr = await pumpHelp(
      tester,
      document: OcptBudgetDocument.expenses,
      subPage: OcptBudgetSubPage.regie,
    );

    // No chain of any of the three documents' own steps is drawn.
    expect(find.text(tr.budgetFicheStepEstimatedLabel), findsNothing);
    expect(find.text(tr.budgetFicheStepPromisedLabel), findsNothing);
    expect(find.text(tr.budgetSharingLeftToShareLabel), findsNothing);
    expect(find.byType(Table), findsNothing);

    // Its own first paragraph says why: it types nothing, every figure read from somewhere else.
    expect(find.text(tr.budgetHelpRegieBody1), findsOneWidget);
    expect(
      find.text(
        tr.budgetHelpRegieBody5(
          tr.budgetHeaderDocumentExpensesSegmentLabel,
          tr.budgetHeaderRegieTitle,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    "highlights the Paid step on expenses read by date, announced rather than drawn",
    (tester) async {
      final tr = await pumpHelp(
        tester,
        document: OcptBudgetDocument.expenses,
        reading: OcptBudgetDocumentReading.byDate,
      );

      // The badge rides the cell's own Semantics label — it is never drawn as a widget of its own.
      expect(find.text(tr.budgetHelpChainCurrentStepBadge), findsNothing);
      // And it rides the `Paid` cell's, not merely some cell's. The cell's own caption is merged
      // into that same label, so the match is anchored on its head rather than exact.
      expect(
        find.bySemanticsLabel(
          RegExp(
            "^${RegExp.escape(tr.budgetInspectorFigurePaid)}, "
            "${RegExp.escape(tr.budgetHelpChainCurrentStepBadge)}",
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    "highlights the Committed step on the committed-spending sub-page, announced rather than drawn",
    (tester) async {
      final tr = await pumpHelp(
        tester,
        document: OcptBudgetDocument.expenses,
        subPage: OcptBudgetSubPage.committedSpending,
      );

      expect(find.text(tr.budgetHelpChainCurrentStepBadge), findsNothing);
      expect(
        find.bySemanticsLabel(
          RegExp(
            "^${RegExp.escape(tr.budgetInspectorFigureCommitted)}, "
            "${RegExp.escape(tr.budgetHelpChainCurrentStepBadge)}",
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets("highlights nothing on the cost report (expenses read by tree)", (tester) async {
    final tr = await pumpHelp(tester, document: OcptBudgetDocument.expenses);

    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(tr.budgetHelpChainCurrentStepBadge))),
      findsNothing,
    );
  });
}

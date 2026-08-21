// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';

/// Builds a minimal quote line, everything but [id]/[posteId]/[label] neutral.
OcptBudgetLine _buildLine({required String id, required String posteId, String label = ""}) =>
    OcptBudgetLine(
      id: id,
      posteId: posteId,
      label: label,
      quantityMilli: 1000,
      unit: "u",
      unitPrice: const OcptMoney(amountCents: 0, isTaxInclusive: true, vatRateBasisPoints: null),
      elementId: null,
      notes: "",
      sortKey: "a0",
    );

/// Builds a minimal poste, everything but [id]/[lines] neutral.
OcptBudgetPoste _buildPoste({required String id, List<OcptBudgetLine> lines = const []}) =>
    OcptBudgetPoste(id: id, code: "1", label: "Poste $id", simpleLabel: null, sortKey: "a0", lines: lines);

void main() {
  group("OcptBudgetState.init", () {
    test("starts loading, with no snapshot and the default right dock tab", () {
      const state = OcptBudgetState.init();

      expect(state.isLoading, isTrue);
      expect(state.snapshot, isNull);
      expect(state.postes, isEmpty);
      expect(state.posteCount, 0);
      expect(state.lineCount, 0);
      expect(state.rightDockTab, isNull);
      expect(state.lastRightDockTab, OcptBudgetRightDockTab.inspector);
      expect(state.selectedPoste, isNull);
    });
  });

  group("OcptBudgetState.selectedPoste", () {
    test("resolves the poste named by selectedPosteId out of the snapshot", () {
      final poste = _buildPoste(id: "poste-1");
      final state = const OcptBudgetState.init().copyWith(
        snapshot: OcptBudgetSnapshot.build(
          postes: [poste],
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
        ),
        selectedPosteId: "poste-1",
      );

      expect(state.selectedPoste, poste);
    });

    test("is null while selectedPosteId names no live poste", () {
      final state = const OcptBudgetState.init().copyWith(
        snapshot: OcptBudgetSnapshot.build(
          postes: [_buildPoste(id: "poste-1")],
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
        ),
        selectedPosteId: "gone",
      );

      expect(state.selectedPoste, isNull);
    });
  });

  group("OcptBudgetState.fieldValueOf", () {
    test("reads a pending edit ahead of the stored value", () {
      final state = const OcptBudgetState.init().copyWith(
        pendingFieldEdits: {("poste-1", OcptBudgetField.posteLabel): "Typed"},
      );

      expect(state.fieldValueOf("poste-1", OcptBudgetField.posteLabel, "Stored"), "Typed");
    });

    test("falls back to the stored value while nothing is pending for that key", () {
      const state = OcptBudgetState.init();

      expect(state.fieldValueOf("poste-1", OcptBudgetField.posteLabel, "Stored"), "Stored");
    });
  });

  group("OcptBudgetState.copyWith", () {
    test("clears selectedPosteId only through its own clear flag", () {
      final withSelection = const OcptBudgetState.init().copyWith(selectedPosteId: "poste-1");
      expect(withSelection.selectedPosteId, "poste-1");

      final stillSelected = withSelection.copyWith(centreView: withSelection.centreView);
      expect(stillSelected.selectedPosteId, "poste-1");

      final cleared = withSelection.copyWith(clearSelectedPosteId: true);
      expect(cleared.selectedPosteId, isNull);
    });

    test("clears expandedLineId only through its own clear flag", () {
      final withExpanded = const OcptBudgetState.init().copyWith(expandedLineId: "line-1");
      expect(withExpanded.expandedLineId, "line-1");

      final cleared = withExpanded.copyWith(clearExpandedLineId: true);
      expect(cleared.expandedLineId, isNull);
    });

    test("clears rightDockTab only through its own clear flag", () {
      final withTab = const OcptBudgetState.init().copyWith(
        rightDockTab: OcptBudgetRightDockTab.inspector,
      );
      expect(withTab.rightDockTab, OcptBudgetRightDockTab.inspector);

      final cleared = withTab.copyWith(clearRightDockTab: true);
      expect(cleared.rightDockTab, isNull);
    });
  });

  group("OcptBudgetSnapshot counters", () {
    test("posteCount and lineCount count every poste and every line across them", () {
      final snapshot = OcptBudgetSnapshot.build(
        postes: [
          _buildPoste(
            id: "poste-1",
            lines: [
              _buildLine(id: "line-1", posteId: "poste-1"),
              _buildLine(id: "line-2", posteId: "poste-1"),
            ],
          ),
          _buildPoste(id: "poste-2"),
        ],
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
      );
      final state = const OcptBudgetState.init().copyWith(snapshot: snapshot);

      expect(state.posteCount, 2);
      expect(state.lineCount, 2);
    });
  });
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
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

/// Builds a minimal journal entry naming [posteId], everything else neutral (a debit of
/// [debitCents], tax-inclusive, no VAT rate override).
OcptBudgetEntry _buildEntry({required String id, required String posteId, int debitCents = 0}) =>
    OcptBudgetEntry(
      id: id,
      date: DateTime(2026),
      label: "Entry $id",
      posteId: posteId,
      debitCents: debitCents,
      creditCents: 0,
      isTaxInclusive: true,
      vatRateBasisPoints: null,
      voucherNumber: "J-001",
      sortKey: "a0",
      resourceId: null,
    );

/// Builds a minimal financing resource, everything but [id] neutral.
OcptBudgetResource _buildResource({
  required String id,
  OcptBudgetResourceGroupKind groupKind = OcptBudgetResourceGroupKind.subsidy,
  int amountCents = 0,
}) => OcptBudgetResource(
  id: id,
  groupKind: groupKind,
  label: "Resource $id",
  amountCents: amountCents,
  status: OcptBudgetResourceStatus.applied,
  isReimbursable: false,
  notes: "",
  sortKey: "a0",
);

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
          entries: const [],
          commitments: const [],
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
          entries: const [],
          commitments: const [],
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
        entries: const [],
        commitments: const [],
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
      );
      final state = const OcptBudgetState.init().copyWith(snapshot: snapshot);

      expect(state.posteCount, 2);
      expect(state.lineCount, 2);
    });
  });

  group("OcptBudgetState.paidCentsOf / committedCentsOf", () {
    test("reads zero for a poste with no entry against it, rather than a hole", () {
      final snapshot = OcptBudgetSnapshot.build(
        postes: [_buildPoste(id: "poste-1"), _buildPoste(id: "poste-2")],
        entries: [_buildEntry(id: "entry-1", posteId: "poste-1", debitCents: 1000)],
        commitments: const [],
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
      );
      final state = const OcptBudgetState.init().copyWith(snapshot: snapshot);

      expect(state.paidCentsOf("poste-2"), 0);
      expect(state.committedCentsOf("poste-2"), 0);
    });

    test("reads the real amount once an entry has actually been paid against the poste", () {
      final snapshot = OcptBudgetSnapshot.build(
        postes: [_buildPoste(id: "poste-1")],
        entries: [_buildEntry(id: "entry-1", posteId: "poste-1", debitCents: 1000)],
        commitments: const [],
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
      );
      final state = const OcptBudgetState.init().copyWith(snapshot: snapshot);

      expect(state.paidCentsOf("poste-1"), 1000);
    });

    test("answers zero while nothing at all is loaded yet", () {
      const state = OcptBudgetState.init();

      expect(state.paidCentsOf("poste-1"), 0);
      expect(state.committedCentsOf("poste-1"), 0);
    });

    test("excludes a settled commitment outright", () {
      final snapshot = OcptBudgetSnapshot.build(
        postes: [_buildPoste(id: "poste-1")],
        entries: const [],
        commitments: [
          const OcptBudgetCommitment(
            id: "commitment-1",
            dueDate: null,
            label: "Camera deposit",
            posteId: "poste-1",
            amount: OcptMoney(amountCents: 5000, isTaxInclusive: true, vatRateBasisPoints: null),
            status: OcptBudgetCommitmentStatus.quoteAccepted,
            settledEntryId: "entry-1",
            sortKey: "a0",
          ),
        ],
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
      );
      final state = const OcptBudgetState.init().copyWith(snapshot: snapshot);

      expect(state.committedCentsOf("poste-1"), 0);
    });
  });

  group("OcptBudgetState.commitments", () {
    test("reads the snapshot's own commitments, empty while nothing is loaded", () {
      const emptyState = OcptBudgetState.init();
      expect(emptyState.commitments, isEmpty);

      final commitment = OcptBudgetCommitment(
        id: "commitment-1",
        dueDate: DateTime(2026),
        label: "Camera deposit",
        posteId: "poste-1",
        amount: const OcptMoney(amountCents: 5000, isTaxInclusive: true, vatRateBasisPoints: null),
        status: OcptBudgetCommitmentStatus.quoteAccepted,
        settledEntryId: null,
        sortKey: "a0",
      );
      final snapshot = OcptBudgetSnapshot.build(
        postes: [_buildPoste(id: "poste-1")],
        entries: const [],
        commitments: [commitment],
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
      );
      final state = const OcptBudgetState.init().copyWith(snapshot: snapshot);

      expect(state.commitments, [commitment]);
    });
  });

  group("OcptBudgetState.alerts", () {
    test("reads the snapshot's own alerts, empty while nothing is loaded", () {
      const emptyState = OcptBudgetState.init();
      expect(emptyState.alerts, isEmpty);

      final snapshot = OcptBudgetSnapshot.build(
        postes: [_buildPoste(id: "poste-1", lines: [_buildLine(id: "line-1", posteId: "poste-1")])],
        entries: const [],
        commitments: const [],
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
      );
      final state = const OcptBudgetState.init().copyWith(snapshot: snapshot);

      // A poste quoted at zero (the neutral line's own unit price) with nothing paid or
      // committed against it raises nothing.
      expect(state.alerts, isEmpty);
    });
  });

  group("OcptBudgetState.paidByPosteId / committedByPosteId", () {
    test("read the snapshot's own maps, empty while nothing is loaded", () {
      const emptyState = OcptBudgetState.init();
      expect(emptyState.paidByPosteId, isEmpty);
      expect(emptyState.committedByPosteId, isEmpty);

      final snapshot = OcptBudgetSnapshot.build(
        postes: [_buildPoste(id: "poste-1")],
        entries: [_buildEntry(id: "entry-1", posteId: "poste-1", debitCents: 1000)],
        commitments: const [],
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
      );
      final state = const OcptBudgetState.init().copyWith(snapshot: snapshot);

      expect(state.paidByPosteId["poste-1"]?.amountCents, 1000);
      expect(state.committedByPosteId, isEmpty);
    });
  });

  group("OcptBudgetState.resources / resourceCount", () {
    test("read the snapshot's own resources, empty while nothing is loaded", () {
      const emptyState = OcptBudgetState.init();
      expect(emptyState.resources, isEmpty);
      expect(emptyState.resourceCount, 0);

      final resource = _buildResource(id: "resource-1");
      final snapshot = OcptBudgetSnapshot.build(
        postes: const [],
        entries: const [],
        commitments: const [],
        resources: [resource],
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
      );
      final state = const OcptBudgetState.init().copyWith(snapshot: snapshot);

      expect(state.resources, [resource]);
      expect(state.resourceCount, 1);
    });
  });

  group("OcptBudgetState.selectedResource", () {
    test("resolves the resource named by selectedResourceId out of the snapshot", () {
      final resource = _buildResource(id: "resource-1");
      final state = const OcptBudgetState.init().copyWith(
        snapshot: OcptBudgetSnapshot.build(
          postes: const [],
          entries: const [],
          commitments: const [],
          resources: [resource],
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
        ),
        selectedResourceId: "resource-1",
      );

      expect(state.selectedResource, resource);
    });

    test("is null while selectedResourceId names no live resource", () {
      final state = const OcptBudgetState.init().copyWith(
        snapshot: OcptBudgetSnapshot.build(
          postes: const [],
          entries: const [],
          commitments: const [],
          resources: [_buildResource(id: "resource-1")],
          defaultVatRateBasisPoints: null,
          currencyCode: "EUR",
        ),
        selectedResourceId: "gone",
      );

      expect(state.selectedResource, isNull);
    });
  });

  group("OcptBudgetState.copyWith clears selectedResourceId", () {
    test("only through its own clear flag", () {
      final withSelection = const OcptBudgetState.init().copyWith(selectedResourceId: "resource-1");
      expect(withSelection.selectedResourceId, "resource-1");

      final stillSelected = withSelection.copyWith(centreView: withSelection.centreView);
      expect(stillSelected.selectedResourceId, "resource-1");

      final cleared = withSelection.copyWith(clearSelectedResourceId: true);
      expect(cleared.selectedResourceId, isNull);
    });
  });

  group("OcptBudgetState.receivedCentsOf / receivedByResourceId", () {
    test("reads zero for a resource with no entry naming it, rather than a hole", () {
      final resource = _buildResource(id: "resource-1", amountCents: 5000);
      final snapshot = OcptBudgetSnapshot.build(
        postes: const [],
        entries: const [],
        commitments: const [],
        resources: [resource],
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
      );
      final state = const OcptBudgetState.init().copyWith(snapshot: snapshot);

      expect(state.receivedCentsOf("resource-1"), 0);
      expect(state.receivedByResourceId, isEmpty);
    });

    test("reads the real amount once an entry credits the resource", () {
      final resource = _buildResource(id: "resource-1", amountCents: 5000);
      final entry = OcptBudgetEntry(
        id: "entry-1",
        date: DateTime(2026),
        label: "Grant instalment",
        posteId: null,
        debitCents: 0,
        creditCents: 2000,
        isTaxInclusive: true,
        vatRateBasisPoints: null,
        voucherNumber: "J-001",
        sortKey: "a0",
        resourceId: "resource-1",
      );
      final snapshot = OcptBudgetSnapshot.build(
        postes: const [],
        entries: [entry],
        commitments: const [],
        resources: [resource],
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
      );
      final state = const OcptBudgetState.init().copyWith(snapshot: snapshot);

      expect(state.receivedCentsOf("resource-1"), 2000);
      expect(state.receivedByResourceId["resource-1"]?.amountCents, 2000);
    });

    test("answers zero while nothing at all is loaded yet", () {
      const state = OcptBudgetState.init();

      expect(state.receivedCentsOf("resource-1"), 0);
    });
  });

  group("OcptBudgetSnapshot.resourceCount", () {
    test("counts every live resource", () {
      final snapshot = OcptBudgetSnapshot.build(
        postes: const [],
        entries: const [],
        commitments: const [],
        resources: [_buildResource(id: "resource-1"), _buildResource(id: "resource-2")],
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
      );

      expect(snapshot.resourceCount, 2);
    });
  });

  group("OcptBudgetState.receiptsByEntryId", () {
    test("is empty while nothing is loaded or no entry carries a voucher", () {
      const emptyState = OcptBudgetState.init();
      expect(emptyState.receiptsByEntryId, isEmpty);

      final snapshot = OcptBudgetSnapshot.build(
        postes: [_buildPoste(id: "poste-1")],
        entries: [_buildEntry(id: "entry-1", posteId: "poste-1")],
        commitments: const [],
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
      );
      final state = const OcptBudgetState.init().copyWith(snapshot: snapshot);

      expect(state.receiptsByEntryId, isEmpty);
    });
  });
}

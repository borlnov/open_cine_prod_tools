// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_commitment.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_line.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_poste.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_resource.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_money.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_cast_member.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot_crew_member.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_commitment_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_group_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_resource_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_source_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_image_rights_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_day_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_slot_anchor_edge.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/budget/budget_state.dart';

/// Builds a minimal quote line, everything but [id]/[posteId]/[label]/[elementId] neutral.
OcptBudgetLine _buildLine({
  required String id,
  required String posteId,
  String label = "",
  String? elementId,
}) => OcptBudgetLine(
  id: id,
  posteId: posteId,
  label: label,
  quantityMilli: 1000,
  unit: "u",
  unitPrice: const OcptMoney(amountCents: 0, isTaxInclusive: true, vatRateBasisPoints: null),
  elementId: elementId,
  notes: "",
  sortKey: "a0",
);

/// Builds a minimal breakdown element, everything but [id]/[name]/[cost] neutral — mirrors
/// `ocpt_elements_list_test.dart`'s own `_element`.
OcptElement _buildElement({required String id, String name = "", int? cost}) => OcptElement(
  id: id,
  category: OcptElementCategory.prop,
  subCategory: "",
  name: name,
  code: "",
  quantity: "",
  sourceKind: OcptElementSourceKind.owned,
  status: OcptElementStatus.toFind,
  ownerPersonId: null,
  ownerNotes: "",
  broughtByPersonId: null,
  storageNotes: "",
  isSecured: false,
  isReadyForShoot: false,
  isReturned: false,
  cost: cost,
  purposeNotes: "",
  notes: "",
  photoAssetId: null,
  photo: null,
  sceneLinks: const [],
  roleLinks: const [],
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

/// Builds a shooting day with the few fields these tests read, everything else neutral.
OcptShootingDay _buildDay({required String id, required int dayNumber, required DateTime date}) =>
    OcptShootingDay(
      id: id,
      date: date,
      dayNumber: dayNumber,
      status: OcptShootingDayStatus.planned,
      crewNote: "",
      weatherNote: "",
      notes: "",
    );

/// Builds a slot with the few fields these tests read, everything else neutral.
OcptShootingSlot _buildSlot({
  required String id,
  required String dayId,
  List<OcptShootingSlotCrewMember> crew = const [],
  List<OcptShootingSlotCastMember> cast = const [],
}) => OcptShootingSlot(
  id: id,
  shootingDayId: dayId,
  label: "",
  locationId: null,
  setId: null,
  anchorEdge: OcptShootingSlotAnchorEdge.start,
  anchorMinute: 480,
  anchorSlotId: null,
  notes: "",
  crew: crew,
  cast: cast,
  guests: const [],
);

/// Builds a crew assignment, the few fields these tests read, everything else neutral.
OcptShootingSlotCrewMember _buildCrewMember({
  required String id,
  required String slotId,
  required String personId,
}) => OcptShootingSlotCrewMember(
  id: id,
  slotId: slotId,
  personId: personId,
  positionId: "",
  customLabel: "",
  notes: "",
);

/// Builds a cast convocation naming [roleId], the few fields these tests read.
OcptShootingSlotCastMember _buildCastMember({
  required String id,
  required String slotId,
  required String roleId,
}) => OcptShootingSlotCastMember(id: id, slotId: slotId, roleId: roleId, notes: "");

/// Builds a role, the few fields these tests read, everything else neutral.
OcptRole _buildRole({
  required String id,
  String name = "",
  String? personId,
  OcptRoleKind kind = OcptRoleKind.speaking,
}) => OcptRole(
  id: id,
  name: name,
  personId: personId,
  kind: kind,
  isFromScreenplay: false,
  orphanedName: null,
  castingNotes: "",
  number: 1,
  episodeIds: const [],
);

/// Builds a person, the few fields these tests read, everything else neutral.
OcptPerson _buildPerson({
  required String id,
  int? commuteKmMilli,
  String? mileageRateId,
}) => OcptPerson(
  id: id,
  firstName: "Person $id",
  lastName: "",
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
  commuteKmMilli: commuteKmMilli,
  mileageRateId: mileageRateId,
  positions: const [],
  skills: const [],
  unavailabilities: const [],
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

  group("OcptBudgetState.elementLinkCounts / unpricedElements", () {
    test("a live element named by a live line's own elementId counts as priced", () {
      final snapshot = OcptBudgetSnapshot.build(
        postes: [
          _buildPoste(
            id: "poste-1",
            lines: [_buildLine(id: "line-1", posteId: "poste-1", elementId: "element-priced")],
          ),
        ],
        entries: const [],
        commitments: const [],
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
      );
      final state = const OcptBudgetState.init().copyWith(
        snapshot: snapshot,
        elements: [
          _buildElement(id: "element-priced", name: "Priced"),
          _buildElement(id: "element-unpriced", name: "Unpriced"),
        ],
      );

      expect(state.elementLinkCounts.pricedCount, 1);
      expect(state.elementLinkCounts.unpricedCount, 1);
    });

    test("offers only the elements no live line prices yet, an already-priced one dropped", () {
      final snapshot = OcptBudgetSnapshot.build(
        postes: [
          _buildPoste(
            id: "poste-1",
            lines: [_buildLine(id: "line-1", posteId: "poste-1", elementId: "element-priced")],
          ),
        ],
        entries: const [],
        commitments: const [],
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
      );
      final state = const OcptBudgetState.init().copyWith(
        snapshot: snapshot,
        elements: [
          _buildElement(id: "element-priced", name: "Priced"),
          _buildElement(id: "element-unpriced", name: "Unpriced"),
        ],
      );

      expect(state.unpricedElements.map((element) => element.id), ["element-unpriced"]);
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

  group("OcptBudgetState.regieDays / travelRows", () {
    test("are empty while nothing is loaded", () {
      const state = OcptBudgetState.init();

      expect(state.regieDays, isEmpty);
      expect(state.travelRows, isEmpty);
      expect(state.regieTotals.cost.amountCents, 0);
      expect(state.travelTotals.cost.amountCents, 0);
    });

    test("read the snapshot's own catering-and-travel pass, built from the schedule it was given", () {
      final crewPerson = _buildPerson(id: "person-crew", commuteKmMilli: 10000, mileageRateId: "rate-1");
      final castPerson = _buildPerson(id: "person-cast");
      final role = _buildRole(id: "role-1", name: "Hero", personId: "person-cast");

      final day = _buildDay(id: "day-1", dayNumber: 1, date: DateTime(2026, 3));
      final slot = _buildSlot(
        id: "slot-1",
        dayId: "day-1",
        crew: [_buildCrewMember(id: "crew-1", slotId: "slot-1", personId: "person-crew")],
        cast: [_buildCastMember(id: "cast-1", slotId: "slot-1", roleId: "role-1")],
      );

      final snapshot = OcptBudgetSnapshot.build(
        postes: const [],
        entries: const [],
        commitments: const [],
        defaultVatRateBasisPoints: null,
        currencyCode: "EUR",
        scheduleDays: [day],
        slotsByDayId: {
          "day-1": [slot],
        },
        roles: [role],
        people: [crewPerson, castPerson],
        mileageRates: [
          const OcptBudgetMileageRate(id: "rate-1", label: "Car", ratePerKmMilliCents: 50000, sortKey: "a0"),
        ],
        mealPriceCents: 1200,
        snackPriceCents: 400,
      );
      final state = const OcptBudgetState.init().copyWith(snapshot: snapshot);

      expect(state.regieDays, hasLength(1));
      expect(state.regieDays.single.headCount, 2);
      expect(state.regieDays.single.cost.isComplete, isTrue);
      expect(state.mealPriceCents, 1200);
      expect(state.snackPriceCents, 400);

      expect(state.travelRows, hasLength(2));
      final crewRow = state.travelRows.firstWhere((row) => row.personId == "person-crew");
      expect(crewRow.totalKmMilli, 20000);
      expect(crewRow.amountCents, 1000);
      final castRow = state.travelRows.firstWhere((row) => row.personId == "person-cast");
      expect(castRow.totalKmMilli, isNull);
      expect(castRow.amountCents, isNull);
    });
  });

  group("OcptBudgetState.roles / people / regieDecorNameByDayId", () {
    test("default to empty and are carried through copyWith", () {
      const emptyState = OcptBudgetState.init();
      expect(emptyState.roles, isEmpty);
      expect(emptyState.people, isEmpty);
      expect(emptyState.regieDecorNameByDayId, isEmpty);

      final role = _buildRole(id: "role-1");
      final person = _buildPerson(id: "person-1");
      final state = emptyState.copyWith(
        roles: [role],
        people: [person],
        regieDecorNameByDayId: const {"day-1": "Kitchen"},
      );

      expect(state.roles, [role]);
      expect(state.people, [person]);
      expect(state.regieDecorNameByDayId, {"day-1": "Kitchen"});
    });
  });
}

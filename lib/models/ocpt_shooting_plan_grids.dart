// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/constants/ocpt_crew_positions.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';

/// One column of the locations, sequences and crew-and-cast summary grids: a slot, and the day it
/// belongs to — [dayId]/[dayNumber] let a caller print or write a day tag once above the first
/// column of its own group, [OcptShootingPlanGrids.slotColumns] itself carrying no grouping of its
/// own (a caller compares one column's [dayId] against the one before it, exactly as
/// `OcptShootingPlanPdfService._gridPage` already does).
class OcptShootingPlanGridColumn extends Equatable {
  /// Class constructor
  const OcptShootingPlanGridColumn({
    required this.dayId,
    required this.dayNumber,
    required this.slotId,
    required this.slotLabel,
  });

  /// The id of the day [slotId] belongs to.
  final String dayId;

  /// That day's own printed rank (`OcptShootingDay.dayNumber`).
  final int dayNumber;

  /// The slot this column is about.
  final String slotId;

  /// The slot's own free-text label, verbatim — never substituted with a placeholder here, which is
  /// a drawing-time decision each caller makes for itself.
  final String slotLabel;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptShootingPlanGridColumn(dayId: $dayId, slotId: $slotId)";

  /// Object properties
  @override
  List<Object?> get props => [dayId, dayNumber, slotId, slotLabel];
}

/// One row of the locations, sequences or crew-and-cast summary grid: its own leading label and its
/// already-resolved cells, one per [OcptShootingPlanGrids.slotColumns] entry, in the same order.
///
/// A cell is the empty string when the row's own subject does not apply to that column at all (a
/// location's row against a slot shot somewhere else, a role's row against a slot that doesn't
/// convoke it) — never a placeholder standing in for a missing value, the distinction
/// `OcptShootingPlanPdfService._gridDataCell`'s own doc comment already draws between a blank grid
/// cell and a blank shot-table one. A caller substitutes its own "nothing here" mark for a
/// genuinely missing value elsewhere; this model never does.
class OcptShootingPlanGridRow extends Equatable {
  /// Class constructor
  const OcptShootingPlanGridRow({
    required this.label,
    required this.cells,
    this.isBold = false,
    this.isMuted = false,
    this.isIndented = false,
  });

  /// This row's own leading label (a location's name, a sequence's own tag, a crew position's or a
  /// role's own label).
  final String label;

  /// This row's own resolved value at every one of [OcptShootingPlanGrids.slotColumns], in order.
  final List<String> cells;

  /// Whether [label] is meant to be printed bold — a location's or a sequence's own name, a crew
  /// position.
  final bool isBold;

  /// Whether this row's own cells are meant to be printed muted — the locations grid's own nested
  /// `Perso.` row.
  final bool isMuted;

  /// Whether [label] is meant to be printed indented — the locations grid's own nested `Perso.` row.
  final bool isIndented;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptShootingPlanGridRow(label: $label, cells: ${cells.length})";

  /// Object properties
  @override
  List<Object?> get props => [label, cells, isBold, isMuted, isIndented];
}

/// One row of the elements summary grid — either an [OcptElementCategory] band or one element's own
/// data row. A sealed alternative to reusing [OcptShootingPlanGridRow] itself: that class's own
/// cells read a **slot** column, and the elements grid's own columns are **days**
/// ([OcptShootingPlanGrids]'s own doc comment), so reusing it would either force a slot-shaped
/// column onto a grid that has none or force every slot grid's own row to accept a column type it
/// never sees.
sealed class OcptShootingPlanElementsGridRow extends Equatable {
  /// Class constructor
  const OcptShootingPlanElementsGridRow();
}

/// An [OcptElementCategory] band row — the reference `.xlsx`'s own `ANIMAUX`/`VÉHICULES`/
/// `ÉQUIPEMENTS SPÉCIAUX` bands — carrying no per-column cell of its own: a caller draws it as a
/// whole row in its own right, however it draws a band (a coloured `pw.TableRow`, a bolded XLSX
/// row).
class OcptShootingPlanElementsGridCategoryBand extends OcptShootingPlanElementsGridRow {
  /// Class constructor
  const OcptShootingPlanElementsGridCategoryBand({required this.label});

  /// The category's own already-resolved display label.
  final String label;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptShootingPlanElementsGridCategoryBand(label: $label)";

  /// Object properties
  @override
  List<Object?> get props => [label];
}

/// One element's own row: its `<code> · <name>` label — the same shape
/// `OcptSchedulePlanSnapshot.elementsToBringOnDay`'s own printed line already carries on a named
/// call sheet — and its already-resolved cells, one per [OcptShootingPlanGrids.dayColumns] entry,
/// in the same order: the caller's own presence mark when the element is needed that day, or the
/// empty string otherwise — **never a quantity summed across that day's own scenes**, see
/// [OcptShootingPlanGrids]'s own doc comment.
class OcptShootingPlanElementsGridElementRow extends OcptShootingPlanElementsGridRow {
  /// Class constructor
  const OcptShootingPlanElementsGridElementRow({required this.label, required this.cells});

  /// This row's own leading label.
  final String label;

  /// This row's own resolved value at every one of [OcptShootingPlanGrids.dayColumns], in order.
  final List<String> cells;

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptShootingPlanElementsGridElementRow(label: $label, cells: ${cells.length})";

  /// Object properties
  @override
  List<Object?> get props => [label, cells];
}

/// The four summary grids of the shooting plan — locations, sequences, crew and cast, and elements
/// — computed once here so `OcptShootingPlanPdfService` (which prints them as landscape pages) and
/// `OcptShootingPlanXlsxExportService` (which writes them as workbook sheets) cannot come to
/// disagree about what a production is doing on a given day.
///
/// Pure Dart on purpose (no `pdf` import, no Flutter import): exactly the shape
/// `OcptScenarioCoverageLayout` and `OcptShootingDayAgendaGrid` already are. It owns every rule a
/// caller would otherwise have to restate — which locations, sequences, positions, roles and
/// elements earn a row, which cell is blank because a slot or a day doesn't apply and which is
/// blank because nothing is there to say — and hands back rows whose own cells are already resolved
/// strings, never a closure: a `valueOf(column)` callback is a drawing-time convenience belonging to
/// whichever service consumes it, not something a model should carry.
///
/// It takes no `OcptShootingPlanLabels`, and deliberately so: a `lib/models/` file must not depend
/// on `lib/managers/export/services/`, where that labels class lives beside the PDF service that
/// reads it (dependencies never reference their dependents). The handful of words its own rows need
/// — the presence mark, the `Perso.` label, the sequences row's own prefix, and the mark substituted
/// for a location with no name of its own — arrive as plain [String] parameters instead, exactly the
/// trade `ocptScheduleGuestRowsOfDay` already makes for its own `unnamedPersonLabel`
/// (`ocpt_schedule_pdf_shared.dart`). The crew position and element category labels arrive as the
/// very maps the caller already holds, for the same reason.
///
/// **The locations, sequences and crew-and-cast grids' own columns are one per slot, grouped under
/// its day** ([slotColumns]) — a decision already taken, this model does not revisit it. **The
/// elements grid's own columns are one per day instead** ([dayColumns]): an element is needed on a
/// day or it is not, and which of that day's own units carries it is not something this app's data
/// says.
///
/// **Chunking a wide grid across several pages, or running it on across nothing at all for a
/// workbook, is not this model's job.** [slotColumns] and [dayColumns] are handed back whole; a PDF
/// service paginates them into fixed-size chunks for a landscape page, an XLSX service writes every
/// one of them into a single sheet — two different answers to a question this model does not ask.
class OcptShootingPlanGrids extends Equatable {
  /// Class constructor. Prefer [OcptShootingPlanGrids.of].
  const OcptShootingPlanGrids({
    required this.slotColumns,
    required this.dayColumns,
    required this.locationsRows,
    required this.sequencesRows,
    required this.peopleRows,
    required this.elementsRows,
  });

  /// One column per live slot of every live day of `dayIds` that carries at least one, in the order
  /// given — a day with no live slot at all contributes no column.
  final List<OcptShootingPlanGridColumn> slotColumns;

  /// One column per live day of `dayIds`, in the order given — the elements grid's own columns.
  /// Unlike [slotColumns], a day contributes one here even while it carries no live slot at all: an
  /// element's own need is read off the scenes a day plays, never off a slot.
  final List<OcptShootingDay> dayColumns;

  /// The locations grid's own rows: two per location referenced by [slotColumns] — its own name
  /// (marking, in each of its own slot columns, the set shot there or the caller's own presence mark
  /// when none was chosen) and, nested under it, a row naming who is present.
  final List<OcptShootingPlanGridRow> locationsRows;

  /// The sequences grid's own rows: one per sequence with at least one shot placed anywhere in
  /// [slotColumns], in screenplay order, each cell listing the shot ranks covered in that slot.
  final List<OcptShootingPlanGridRow> sequencesRows;

  /// The crew and cast grid's own rows: one per crew position actually held anywhere in
  /// [slotColumns], in catalogue order, then one per role convoked anywhere in [slotColumns], in
  /// role-number order.
  final List<OcptShootingPlanGridRow> peopleRows;

  /// The elements grid's own rows: every element linked to a scene at least one of [dayColumns]
  /// actually plays, grouped under an [OcptElementCategory] band in the enum's own declaration
  /// order, each band's own elements sorted by name.
  final List<OcptShootingPlanElementsGridRow> elementsRows;

  /// Builds the four grids of [plan] over [dayIds] — see the class doc comment for why every
  /// localized word arrives as a plain parameter or a map rather than a labels object.
  factory OcptShootingPlanGrids.of({
    required OcptSchedulePlanSnapshot plan,
    required List<String> dayIds,
    required String presenceMark,
    required String persoLabel,
    required String sequenceRowPrefix,
    required String emptyValue,
    required Map<String, String> crewPositionLabelById,
    required Map<OcptElementCategory, String> elementCategoryLabels,
  }) {
    final slotColumnRefs = _liveSlotColumnsOf(plan, dayIds);
    final dayColumns = [
      for (final dayId in dayIds)
        if (plan.schedule.daysById[dayId] case final day?) day,
    ];

    return OcptShootingPlanGrids(
      slotColumns: [
        for (final ref in slotColumnRefs)
          OcptShootingPlanGridColumn(
            dayId: ref.day.id,
            dayNumber: ref.day.dayNumber,
            slotId: ref.slot.id,
            slotLabel: ref.slot.label,
          ),
      ],
      dayColumns: dayColumns,
      locationsRows: _locationsRowsOf(
        plan: plan,
        columns: slotColumnRefs,
        presenceMark: presenceMark,
        persoLabel: persoLabel,
        emptyValue: emptyValue,
      ),
      sequencesRows: _sequencesRowsOf(
        plan: plan,
        columns: slotColumnRefs,
        sequenceRowPrefix: sequenceRowPrefix,
      ),
      peopleRows: _peopleRowsOf(
        plan: plan,
        columns: slotColumnRefs,
        presenceMark: presenceMark,
        crewPositionLabelById: crewPositionLabelById,
      ),
      elementsRows: _elementsRowsOf(
        plan: plan,
        dayColumns: dayColumns,
        presenceMark: presenceMark,
        elementCategoryLabels: elementCategoryLabels,
      ),
    );
  }

  /// One `(day, slot)` pair per live slot of every live day of [dayIds] that carries at least one,
  /// in the order given — the raw material [slotColumns] is built from, and every one of the three
  /// slot-shaped grids' own rows are resolved against. A day with no live slot at all contributes no
  /// pair, since its own slot loop below simply runs zero times.
  static List<({OcptShootingDay day, OcptShootingSlot slot})> _liveSlotColumnsOf(
    OcptSchedulePlanSnapshot plan,
    List<String> dayIds,
  ) {
    final columns = <({OcptShootingDay day, OcptShootingSlot slot})>[];
    for (final dayId in dayIds) {
      final day = plan.schedule.daysById[dayId];
      if (day == null) {
        continue;
      }
      for (final slot in plan.schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[]) {
        columns.add((day: day, slot: slot));
      }
    }
    return columns;
  }

  /// The locations grid's own rows — see [OcptShootingPlanGrids.locationsRows]'s own doc comment.
  static List<OcptShootingPlanGridRow> _locationsRowsOf({
    required OcptSchedulePlanSnapshot plan,
    required List<({OcptShootingDay day, OcptShootingSlot slot})> columns,
    required String presenceMark,
    required String persoLabel,
    required String emptyValue,
  }) {
    final seenLocationIds = <String>{};
    final locationIds = <String>[];
    for (final column in columns) {
      final locationId = column.slot.locationId;
      if (locationId == null || !seenLocationIds.add(locationId)) {
        continue;
      }
      locationIds.add(locationId);
    }

    final rows = <OcptShootingPlanGridRow>[];
    for (final locationId in locationIds) {
      final location = plan.locationById[locationId];
      final name = location == null || location.name.trim().isEmpty ? emptyValue : location.name.trim();

      rows.add(
        OcptShootingPlanGridRow(
          label: name,
          isBold: true,
          cells: [
            for (final column in columns)
              if (column.slot.locationId != locationId)
                ""
              else
                _locationSetCellOf(plan: plan, slot: column.slot, presenceMark: presenceMark),
          ],
        ),
      );
      rows.add(
        OcptShootingPlanGridRow(
          label: persoLabel,
          isIndented: true,
          isMuted: true,
          cells: [
            for (final column in columns)
              if (column.slot.locationId != locationId)
                ""
              else
                _slotPersonFirstNames(plan, column.slot).join(", "),
          ],
        ),
      );
    }
    return rows;
  }

  /// [slot]'s own set name, or [presenceMark] while it names none.
  static String _locationSetCellOf({
    required OcptSchedulePlanSnapshot plan,
    required OcptShootingSlot slot,
    required String presenceMark,
  }) {
    final setId = slot.setId;
    final setName = setId == null ? null : plan.setById[setId]?.name.trim();
    return (setName != null && setName.isNotEmpty) ? setName : presenceMark;
  }

  /// The sequences grid's own rows — see [OcptShootingPlanGrids.sequencesRows]'s own doc comment.
  static List<OcptShootingPlanGridRow> _sequencesRowsOf({
    required OcptSchedulePlanSnapshot plan,
    required List<({OcptShootingDay day, OcptShootingSlot slot})> columns,
    required String sequenceRowPrefix,
  }) {
    final dayIds = <String>{for (final column in columns) column.day.id};
    final shotsBySceneIdBySlotId = <String, Map<String, List<OcptShot>>>{};

    for (final dayId in dayIds) {
      for (final block in plan.schedule.blocksByDayId[dayId] ?? const <OcptShootingDayBlock>[]) {
        if (block.kind != OcptShootingBlockKind.shot || block.shotId == null) {
          continue;
        }
        final shot = plan.shotById(block.shotId!);
        if (shot == null || shot.sceneId == null) {
          continue;
        }
        ((shotsBySceneIdBySlotId[shot.sceneId!] ??= <String, List<OcptShot>>{})[block.slotId] ??= <OcptShot>[])
            .add(shot);
      }
    }

    final sequencesBySceneId = {
      for (final sequence in plan.shotList?.sequences ?? const [])
        if (sequence is OcptSceneShotSequence) sequence.sceneId: sequence,
    };

    final rows = <OcptShootingPlanGridRow>[];
    for (final sequence in sequencesBySceneId.values) {
      final bySlotId = shotsBySceneIdBySlotId[sequence.sceneId];
      if (bySlotId == null || bySlotId.isEmpty) {
        continue;
      }
      rows.add(
        OcptShootingPlanGridRow(
          label: "$sequenceRowPrefix ${sequence.displaySceneNumber}",
          isBold: true,
          cells: [
            for (final column in columns)
              if (bySlotId[column.slot.id] case final shots? when shots.isNotEmpty)
                (shots.map(_shotRankOf).toList()..sort()).join(",")
              else
                "",
          ],
        ),
      );
    }
    return rows;
  }

  /// [shot]'s own per-scene rank half of its `<sceneNumber>/<rank>` display code.
  ///
  /// Duplicates `ocptShotRankOf` (`lib/managers/export/services/ocpt_schedule_pdf_shared.dart`)
  /// rather than importing it: a `lib/models/` file must not depend on the manager layer that
  /// consumes it (dependencies never reference their dependents), and this is a one-line string
  /// split with no risk of the two rules ever disagreeing — the same trade
  /// `OcptSchedulePlanSnapshot._unavailabilityCoversDate` already makes for its own tiny duplicated
  /// check.
  static String _shotRankOf(OcptShot shot) => shot.code.contains("/") ? shot.code.split("/").last : shot.code;

  /// The crew and cast grid's own rows — see [OcptShootingPlanGrids.peopleRows]'s own doc comment.
  static List<OcptShootingPlanGridRow> _peopleRowsOf({
    required OcptSchedulePlanSnapshot plan,
    required List<({OcptShootingDay day, OcptShootingSlot slot})> columns,
    required String presenceMark,
    required Map<String, String> crewPositionLabelById,
  }) {
    final heldPositionIds = <String>{};
    final castRoleIds = <String>{};
    for (final column in columns) {
      for (final member in column.slot.crew) {
        if (member.positionId.isNotEmpty) {
          heldPositionIds.add(member.positionId);
        }
      }
      for (final member in column.slot.cast) {
        castRoleIds.add(member.roleId);
      }
    }

    final rows = <OcptShootingPlanGridRow>[];
    for (final position in ocptCrewPositions) {
      if (!heldPositionIds.contains(position.id)) {
        continue;
      }
      rows.add(
        OcptShootingPlanGridRow(
          label: crewPositionLabelById[position.id] ?? "",
          isBold: true,
          cells: [
            for (final column in columns)
              _crewCellOf(plan: plan, slot: column.slot, positionId: position.id),
          ],
        ),
      );
    }

    final orderedRoles = [for (final role in plan.roles) if (castRoleIds.contains(role.id)) role]
      ..sort((a, b) => a.number.compareTo(b.number));
    for (final role in orderedRoles) {
      rows.add(
        OcptShootingPlanGridRow(
          label: "${role.number} · ${role.name}",
          cells: [
            for (final column in columns)
              _castCellOf(plan: plan, slot: column.slot, role: role, presenceMark: presenceMark),
          ],
        ),
      );
    }
    return rows;
  }

  /// The first names of every distinct person of [slot] holding [positionId], sorted and joined.
  static String _crewCellOf({
    required OcptSchedulePlanSnapshot plan,
    required OcptShootingSlot slot,
    required String positionId,
  }) {
    final names = <String>{};
    for (final member in slot.crew) {
      if (member.positionId != positionId) {
        continue;
      }
      final first = plan.personById[member.personId]?.firstName.trim();
      if (first != null && first.isNotEmpty) {
        names.add(first);
      }
    }
    final sorted = names.toList()..sort();
    return sorted.join(", ");
  }

  /// [role]'s own actor's first name against [slot], or [presenceMark] while [slot] convokes it
  /// uncast, or the empty string while [slot] does not convoke it at all.
  static String _castCellOf({
    required OcptSchedulePlanSnapshot plan,
    required OcptShootingSlot slot,
    required OcptRole role,
    required String presenceMark,
  }) {
    if (!slot.cast.any((member) => member.roleId == role.id)) {
      return "";
    }
    final actorFirstName = role.personId == null ? null : plan.personById[role.personId]?.firstName.trim();
    return (actorFirstName != null && actorFirstName.isNotEmpty) ? actorFirstName : presenceMark;
  }

  /// Every distinct first name of a person linked to [slot], crew and cast alike (a cast role's
  /// actor read through `roles.personId`), sorted.
  static List<String> _slotPersonFirstNames(OcptSchedulePlanSnapshot plan, OcptShootingSlot slot) {
    final names = <String>{};
    for (final member in slot.crew) {
      final first = plan.personById[member.personId]?.firstName.trim();
      if (first != null && first.isNotEmpty) {
        names.add(first);
      }
    }
    for (final member in slot.cast) {
      final role = plan.roleById[member.roleId];
      final personId = role?.personId;
      final first = personId == null ? null : plan.personById[personId]?.firstName.trim();
      if (first != null && first.isNotEmpty) {
        names.add(first);
      }
    }
    final sorted = names.toList()..sort();
    return sorted;
  }

  /// The elements grid's own rows — see [OcptShootingPlanGrids.elementsRows]'s own doc comment.
  static List<OcptShootingPlanElementsGridRow> _elementsRowsOf({
    required OcptSchedulePlanSnapshot plan,
    required List<OcptShootingDay> dayColumns,
    required String presenceMark,
    required Map<OcptElementCategory, String> elementCategoryLabels,
  }) {
    final sceneIdsByDayId = {for (final day in dayColumns) day.id: plan.sceneIdsOfDay(day.id)};
    final playedSceneIds = {for (final sceneIds in sceneIdsByDayId.values) ...sceneIds};

    final elementsByCategory = <OcptElementCategory, List<OcptElement>>{};
    for (final element in plan.elements) {
      if (!element.sceneLinks.any((link) => playedSceneIds.contains(link.sceneId))) {
        continue;
      }
      (elementsByCategory[element.category] ??= <OcptElement>[]).add(element);
    }

    final rows = <OcptShootingPlanElementsGridRow>[];
    for (final category in OcptElementCategory.values) {
      final elements = elementsByCategory[category];
      if (elements == null || elements.isEmpty) {
        continue;
      }
      elements.sort((a, b) => a.name.compareTo(b.name));
      rows.add(OcptShootingPlanElementsGridCategoryBand(label: elementCategoryLabels[category] ?? ""));
      for (final element in elements) {
        rows.add(
          OcptShootingPlanElementsGridElementRow(
            label: "${element.code} · ${element.name}",
            cells: [
              for (final day in dayColumns)
                if (element.sceneLinks.any(
                  (link) => (sceneIdsByDayId[day.id] ?? const <String>{}).contains(link.sceneId),
                ))
                  presenceMark
                else
                  "",
            ],
          ),
        );
      }
    }
    return rows;
  }

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShootingPlanGrids(slotColumns: ${slotColumns.length}, dayColumns: ${dayColumns.length})";

  /// Object properties
  @override
  List<Object?> get props => [slotColumns, dayColumns, locationsRows, sequencesRows, peopleRows, elementsRows];
}

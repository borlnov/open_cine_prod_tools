// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_crew_positions.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_avatar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_crew_position_prefill.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/utils/ocpt_schedule_alerts.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';

/// The width of the matrix's own frozen first column — wide enough for the longest crew position
/// label the `ocptCrewPositions` catalogue prints, department headings included.
const double _ocptPositionsMatrixLabelColumnWidth = 168;

/// The width every slot column claims — narrow, since a cell only ever carries a pair of initials
/// or the short "lost" marker, never a name.
const double _ocptPositionsMatrixSlotColumnWidth = 84;

/// The header row's own height — tall enough for its three stacked lines (the day tag, the slot's
/// own label, its resolved start).
const double _ocptPositionsMatrixHeaderRowHeight = 48;

/// A department heading band's own height.
const double _ocptPositionsMatrixGroupHeaderHeight = 26;

/// A position row's own height — tall enough for the small avatar a held cell draws.
const double _ocptPositionsMatrixRowHeight = 38;

/// The radius of the circle a held cell draws its holder's initials in.
const double _ocptPositionsMatrixCellAvatarRadius = 11;

/// The opacity a lost cell's own error-coloured fill is drawn at.
const double _ocptPositionsMatrixLostCellFillAlpha = 0.18;

/// One column of [OcptSchedulePositionsMatrix]: one live slot, wherever it falls in the shoot —
/// [dayId] and [slot] together are what a cell is resolved against, [dayTag] and [startMinute]
/// are what the column's own header prints.
class _OcptPositionsMatrixColumn {
  /// The day this column's own slot belongs to.
  final String dayId;

  /// [dayId]'s own printed rank (`D3`/`J3`), already localized.
  final String dayTag;

  /// The slot this column stands for, its live crew nested — what every cell of this column reads.
  final OcptShootingSlot slot;

  /// [slot]'s own **resolved** start minute (ADR 0015, amended a second time), or null while it has
  /// nothing placed in it yet — never a stored column, read off the caller's own
  /// `OcptShootingDayTimelines`.
  final int? startMinute;

  /// Class constructor
  const _OcptPositionsMatrixColumn({
    required this.dayId,
    required this.dayTag,
    required this.slot,
    required this.startMinute,
  });
}

/// One row of [OcptSchedulePositionsMatrix]: one crew position held by somebody, somewhere in the
/// shoot — a position nobody ever holds names no row at all (see the class doc comment).
class _OcptPositionsMatrixRow {
  /// This row's own identity — the pair `(positionId, customLabel)` [OcptCrewPositionRef] already
  /// models one with.
  final OcptCrewPositionRef position;

  /// This row's own display label.
  final String label;

  /// Class constructor
  const _OcptPositionsMatrixRow({required this.position, required this.label});
}

/// One department group of [OcptSchedulePositionsMatrix]'s own rows, headed by [heading].
class _OcptPositionsMatrixGroup {
  /// This group's own heading, already localized.
  final String heading;

  /// This group's own rows, never empty (an empty group is never built at all).
  final List<_OcptPositionsMatrixRow> rows;

  /// Class constructor
  const _OcptPositionsMatrixGroup({required this.heading, required this.rows});
}

/// The schedule mode's positions view: who holds which crew position, slot by slot, across the
/// whole shoot — the third centre view, beside the day and the agenda
/// (`OcptScheduleCentreView.positions`).
///
/// **Rows** are crew positions **held by somebody on at least one live slot of the whole
/// schedule** — a position nobody has ever convoked prints nothing, exactly as an unused department
/// heading is never shown either. A row's identity is the pair `(positionId, customLabel)`
/// [OcptCrewPositionRef] and `lib/utils/ocpt_crew_position_prefill.dart` already model one with.
/// Catalogue rows are grouped by [OcptCrewDepartment] in the catalogue's own declared order; a
/// free-label position (`positionId` empty) or one naming a position retired from the catalogue
/// (department unresolved) has no department of its own, so every such row is grouped together,
/// under [Tr.scheduleSlotUnassignedDepartmentLabel] — the exact heading `_OcptScheduleCrewSection`
/// already shows a slot card's own crew row under for the same reason — sorted alphabetically by
/// its own label for a deterministic reading, there being no natural order left to fall back on.
///
/// **Columns** are one per live slot, in day order (`days` is already `dayNumber` order) then the
/// day's own slot order (`sortKey` order) — a column's own header prints the day tag, the slot's
/// own label and its **resolved** start (never a stored column, ADR 0015 as amended a second time).
/// Clicking a header selects that day and opens the day view, exactly as a week or a month cell
/// already does.
///
/// **A cell** is that position's holder on that slot — their initials in their own avatar colour,
/// their full name in a tooltip — or, where [OcptSchedulePositionLostAlert] already says the
/// position was held on the slot immediately before and dropped on this one, an error-coloured
/// marker naming who held it before. **That rule is read from [lostPositionAlerts], never
/// recomputed here**: `OcptSchedulePlanSnapshot.alerts` is the one place rule 4 is implemented, and
/// a second implementation is exactly how this matrix and the alerts panel would come to disagree
/// about what "lost" means. A position held by nobody and never lost on that slot prints a plain
/// em dash.
///
/// Entirely **read-only**, like `OcptScheduleConvocationsPanel`: every figure here is joined or
/// computed by the caller, and the only callback this widget takes ([onDayOpenRequested]) is a
/// selection, which writes nothing to the project database. It therefore takes no `isReadOnly` flag
/// and draws identically whether the working copy or a version preview is on screen.
class OcptSchedulePositionsMatrix extends StatelessWidget {
  /// Every live day, in `dayNumber` order — one group of columns per entry.
  final List<OcptShootingDay> days;

  /// Every day's own live slots, keyed by day id, each list in `sortKey` order — the columns a
  /// day's own group is split into.
  final Map<String, List<OcptShootingSlot>> slotsByDayId;

  /// The whole address book, keyed by id — what a cell's own holder (or a lost cell's own previous
  /// holder) is resolved to a name and an avatar colour through.
  final Map<String, OcptPerson> personById;

  /// Resolves a day id to its own computed timelines (ADR 0015, as amended), or null while it has
  /// nothing placed — what a column's own header reads its resolved start off.
  final OcptShootingDayTimelines? Function(String dayId) timelinesOfDay;

  /// Every [OcptSchedulePositionLostAlert] `OcptSchedulePlanSnapshot.alerts` raised over the whole
  /// schedule — already filtered to that one kind by the caller, since this widget has no business
  /// reading the other eight rules.
  final List<OcptSchedulePositionLostAlert> lostPositionAlerts;

  /// Called with a column's own day id when its header is clicked, selecting that day and opening
  /// the day view — the same "open this day" gesture the strip, the week and the month agendas
  /// already answer.
  final ValueChanged<String> onDayOpenRequested;

  /// Class constructor
  const OcptSchedulePositionsMatrix({
    super.key,
    required this.days,
    required this.slotsByDayId,
    required this.personById,
    required this.timelinesOfDay,
    required this.lostPositionAlerts,
    required this.onDayOpenRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final columns = _buildColumns(tr);
    final groups = _buildGroups(tr, columns);

    if (groups.isEmpty) {
      return OcptWorkspaceEmptyMode(
        icon: Icons.badge_outlined,
        message: tr.schedulePositionsMatrixEmptyHint,
      );
    }

    // `OcptScheduleAlert.dayId` is nullable on the base class (null only ever means
    // `OcptScheduleRoleUncastAlert`), but rule 4 always sets one — the `!` is that guarantee, not
    // an assumption.
    final lostPersonIdByCell = {
      for (final alert in lostPositionAlerts)
        (alert.dayId!, alert.slotId, alert.position): alert.personId,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            tr.schedulePositionsMatrixLegend,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(ocptRadiusMedium),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabelColumn(context, tr, groups),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _buildCellsColumn(context, tr, columns, groups, lostPersonIdByCell),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// One column per live slot, in day order then the day's own slot order — see the class doc
  /// comment.
  List<_OcptPositionsMatrixColumn> _buildColumns(Tr tr) => [
    for (final day in days)
      for (final slot in slotsByDayId[day.id] ?? const <OcptShootingSlot>[])
        _OcptPositionsMatrixColumn(
          dayId: day.id,
          dayTag: ocptScheduleDayTagLabel(tr, day.dayNumber),
          slot: slot,
          startMinute: timelinesOfDay(day.id)?.bySlotId[slot.id]?.startMinute,
        ),
  ];

  /// Every department group holding at least one row, in [OcptCrewDepartment.values] order, then
  /// the free-label/unrecognised group last — see the class doc comment for the whole rule.
  List<_OcptPositionsMatrixGroup> _buildGroups(Tr tr, List<_OcptPositionsMatrixColumn> columns) {
    final held = <OcptCrewPositionRef>{};
    for (final column in columns) {
      for (final member in column.slot.crew) {
        final ref = OcptCrewPositionRef(positionId: member.positionId, customLabel: member.customLabel);
        if (!ref.isEmpty) {
          held.add(ref);
        }
      }
    }

    final groups = <_OcptPositionsMatrixGroup>[];
    for (final department in OcptCrewDepartment.values) {
      final rows = <_OcptPositionsMatrixRow>[];
      for (final position in ocptCrewPositions) {
        if (position.department != department) {
          continue;
        }
        final ref = OcptCrewPositionRef(positionId: position.id, customLabel: "");
        if (held.remove(ref)) {
          rows.add(_OcptPositionsMatrixRow(position: ref, label: ocptCrewPositionLabel(tr, position.id)));
        }
      }
      if (rows.isNotEmpty) {
        groups.add(_OcptPositionsMatrixGroup(heading: ocptCrewDepartmentLabel(tr, department), rows: rows));
      }
    }

    // Whatever is left of `held` names either a free label (`positionId` empty) or a position this
    // build no longer recognises (a retired catalogue entry) — both read as "no department of its
    // own" and land in the one trailing group, alphabetised for a deterministic reading.
    if (held.isNotEmpty) {
      final leftoverRows = [
        for (final ref in held)
          _OcptPositionsMatrixRow(
            position: ref,
            label: ref.positionId.isEmpty ? ref.customLabel : ocptCrewPositionLabel(tr, ref.positionId),
          ),
      ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
      groups.add(
        _OcptPositionsMatrixGroup(heading: tr.scheduleSlotUnassignedDepartmentLabel, rows: leftoverRows),
      );
    }

    return groups;
  }

  /// The frozen first column: the `Position` header, then every group's own heading and row
  /// labels — never scrolled horizontally, so it stays readable however wide the shoot runs.
  Widget _buildLabelColumn(BuildContext context, Tr tr, List<_OcptPositionsMatrixGroup> groups) {
    final theme = Theme.of(context);

    return SizedBox(
      width: _ocptPositionsMatrixLabelColumnWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: _ocptPositionsMatrixHeaderRowHeight,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
            ),
            child: Text(
              tr.schedulePositionsMatrixPositionColumnHeader.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          for (final group in groups) ...[
            Container(
              height: _ocptPositionsMatrixGroupHeaderHeight,
              width: double.infinity,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              color: theme.colorScheme.surfaceContainerHigh,
              child: Text(
                group.heading,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            for (final row in group.rows)
              Container(
                height: _ocptPositionsMatrixRowHeight,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
                ),
                child: Text(
                  row.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// The scrollable right-hand side: one header cell per column, then, mirroring
  /// [_buildLabelColumn] row for row, each group's own blank heading band and each row's own cells
  /// — the two sides sharing the exact same row heights is what keeps them aligned with no
  /// `IntrinsicHeight` needed.
  Widget _buildCellsColumn(
    BuildContext context,
    Tr tr,
    List<_OcptPositionsMatrixColumn> columns,
    List<_OcptPositionsMatrixGroup> groups,
    Map<(String, String, OcptCrewPositionRef), String> lostPersonIdByCell,
  ) {
    final theme = Theme.of(context);
    final totalWidth = columns.length * _ocptPositionsMatrixSlotColumnWidth;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (final column in columns) _buildColumnHeader(context, tr, column)],
        ),
        for (final group in groups) ...[
          Container(height: _ocptPositionsMatrixGroupHeaderHeight, width: totalWidth, color: theme.colorScheme.surfaceContainerHigh),
          for (final row in group.rows)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final column in columns)
                  _buildCell(context, tr, column, row, lostPersonIdByCell),
              ],
            ),
        ],
      ],
    );
  }

  /// One column's own header: its day tag, its slot's own label and its resolved start, stacked —
  /// clicking it opens that day.
  Widget _buildColumnHeader(BuildContext context, Tr tr, _OcptPositionsMatrixColumn column) {
    final theme = Theme.of(context);
    final slotLabel = column.slot.label.isEmpty ? tr.scheduleInspectorUnnamedSlot : column.slot.label;
    final startLabel = column.startMinute == null ? "—" : ocptFormatDayMinute(column.startMinute!);

    return SizedBox(
      width: _ocptPositionsMatrixSlotColumnWidth,
      height: _ocptPositionsMatrixHeaderRowHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            left: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
        ),
        child: InkWell(
          onTap: () => onDayOpenRequested(column.dayId),
          mouseCursor: ocptClickableCursor,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  column.dayTag,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  slotLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  startLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One cell: [row]'s own position, read off [column]'s own slot — the holder's avatar, the
  /// error-coloured "lost" marker, or a plain em dash, in that order (see the class doc comment).
  Widget _buildCell(
    BuildContext context,
    Tr tr,
    _OcptPositionsMatrixColumn column,
    _OcptPositionsMatrixRow row,
    Map<(String, String, OcptCrewPositionRef), String> lostPersonIdByCell,
  ) {
    final theme = Theme.of(context);

    String? holderId;
    for (final member in column.slot.crew) {
      if (member.positionId == row.position.positionId && member.customLabel == row.position.customLabel) {
        holderId = member.personId;
        break;
      }
    }
    final holder = holderId == null ? null : personById[holderId];

    Widget content;
    if (holder != null) {
      content = Tooltip(
        message: holder.displayName.isEmpty ? tr.resourcesUnnamedPerson : holder.displayName,
        child: Center(
          child: OcptPersonInitialsAvatar(person: holder, radius: _ocptPositionsMatrixCellAvatarRadius),
        ),
      );
    } else {
      final lostPersonId = lostPersonIdByCell[(column.dayId, column.slot.id, row.position)];
      if (lostPersonId != null) {
        final previousHolder = personById[lostPersonId];
        final previousHolderName = previousHolder == null || previousHolder.displayName.isEmpty
            ? tr.resourcesUnnamedPerson
            : previousHolder.displayName;
        content = Tooltip(
          message: tr.schedulePositionsMatrixLostCellTooltip(previousHolderName),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: _ocptPositionsMatrixLostCellFillAlpha),
                border: Border.all(color: theme.colorScheme.error),
                borderRadius: BorderRadius.circular(ocptRadiusLarge),
              ),
              child: Text(
                tr.schedulePositionsMatrixLostCellLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ),
        );
      } else {
        content = Center(
          child: Text(
            "—",
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        );
      }
    }

    return SizedBox(
      width: _ocptPositionsMatrixSlotColumnWidth,
      height: _ocptPositionsMatrixRowHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            left: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
        ),
        child: content,
      ),
    );
  }
}

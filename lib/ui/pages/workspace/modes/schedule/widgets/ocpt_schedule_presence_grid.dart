// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/types/ocpt_presence_code.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_avatar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_schedule_alerts.dart';

/// The width of the grid's own frozen first column — wide enough for a name and a "postes" subtitle
/// line.
const double _ocptPresenceGridLabelColumnWidth = 208;

/// The width every day column claims — narrow, since a cell only ever carries a single-letter pill.
const double _ocptPresenceGridDayColumnWidth = 56;

/// The width of the trailing total column.
const double _ocptPresenceGridTotalColumnWidth = 64;

/// The header row's own height — tall enough for its two stacked lines (the day tag, the date).
const double _ocptPresenceGridHeaderRowHeight = 44;

/// A person row's own height — tall enough for the name and the "postes" subtitle beneath it.
const double _ocptPresenceGridRowHeight = 44;

/// The radius of a cell's own pill.
const double _ocptPresenceGridPillRadius = 10;

/// The opacity a pill's own fill is drawn at, its border staying opaque.
const double _ocptPresenceGridPillFillAlpha = 0.16;

/// One column of [OcptSchedulePresenceGrid]'s own scrollable area: one live day, wherever it falls
/// in the shoot.
class _OcptPresenceGridDayColumn {
  /// The day this column stands for.
  final OcptShootingDay day;

  /// [day]'s own printed rank (`D3`/`J3`), already localized.
  final String dayTag;

  /// [day]'s own date, formatted short — a column this narrow has no room for more.
  final String dateLabel;

  /// Class constructor
  const _OcptPresenceGridDayColumn({required this.day, required this.dayTag, required this.dateLabel});
}

/// The schedule mode's presence view: who is working or unavailable, day by day, across the whole
/// shoot — the fourth and last centre view, after the day, the agenda and the positions matrix
/// (`OcptScheduleCentreView.presence`).
///
/// **Rows** are the **whole address book**, [people], in the order it is loaded — every person the
/// project knows about, whether or not they are convoked anywhere yet: a project's crew and cast are
/// read from there, not from who happens to hold a slot. Each row's own subtitle is a discreet line
/// of what that person is on this film — their declared `person_positions`, localized, then the
/// names of the roles cast to them, joined — the same "postes" reading `OcptPeopleList`'s own row
/// already gives, with roles added.
///
/// **Columns** are one per live [days], in `dayNumber` order, headed by the day tag
/// (`ocptScheduleDayTagLabel`) and a short date; clicking a header selects that day and opens the
/// day view ([onDayOpenRequested]), exactly as the positions matrix's own header does. A trailing
/// **Total** column counts, per row, how many of [days] that person's own [presenceCellOf] reads as
/// [OcptPresenceCode.working].
///
/// **A cell** is [presenceCellOf]'s own answer for that (day, person) pair — see
/// `OcptSchedulePlanSnapshot.presenceCellOf`, entirely computed: [OcptPresenceCode.working] or
/// [OcptPresenceCode.unavailable], or null, drawn **blank**, no pill at all — absence of
/// information, never a claim. A cell named by one of [unavailableAlerts]
/// (`OcptSchedulePersonUnavailableAlert`, rule 1 of `lib/utils/ocpt_schedule_alerts.dart`, **read
/// here, never recomputed**) is painted in the error colour whatever its own code, mirroring how
/// `OcptSchedulePositionsMatrix` reads rule 4 through `lostPositionAlerts` rather than re-deriving
/// "lost" on its own — two implementations of one rule is exactly how this grid and the alerts
/// panel would come to disagree.
///
/// **It offers nothing to withhold.** Schema v17 drops `shooting_presences`, the by-hand override a
/// cell's click used to cycle: every code this grid draws is computed, so it joins `Convocations`,
/// the positions matrix and the `Alerts` panel as a view that needs no `isReadOnly` handling at all
/// — it draws identically whether the project is being edited or a version is being previewed.
class OcptSchedulePresenceGrid extends StatelessWidget {
  /// Every live day, in `dayNumber` order — one column per entry.
  final List<OcptShootingDay> days;

  /// The whole address book, in its own order — one row per entry.
  final List<OcptPerson> people;

  /// The whole cast — what a row's own subtitle reads a person's roles off (`roles.personId`).
  final List<OcptRole> roles;

  /// Resolves the effective code of `personId` on `dayId`, or null for a blank cell — delegates to
  /// `OcptSchedulePlanSnapshot.presenceCellOf`.
  final OcptPresenceCode? Function(String dayId, String personId) presenceCellOf;

  /// Every [OcptSchedulePersonUnavailableAlert] `OcptSchedulePlanSnapshot.alerts` raised over the
  /// whole schedule — already filtered to that one kind by the caller, since this widget has no
  /// business reading the other eight rules.
  final List<OcptSchedulePersonUnavailableAlert> unavailableAlerts;

  /// Called with a column's own day id when its header is clicked, selecting that day and opening
  /// the day view — the same "open this day" gesture the strip, the week, the month and the
  /// positions matrix already answer.
  final ValueChanged<String> onDayOpenRequested;

  /// Class constructor
  const OcptSchedulePresenceGrid({
    super.key,
    required this.days,
    required this.people,
    required this.roles,
    required this.presenceCellOf,
    required this.unavailableAlerts,
    required this.onDayOpenRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    if (people.isEmpty) {
      return OcptWorkspaceEmptyMode(
        icon: Icons.groups_outlined,
        message: tr.schedulePresenceGridEmptyHint,
      );
    }

    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.Md(locale);
    final columns = [
      for (final day in days)
        _OcptPresenceGridDayColumn(
          day: day,
          dayTag: ocptScheduleDayTagLabel(tr, day.dayNumber),
          dateLabel: dateFormat.format(day.date),
        ),
    ];

    // `OcptScheduleAlert.dayId` is nullable on the base class (null only ever means
    // `OcptScheduleRoleUncastAlert`), but rule 1 always sets one — the `!` is that guarantee, not an
    // assumption, mirroring `OcptSchedulePositionsMatrix`'s own read of rule 4.
    final conflictCells = <(String, String)>{
      for (final alert in unavailableAlerts) (alert.dayId!, alert.personId),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            tr.schedulePresenceGridLegend,
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
                  _buildLabelColumn(context, tr),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _buildCellsColumn(context, tr, columns, conflictCells),
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

  /// The frozen first column: the header, then every person's own name and subtitle — never
  /// scrolled horizontally, so it stays readable however wide the shoot runs.
  Widget _buildLabelColumn(BuildContext context, Tr tr) {
    final theme = Theme.of(context);

    return SizedBox(
      width: _ocptPresenceGridLabelColumnWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: _ocptPresenceGridHeaderRowHeight,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
            ),
            child: Text(
              tr.schedulePresenceGridPersonColumnHeader.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          for (final person in people) _buildLabelRow(context, tr, person),
        ],
      ),
    );
  }

  /// One row of the frozen first column: [person]'s own avatar, name and "postes" subtitle.
  Widget _buildLabelRow(BuildContext context, Tr tr, OcptPerson person) {
    final theme = Theme.of(context);
    final displayName = person.displayName;
    final name = displayName.isEmpty ? tr.resourcesUnnamedPerson : displayName;
    final subtitle = _subtitleOf(tr, person);

    return Container(
      height: _ocptPresenceGridRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          OcptPersonAvatar(person: person, radius: 12),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: displayName.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// [person]'s own declared positions, localized, then the names of the roles cast to them, joined
  /// — what a row's own subtitle prints. Empty when they hold neither.
  String _subtitleOf(Tr tr, OcptPerson person) {
    final positionLabels = person.positions
        .map(
          (position) => position.positionId.isNotEmpty
              ? ocptCrewPositionLabel(tr, position.positionId)
              : position.customLabel,
        )
        .where((label) => label.isNotEmpty);
    final roleNames = roles
        .where((role) => role.personId == person.id)
        .map((role) => role.name)
        .where((name) => name.isNotEmpty);

    return [...positionLabels, ...roleNames].join(" · ");
  }

  /// The scrollable right-hand side: one header cell per day plus the total header, then, mirroring
  /// [_buildLabelColumn] row for row, each person's own cells and their total — the two sides
  /// sharing the exact same row heights is what keeps them aligned with no `IntrinsicHeight` needed.
  Widget _buildCellsColumn(
    BuildContext context,
    Tr tr,
    List<_OcptPresenceGridDayColumn> columns,
    Set<(String, String)> conflictCells,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final column in columns) _buildColumnHeader(context, column),
          _buildTotalHeader(context, tr),
        ],
      ),
      for (final person in people)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final column in columns) _buildCell(context, tr, column, person, conflictCells),
            _buildTotalCell(context, person),
          ],
        ),
    ],
  );

  /// One column's own header: its day tag over its date, clicking it opens that day.
  Widget _buildColumnHeader(BuildContext context, _OcptPresenceGridDayColumn column) {
    final theme = Theme.of(context);

    return SizedBox(
      width: _ocptPresenceGridDayColumnWidth,
      height: _ocptPresenceGridHeaderRowHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
            left: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
        ),
        child: InkWell(
          onTap: () => onDayOpenRequested(column.day.id),
          mouseCursor: ocptClickableCursor,
          child: Center(
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
                  column.dateLabel,
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

  /// The trailing total column's own header.
  Widget _buildTotalHeader(BuildContext context, Tr tr) {
    final theme = Theme.of(context);

    return Container(
      width: _ocptPresenceGridTotalColumnWidth,
      height: _ocptPresenceGridHeaderRowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          left: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Text(
        tr.schedulePresenceGridTotalColumnHeader.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  /// One cell: [column]'s own day crossed with [person] — a pill reading [presenceCellOf]'s own
  /// code (see the class doc comment), or nothing at all for a blank cell. Plain, unclickable: this
  /// view has nothing left to write.
  Widget _buildCell(
    BuildContext context,
    Tr tr,
    _OcptPresenceGridDayColumn column,
    OcptPerson person,
    Set<(String, String)> conflictCells,
  ) {
    final theme = Theme.of(context);
    final code = presenceCellOf(column.day.id, person.id);
    final hasConflict = conflictCells.contains((column.day.id, person.id));

    Widget content = const SizedBox.shrink();
    if (code != null) {
      final color = hasConflict ? theme.colorScheme.error : ocptPresenceCodeColor(context, code);
      final label = ocptPresenceCodeLabel(tr, code);

      content = Tooltip(
        message: hasConflict
            ? "$label — ${tr.schedulePresenceGridConflictTooltip}"
            : label,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: _ocptPresenceGridPillFillAlpha),
            border: Border.all(color: color, width: hasConflict ? 1.5 : 1),
            borderRadius: BorderRadius.circular(_ocptPresenceGridPillRadius),
          ),
          child: Text(
            ocptPresenceCodeLetterLabel(tr, code),
            style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: color),
          ),
        ),
      );
    }

    return SizedBox(
      width: _ocptPresenceGridDayColumnWidth,
      height: _ocptPresenceGridRowHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            left: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
        ),
        child: Center(child: content),
      ),
    );
  }

  /// [person]'s own trailing total cell: how many of [days] their own effective cell reads
  /// [OcptPresenceCode.working].
  Widget _buildTotalCell(BuildContext context, OcptPerson person) {
    final theme = Theme.of(context);
    final workingDayCount = days
        .where((day) => presenceCellOf(day.id, person.id) == OcptPresenceCode.working)
        .length;

    return Container(
      width: _ocptPresenceGridTotalColumnWidth,
      height: _ocptPresenceGridRowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          left: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Text(
        "$workingDayCount",
        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

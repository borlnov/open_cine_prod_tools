// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';

/// The width of the leading gutter every row starts with, carrying the ⚠ of a shot that needs
/// checking.
const double _gutterWidth = 14;

/// The horizontal space left between two columns.
const double _columnGap = 10;

/// The width of the accent bar painted down the left edge of the selected row.
const double _selectionBarWidth = 2;

/// One column of the shot list table: what it reads off a shot, how wide it wants to be, and how
/// it renders.
///
/// Declared in the order the table lays them out, which interleaves the always-shown columns with
/// the optional ones ([optionalColumn] is null exactly for the always-shown ones) so that, say,
/// `Set` sits next to the shot size it qualifies rather than being pushed to the end of the row.
enum OcptShotListTableColumn {
  /// The derived `<scene number>/<rank>` code.
  shot(minWidth: 64, flex: 0),

  /// The characters attached to the shot.
  characters(minWidth: 120, flex: 1),

  /// The scene's set, read from the sequence rather than the shot.
  set(optionalColumn: OcptShotListColumn.set, minWidth: 130, flex: 1, wraps: true),

  /// The shot size ("valeur de plan").
  shotSize(minWidth: 120, flex: 2, wraps: true),

  /// The framing and composition.
  framing(minWidth: 160, flex: 3, wraps: true),

  /// The camera move.
  cameraMove(minWidth: 140, flex: 2, wraps: true),

  /// The lens/focal length.
  lens(optionalColumn: OcptShotListColumn.lens, minWidth: 90, flex: 0),

  /// The recording format and frame rate.
  recordingFormat(optionalColumn: OcptShotListColumn.recordingFormat, minWidth: 110, flex: 0),

  /// The estimated duration, rendered `m:ss`.
  duration(
    optionalColumn: OcptShotListColumn.duration,
    minWidth: 74,
    flex: 0,
    alignment: TextAlign.right,
  ),

  /// The number of planned takes.
  takes(
    optionalColumn: OcptShotListColumn.takes,
    minWidth: 56,
    flex: 0,
    alignment: TextAlign.right,
  ),

  /// The sound notes.
  sound(optionalColumn: OcptShotListColumn.sound, minWidth: 110, flex: 1),

  /// The mean of the four difficulty axes.
  difficulty(minWidth: 56, flex: 0, alignment: TextAlign.right),

  /// The shooting day the shot is planned for.
  shootingDay(optionalColumn: OcptShotListColumn.shootingDay, minWidth: 110, flex: 0),

  /// The shooting status.
  status(optionalColumn: OcptShotListColumn.status, minWidth: 90, flex: 0);

  /// The optional column this one is toggled by, or null when the column is always shown.
  final OcptShotListColumn? optionalColumn;

  /// The width this column never shrinks below.
  final double minWidth;

  /// How much of the table's leftover width this column takes, relative to its siblings; 0 for a
  /// column that always stays at [minWidth].
  final int flex;

  /// Whether this column's cells wrap onto several lines rather than being ellipsised on one.
  final bool wraps;

  /// How this column's cells are aligned inside their width.
  final TextAlign alignment;

  /// Class constructor
  const OcptShotListTableColumn({
    this.optionalColumn,
    required this.minWidth,
    required this.flex,
    this.wraps = false,
    this.alignment = TextAlign.left,
  });

  /// The columns to lay out given the [visibleColumns] the user toggled on: every always-shown
  /// column, plus the optional ones currently visible.
  static List<OcptShotListTableColumn> visibleIn(Set<OcptShotListColumn> visibleColumns) => [
    for (final column in OcptShotListTableColumn.values)
      if (column.optionalColumn == null || visibleColumns.contains(column.optionalColumn))
        column,
  ];

  /// This column's header label.
  String label(Tr tr) {
    final optionalColumn = this.optionalColumn;
    if (optionalColumn != null) {
      return ocptShotListColumnLabel(tr, optionalColumn);
    }

    return switch (this) {
      OcptShotListTableColumn.shot => tr.shotListColumnShot,
      OcptShotListTableColumn.characters => tr.shotListColumnCharacters,
      OcptShotListTableColumn.shotSize => tr.shotListColumnShotSize,
      OcptShotListTableColumn.framing => tr.shotListColumnFraming,
      OcptShotListTableColumn.cameraMove => tr.shotListColumnCameraMove,
      OcptShotListTableColumn.difficulty => tr.shotListColumnDifficulty,
      // Every remaining value carries a non-null `optionalColumn` and returned above.
      _ => "",
    };
  }

  /// The text this column shows for [shot], whose sequence has the heading [sequenceHeading].
  String valueFor(BuildContext context, OcptShot shot, String sequenceHeading) => switch (this) {
    OcptShotListTableColumn.shot => shot.code,
    OcptShotListTableColumn.characters => shot.characters.isEmpty
        ? ocptShotListEmptyValue
        : shot.characters.join(", "),
    OcptShotListTableColumn.set => sequenceHeading,
    OcptShotListTableColumn.shotSize => ocptShotFieldOrDash(shot.shotSize),
    OcptShotListTableColumn.framing => ocptShotFieldOrDash(shot.framing),
    OcptShotListTableColumn.cameraMove => ocptShotFieldOrDash(shot.cameraMove),
    OcptShotListTableColumn.lens => ocptShotFieldOrDash(shot.lens),
    OcptShotListTableColumn.recordingFormat => ocptShotFieldOrDash(shot.recordingFormat),
    OcptShotListTableColumn.duration => ocptFormatShotDuration(shot.estimatedDurationMs),
    OcptShotListTableColumn.takes => shot.plannedTakes?.toString() ?? ocptShotListEmptyValue,
    OcptShotListTableColumn.sound => ocptShotFieldOrDash(shot.sound),
    OcptShotListTableColumn.difficulty => ocptFormatShotDifficulty(context, shot.averageDifficulty),
    OcptShotListTableColumn.shootingDay => ocptShotFieldOrDash(shot.shootingDay),
    OcptShotListTableColumn.status => ocptShotStatusLabel(Tr.of(context), shot.status),
  };
}

/// The shot list's centre table: one read-only row per shot of the selected sequence.
///
/// Read-only by design: the table is the dense synthesis a director reads at a glance, and every
/// edit happens in the right dock's inspector instead — there is no inline cell editing and no
/// keyboard grid navigation. Clicking a row only selects the shot, which is what opens that
/// inspector.
///
/// The table never makes the page scroll horizontally: its own [SingleChildScrollView] carries
/// the overflow whenever the visible columns need more room than the centre area has, while a
/// wider centre area is shared out between the columns that declared a flex.
class OcptShotListTable extends StatelessWidget {
  /// The shots to list, in display order.
  final List<OcptShot> shots;

  /// The heading of the sequence these shots belong to, shown by the `Set` column.
  ///
  /// A sequence *is* a screenplay scene, so what identifies its set is the scene's own heading,
  /// read from the scene index and never duplicated onto the shots themselves; the table takes it
  /// from its caller for that reason.
  final String sequenceHeading;

  /// The optional columns currently shown.
  final Set<OcptShotListColumn> visibleColumns;

  /// The id of the selected shot, or null if none is.
  final String? selectedShotId;

  /// Called with a shot's id when its row is clicked.
  final ValueChanged<String> onShotSelected;

  /// Class constructor
  const OcptShotListTable({
    super.key,
    required this.shots,
    required this.sequenceHeading,
    required this.visibleColumns,
    required this.selectedShotId,
    required this.onShotSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final columns = OcptShotListTableColumn.visibleIn(visibleColumns);

    if (shots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          tr.shotListShotsEmptyHint,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final widths = _resolveWidths(columns, constraints.maxWidth);
        final tableWidth =
            _selectionBarWidth +
            _gutterWidth +
            widths.fold<double>(0, (total, width) => total + width + _columnGap);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderRow(columns: columns, widths: widths),
                Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
                Expanded(
                  child: ListView.builder(
                    itemCount: shots.length,
                    itemBuilder: (context, index) => OcptShotListRow(
                      shot: shots[index],
                      sequenceHeading: sequenceHeading,
                      columns: columns,
                      widths: widths,
                      isSelected: shots[index].id == selectedShotId,
                      onTap: () => onShotSelected(shots[index].id),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Resolves the pixel width of each of [columns] inside an area [availableWidth] wide.
  ///
  /// Every column starts at its own minimum; whatever room is left over is shared between the
  /// columns declaring a flex, in proportion to it. When the minimums alone already overflow, no
  /// column shrinks — the table simply becomes wider than the area and scrolls horizontally
  /// inside its own scroll view.
  List<double> _resolveWidths(List<OcptShotListTableColumn> columns, double availableWidth) {
    final fixedWidth =
        _selectionBarWidth +
        _gutterWidth +
        columns.fold<double>(0, (total, column) => total + column.minWidth + _columnGap);
    final totalFlex = columns.fold<int>(0, (total, column) => total + column.flex);
    final extraWidth = availableWidth - fixedWidth;

    if (totalFlex == 0 || extraWidth <= 0) {
      return [for (final column in columns) column.minWidth];
    }

    return [
      for (final column in columns) column.minWidth + extraWidth * column.flex / totalFlex,
    ];
  }
}

/// The table's fixed header row: the column labels, upper-cased and muted.
class _HeaderRow extends StatelessWidget {
  /// The columns laid out, in order.
  final List<OcptShotListTableColumn> columns;

  /// The resolved pixel width of each of [columns], in the same order.
  final List<double> widths;

  /// Class constructor
  const _HeaderRow({required this.columns, required this.widths});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _selectionBarWidth + _gutterWidth,
        10,
        0,
        8,
      ),
      child: Row(
        children: [
          for (var index = 0; index < columns.length; index++)
            Padding(
              padding: const EdgeInsets.only(right: _columnGap),
              child: SizedBox(
                width: widths[index],
                child: Text(
                  columns[index].label(tr).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: columns[index].alignment,
                  style: style,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One shot of the shot list table.
///
/// The selected row wears the accent bar down its left edge and the accent wash behind it; the
/// leading gutter carries the ⚠ of a shot that needs checking. The shot code is typeset in the
/// screenplay's own fixed-pitch family, and both the difficulty and the status take a colour of
/// their own when they have something to say.
class OcptShotListRow extends StatelessWidget {
  /// The shot this row shows.
  final OcptShot shot;

  /// The heading of the sequence this shot belongs to.
  final String sequenceHeading;

  /// The columns laid out, in order.
  final List<OcptShotListTableColumn> columns;

  /// The resolved pixel width of each of [columns], in the same order.
  final List<double> widths;

  /// Whether this shot is the selected one.
  final bool isSelected;

  /// Called when the row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const OcptShotListRow({
    super.key,
    required this.shot,
    required this.sequenceHeading,
    required this.columns,
    required this.widths,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
              width: _selectionBarWidth,
            ),
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _gutterWidth,
                child: shot.needsCheck
                    ? Tooltip(
                        message: tr.shotListNeedsCheckTooltip,
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 12,
                          color: ocptShotListWarningColor(context),
                        ),
                      )
                    : null,
              ),
              for (var index = 0; index < columns.length; index++)
                Padding(
                  padding: const EdgeInsets.only(right: _columnGap),
                  child: SizedBox(
                    width: widths[index],
                    child: Text(
                      columns[index].valueFor(context, shot, sequenceHeading),
                      maxLines: columns[index].wraps ? null : 1,
                      overflow: columns[index].wraps
                          ? TextOverflow.clip
                          : TextOverflow.ellipsis,
                      softWrap: columns[index].wraps,
                      textAlign: columns[index].alignment,
                      style: _styleFor(context, columns[index]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The text style of [column]'s cell for this shot: the shot code in the screenplay's
  /// fixed-pitch family, the difficulty warning-coloured once it reaches its threshold, the
  /// status in its own status colour, everything else the table's plain body style.
  TextStyle? _styleFor(BuildContext context, OcptShotListTableColumn column) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodySmall;

    return switch (column) {
      OcptShotListTableColumn.shot => baseStyle?.copyWith(
        fontFamily: ocptMonospaceFontFamily,
        fontWeight: FontWeight.w600,
      ),
      OcptShotListTableColumn.difficulty => baseStyle?.copyWith(
        fontWeight: FontWeight.w600,
        color: shot.averageDifficulty >= ocptShotListDifficultyWarningThreshold
            ? ocptShotListWarningColor(context)
            : null,
      ),
      OcptShotListTableColumn.status => baseStyle?.copyWith(
        color: ocptShotStatusColor(context, shot.status),
      ),
      _ => baseStyle,
    };
  }
}

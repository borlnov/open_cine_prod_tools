// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_placement.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_row.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_table_column.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_table_constants.dart';

// The table's rows are drawn by their own widget; the table's callers reach both through here.
export 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_row.dart';

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

  /// Where each of [shots] sits in the schedule, keyed by shot id onto every block that places it —
  /// see `OcptShotListSnapshot.placementsByShotId`. A shot with no entry here reads as unplaced.
  final Map<String, List<OcptShotPlacement>> placementsByShotId;

  /// Called with a shot's id when its row is clicked.
  final ValueChanged<String> onShotSelected;

  /// Class constructor
  const OcptShotListTable({
    super.key,
    required this.shots,
    required this.sequenceHeading,
    required this.visibleColumns,
    required this.selectedShotId,
    required this.placementsByShotId,
    required this.onShotSelected,
  });

  /// Build the shot list table as a [LayoutBuilder].
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
            ocptShotListTableSelectionBarWidth +
            ocptShotListTableGutterWidth +
            widths.fold<double>(0, (total, width) => total + width + ocptShotListTableColumnGap);

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
                      placements: placementsByShotId[shots[index].id] ?? const [],
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
        ocptShotListTableSelectionBarWidth +
        ocptShotListTableGutterWidth +
        columns.fold<double>(
          0,
          (total, column) => total + column.minWidth + ocptShotListTableColumnGap,
        );
    final totalFlex = columns.fold<int>(0, (total, column) => total + column.flex);
    final extraWidth = availableWidth - fixedWidth;

    if (totalFlex == 0 || extraWidth <= 0) {
      return [for (final column in columns) column.minWidth];
    }

    return [for (final column in columns) column.minWidth + extraWidth * column.flex / totalFlex];
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

  /// Build the header row as a [Padding].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ocptShotListTableSelectionBarWidth + ocptShotListTableGutterWidth,
        10,
        0,
        8,
      ),
      child: Row(
        children: [
          for (var index = 0; index < columns.length; index++)
            Padding(
              padding: const EdgeInsets.only(right: ocptShotListTableColumnGap),
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

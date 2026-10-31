// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_placement.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_table_column.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_table_constants.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_shot_list_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_warning_color.dart';

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

  /// [shot]'s own placement(s) in the schedule, empty while it hasn't been placed on any day yet.
  final List<OcptShotPlacement> placements;

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
    required this.placements,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
              width: ocptShotListTableSelectionBarWidth,
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
                width: ocptShotListTableGutterWidth,
                child: shot.needsCheck
                    ? Tooltip(
                        message: tr.shotListNeedsCheckTooltip,
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 12,
                          color: ocptWarningColor(context),
                        ),
                      )
                    : null,
              ),
              for (var index = 0; index < columns.length; index++)
                Padding(
                  padding: const EdgeInsets.only(right: ocptShotListTableColumnGap),
                  child: SizedBox(
                    width: widths[index],
                    child: Text(
                      columns[index].valueFor(context, shot, sequenceHeading, placements),
                      maxLines: columns[index].wraps ? null : 1,
                      overflow: columns[index].wraps ? TextOverflow.clip : TextOverflow.ellipsis,
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
            ? ocptWarningColor(context)
            : null,
      ),
      OcptShotListTableColumn.status => baseStyle?.copyWith(
        color: ocptShotStatusColor(context, shot.status),
      ),
      _ => baseStyle,
    };
  }
}

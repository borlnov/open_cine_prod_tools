// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_placement.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_shot_list_labels.dart';

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

  /// The text this column shows for [shot], whose sequence has the heading [sequenceHeading] and
  /// whose placement(s) in the schedule are [placements] (empty while it hasn't been placed on any
  /// day yet).
  String valueFor(
    BuildContext context,
    OcptShot shot,
    String sequenceHeading,
    List<OcptShotPlacement> placements,
  ) => switch (this) {
    OcptShotListTableColumn.shot => shot.code,
    OcptShotListTableColumn.characters =>
      shot.characters.isEmpty ? ocptShotListEmptyValue : shot.characters.join(", "),
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
    OcptShotListTableColumn.shootingDay => ocptShotPlacementLabel(context, placements),
    OcptShotListTableColumn.status => ocptShotStatusLabel(Tr.of(context), shot.status),
  };

  /// The columns to lay out given the [visibleColumns] the user toggled on: every always-shown
  /// column, plus the optional ones currently visible.
  static List<OcptShotListTableColumn> visibleIn(Set<OcptShotListColumn> visibleColumns) => [
    for (final column in OcptShotListTableColumn.values)
      if (column.optionalColumn == null || visibleColumns.contains(column.optionalColumn)) column,
  ];
}

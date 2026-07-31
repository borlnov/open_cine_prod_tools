// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';

/// The placeholder shown in place of a shot field that has no value yet.
///
/// An empty cell would read as a rendering bug in a dense table; an em dash reads as "nothing
/// here yet", which is what it means.
const ocptShotListEmptyValue = "—";

/// The difficulty at or above which a shot's average difficulty is emphasised as a warning, on
/// the 0-5 scale the four difficulty axes are rated on.
const ocptShotListDifficultyWarningThreshold = 2.5;

/// The display label of the optional table column [column], shared by the table's header row and
/// by the `Columns ▾` menu so the two can never name the same column differently.
String ocptShotListColumnLabel(Tr tr, OcptShotListColumn column) => switch (column) {
  OcptShotListColumn.set => tr.shotListColumnSet,
  OcptShotListColumn.lens => tr.shotListColumnLens,
  OcptShotListColumn.recordingFormat => tr.shotListColumnFormat,
  OcptShotListColumn.duration => tr.shotListColumnDuration,
  OcptShotListColumn.takes => tr.shotListColumnTakes,
  OcptShotListColumn.sound => tr.shotListColumnSound,
  OcptShotListColumn.shootingDay => tr.shotListColumnShootingDay,
  OcptShotListColumn.status => tr.shotListColumnStatus,
};

/// The display label of the shooting status [status].
String ocptShotStatusLabel(Tr tr, OcptShotStatus status) => switch (status) {
  OcptShotStatus.toShoot => tr.shotListStatusToShoot,
  OcptShotStatus.shot => tr.shotListStatusShot,
  OcptShotStatus.retake => tr.shotListStatusRetake,
};

/// The header label of the exported workbook's column [column].
///
/// Reuses the table's own column labels wherever the workbook writes the same column, so the
/// spreadsheet a crew works from never names a column differently than the app does; the two
/// columns the table has no room for take the inspector's own section titles instead.
String ocptShotListXlsxColumnLabel(Tr tr, OcptShotListXlsxColumn column) => switch (column) {
  OcptShotListXlsxColumn.shot => tr.shotListColumnShot,
  OcptShotListXlsxColumn.characters => tr.shotListColumnCharacters,
  OcptShotListXlsxColumn.set => tr.shotListColumnSet,
  OcptShotListXlsxColumn.shotSize => tr.shotListColumnShotSize,
  OcptShotListXlsxColumn.framing => tr.shotListColumnFraming,
  OcptShotListXlsxColumn.cameraMove => tr.shotListColumnCameraMove,
  OcptShotListXlsxColumn.lens => tr.shotListColumnLens,
  OcptShotListXlsxColumn.recordingFormat => tr.shotListColumnFormat,
  OcptShotListXlsxColumn.duration => tr.shotListColumnDuration,
  OcptShotListXlsxColumn.takes => tr.shotListColumnTakes,
  OcptShotListXlsxColumn.sound => tr.shotListColumnSound,
  OcptShotListXlsxColumn.difficulty => tr.shotListColumnDifficulty,
  OcptShotListXlsxColumn.shootingDay => tr.shotListColumnShootingDay,
  OcptShotListXlsxColumn.status => tr.shotListColumnStatus,
  OcptShotListXlsxColumn.notes => tr.shotListInspectorNotesSectionTitle,
  OcptShotListXlsxColumn.locationNotes => tr.shotListInspectorLocationSectionTitle,
};

/// Builds every localized string the exported shot list workbook carries, for the [sequences] it
/// is being built from.
///
/// This is the single bridge between the UI's `Tr` and `OcptShotListXlsxExportService`, which runs
/// in the manager layer and has no `BuildContext` to resolve anything of its own: a sequence's
/// separator title is resolved here, sequence by sequence, since a real scene's own header takes
/// its number and heading as placeholders while the orphan group's is a plain title.
OcptShotListXlsxLabels ocptShotListXlsxLabelsOf(Tr tr, List<OcptShotSequence> sequences) =>
    OcptShotListXlsxLabels(
      sheetName: tr.shotListExportXlsxSheetName,
      columnHeaders: {
        for (final column in OcptShotListXlsxColumn.values)
          column: ocptShotListXlsxColumnLabel(tr, column),
      },
      statusLabels: {
        for (final status in OcptShotStatus.values) status: ocptShotStatusLabel(tr, status),
      },
      sequenceTitles: {
        for (final sequence in sequences)
          sequence.id: switch (sequence) {
            OcptSceneShotSequence() => tr.shotListSequenceHeader(
              sequence.displaySceneNumber,
              sequence.heading,
            ),
            OcptOrphanShotSequence() => tr.shotListOrphanSequenceTitle,
          },
      },
    );

/// The colour the shooting status [status] is painted with.
///
/// [OcptShotStatus.toShoot] is the neutral one and reads through the colour scheme's own
/// `onSurfaceVariant`; the two others come from [OcptSpecificColors], which is where the app puts
/// the colours Material 3 has no role for.
Color ocptShotStatusColor(BuildContext context, OcptShotStatus status) {
  final theme = Theme.of(context);
  final specificColors = theme.extension<OcptSpecificColors>();

  return switch (status) {
    OcptShotStatus.toShoot => theme.colorScheme.onSurfaceVariant,
    OcptShotStatus.shot => specificColors?.shotStatusShot ?? theme.colorScheme.onSurfaceVariant,
    OcptShotStatus.retake => specificColors?.shotStatusRetake ?? theme.colorScheme.error,
  };
}

/// The colour the shot list marks everything needing attention with: a shot's ⚠, and a difficulty
/// at or above [ocptShotListDifficultyWarningThreshold].
Color ocptShotListWarningColor(BuildContext context) {
  final theme = Theme.of(context);
  return theme.extension<OcptSpecificColors>()?.shotStatusRetake ?? theme.colorScheme.error;
}

/// Formats the difficulty [value] with a single decimal, in the locale [context] resolves to (so
/// French reads `1,8` where English reads `1.8`).
String ocptFormatShotDifficulty(BuildContext context, double value) =>
    NumberFormat.decimalPatternDigits(
      locale: Localizations.localeOf(context).toString(),
      decimalDigits: 1,
    ).format(value);

/// Formats the shot duration [milliseconds] as `m:ss`, or [ocptShotListEmptyValue] when the shot
/// has no estimated duration yet.
String ocptFormatShotDuration(int? milliseconds) {
  if (milliseconds == null) {
    return ocptShotListEmptyValue;
  }

  final totalSeconds = (milliseconds / Duration.millisecondsPerSecond).round();
  final seconds = totalSeconds % Duration.secondsPerMinute;

  return "${totalSeconds ~/ Duration.secondsPerMinute}:${seconds.toString().padLeft(2, "0")}";
}

/// Returns [value] if it holds anything other than whitespace, [ocptShotListEmptyValue]
/// otherwise: the single place the table and the left dock turn a blank shot field into
/// something readable.
String ocptShotFieldOrDash(String? value) =>
    value == null || value.trim().isEmpty ? ocptShotListEmptyValue : value;

/// Parses a shot's estimated duration from [input], the inverse of [ocptFormatShotDuration].
///
/// A blank [input], or exactly [ocptShotListEmptyValue] (what [ocptFormatShotDuration] itself
/// renders for a null duration, so the two stay round-trippable), means "no estimate" and parses
/// to null. `m:ss` parses to milliseconds. A bare non-negative integer is read as a number of
/// seconds. Anything else throws a [FormatException]: the shot inspector's own choice, on
/// catching it, is to leave the shot's stored duration untouched rather than write anything.
int? ocptParseShotDuration(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty || trimmed == ocptShotListEmptyValue) {
    return null;
  }

  final colonIndex = trimmed.indexOf(":");
  if (colonIndex == -1) {
    final seconds = int.tryParse(trimmed);
    if (seconds == null || seconds < 0) {
      throw FormatException("Not a valid shot duration", input);
    }
    return seconds * Duration.millisecondsPerSecond;
  }

  final minutes = int.tryParse(trimmed.substring(0, colonIndex));
  final seconds = int.tryParse(trimmed.substring(colonIndex + 1));
  if (minutes == null ||
      seconds == null ||
      minutes < 0 ||
      seconds < 0 ||
      seconds >= Duration.secondsPerMinute) {
    throw FormatException("Not a valid shot duration", input);
  }

  return (minutes * Duration.secondsPerMinute + seconds) * Duration.millisecondsPerSecond;
}

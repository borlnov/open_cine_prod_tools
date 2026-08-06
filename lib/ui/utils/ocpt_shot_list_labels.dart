// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_scenario_coverage_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_placement.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_status.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart' show ocptScheduleDayTagLabel;

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
  OcptShotListXlsxColumn.abbreviation => tr.shotListColumnAbbreviation,
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
      sequenceTitles: ocptShotListSequenceTitlesOf(tr, sequences),
    );

/// Builds every localized string the exported scenario coverage document carries, for the
/// [sequences] it is being built from.
///
/// The sibling of [ocptShotListXlsxLabelsOf] for the other export the shot list mode offers, and
/// the same single bridge between the UI's `Tr` and a service running in the manager layer, with no
/// `BuildContext` to resolve anything of its own.
///
/// The legend's own column headers are the shot table's, resolved through the very same keys
/// [ocptShotListXlsxColumnLabel] uses, so the three places a crew reads about a shot — the app, the
/// workbook and this document — never name the same field differently. Only what has no on-screen
/// counterpart at all (the two appendices' headings, the summary's own columns, the file name
/// suffix) gets a key of its own.
OcptScenarioCoverageLabels ocptScenarioCoverageLabelsOf(Tr tr, List<OcptShotSequence> sequences) =>
    OcptScenarioCoverageLabels(
      fileNameSuffix: tr.shotListExportCoverageFileNameSuffix,
      legendTitle: tr.shotListExportCoverageLegendTitle,
      legendShotHeader: tr.shotListColumnShot,
      legendShotSizeHeader: tr.shotListColumnShotSize,
      legendFramingHeader: tr.shotListColumnFraming,
      legendCameraMoveHeader: tr.shotListColumnCameraMove,
      summaryTitle: tr.shotListExportCoverageSummaryTitle,
      summarySequenceHeader: tr.shotListExportCoverageSummarySequenceHeader,
      summaryShotCountHeader: tr.shotListExportCoverageSummaryShotCountHeader,
      summaryCoveredHeader: tr.shotListExportCoverageSummaryCoveredHeader,
      summaryStaleHeader: tr.shotListExportCoverageSummaryStaleHeader,
      summaryUncoveredHeader: tr.shotListExportCoverageSummaryUncoveredHeader,
      laneOverflowNote: tr.shotListExportCoverageLaneOverflowNote,
      sequenceTitles: ocptShotListSequenceTitlesOf(tr, sequences),
    );

/// The title of each of the [sequences], keyed by `OcptShotSequence.id`, as both exports name them.
///
/// Resolved sequence by sequence rather than formatted by the exporting service, since a real
/// scene's own header takes its number and heading as placeholders while the orphan group's is a
/// plain title.
Map<String, String> ocptShotListSequenceTitlesOf(Tr tr, List<OcptShotSequence> sequences) => {
  for (final sequence in sequences)
    sequence.id: switch (sequence) {
      OcptSceneShotSequence() => tr.shotListSequenceHeader(
        sequence.displaySceneNumber,
        sequence.heading,
      ),
      OcptOrphanShotSequence() => tr.shotListOrphanSequenceTitle,
    },
};

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

/// Formats the difficulty [value] with a single decimal, in the locale [context] resolves to (so
/// French reads `1,8` where English reads `1.8`).
String ocptFormatShotDifficulty(BuildContext context, double value) =>
    NumberFormat.decimalPatternDigits(
      locale: Localizations.localeOf(context).toString(),
      decimalDigits: 1,
    ).format(value);

/// Formats the shot duration [milliseconds] as `mm:ss`, or [ocptShotListEmptyValue] when the shot
/// has no estimated duration yet.
///
/// Both halves are always written on two digits (`01:30`, `00:45`), so a column of durations reads
/// as one column rather than as a ragged edge, and so what the table shows is exactly what the
/// inspector's own field accepts back. A duration of an hour or more simply overflows its minutes
/// (`75:00`): a *shot* never runs that long, and inventing an hours field for it would cost every
/// other duration a pair of leading zeroes.
String ocptFormatShotDuration(int? milliseconds) {
  if (milliseconds == null) {
    return ocptShotListEmptyValue;
  }

  final totalSeconds = (milliseconds / Duration.millisecondsPerSecond).round();
  final minutes = totalSeconds ~/ Duration.secondsPerMinute;
  final seconds = totalSeconds % Duration.secondsPerMinute;

  return "${minutes.toString().padLeft(2, "0")}:${seconds.toString().padLeft(2, "0")}";
}

/// Returns [value] if it holds anything other than whitespace, [ocptShotListEmptyValue]
/// otherwise: the single place the table and the left dock turn a blank shot field into
/// something readable.
String ocptShotFieldOrDash(String? value) =>
    value == null || value.trim().isEmpty ? ocptShotListEmptyValue : value;

/// The shot list's own read-out of a shot's placement in the schedule: `J3 · Tue 4 Aug` for a
/// placed shot, [ocptShotListEmptyValue] for one [placement] is null for — the schedule carries no
/// entry for it at all, which is what "not yet planned" looks like
/// (`OcptScheduleService.loadShotPlacements`'s own doc comment).
///
/// The day tag is [ocptScheduleDayTagLabel], the schedule mode's own — reused rather than
/// reimplemented, so the two modes can never print a shooting day's rank differently, and never run
/// through `Tr` for the same reason that one isn't: it is the trade's own shorthand, not a
/// translated word. The date is formatted for the locale [context] resolves to, without a year: the
/// column has no room for one and a shoot rarely spans two.
String ocptShotPlacementLabel(BuildContext context, OcptShotPlacement? placement) {
  if (placement == null) {
    return ocptShotListEmptyValue;
  }

  final dateLabel = DateFormat.MMMEd(
    Localizations.localeOf(context).toString(),
  ).format(placement.date);

  return "${ocptScheduleDayTagLabel(placement.dayNumber)} · $dateLabel";
}

/// Parses a shot's estimated duration from [input], the inverse of [ocptFormatShotDuration].
///
/// A blank [input], or exactly [ocptShotListEmptyValue] (what [ocptFormatShotDuration] itself
/// renders for a null duration, so the two stay round-trippable), means "no estimate" and parses
/// to null. `mm:ss` parses to milliseconds, leading zeroes optional on either half (`1:30` and
/// `01:30` are the same duration). A bare non-negative integer is read as a number of seconds, so
/// a duration under a minute can be typed as `45` alone. Anything else throws a
/// [FormatException]: the shot inspector's own choice, on catching it, is to leave the shot's
/// stored duration untouched rather than write anything, and to mark the field in error.
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

/// Deduces the short abbreviation of the shot size [shotSize]: the initials of its words, upper
/// cased (`Plan moyen` → `PM`, `Gros plan` → `GP`, `Close-up` → `C`).
///
/// A "word" is whatever whitespace separates, so a hyphenated shot size counts as one — which is
/// what makes `Close-up` a `C` rather than a `CU`, matching how a French crew writes the same
/// abbreviations. A word carrying no letter or digit at all (a lone dash, a bracket) contributes
/// nothing, and a shot size made of nothing but those deduces to an empty abbreviation, which the
/// caller reads as "nothing to deduce" rather than writing it.
///
/// Only ever applied to a shot whose abbreviation is still empty, and only at the moment its shot
/// size is committed: an abbreviation the user has typed is theirs, and editing the shot size
/// afterwards never overwrites it.
String ocptDeduceShotAbbreviation(String shotSize) {
  final initials = StringBuffer();

  for (final word in shotSize.split(RegExp(r"\s+"))) {
    final initial = RegExp(r"[\p{L}\p{N}]", unicode: true).firstMatch(word)?.group(0);
    if (initial != null) {
      initials.write(initial.toUpperCase());
    }
  }

  return initials.toString();
}

/// The formatters the shot inspector's estimated-duration field is built with: what `mm:ss` is
/// written with, digits and the `:` separator, and nothing else.
///
/// Keeping every other character out of the field is what turns "the duration is a number" into
/// something the user is shown rather than told: a letter, a sign or a space never even appears,
/// so the only mistake left to report is a badly shaped one (`1:75`, `1:2:3`), which
/// [ocptIsShotDurationValid] answers for.
final List<TextInputFormatter> ocptShotDurationInputFormatters = [
  FilteringTextInputFormatter.allow(RegExp("[0-9:]")),
];

/// Whether [input] is something [ocptParseShotDuration] accepts, answered without throwing: what
/// the shot inspector's duration field asks itself on every keystroke to decide whether to show
/// its `mm:ss` error, while the bloc goes on parsing the very same text for the value itself.
bool ocptIsShotDurationValid(String input) {
  try {
    ocptParseShotDuration(input);
    return true;
  } on FormatException {
    return false;
  }
}

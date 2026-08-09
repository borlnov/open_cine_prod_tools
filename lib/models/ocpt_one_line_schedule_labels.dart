// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// Every localized string the exported one-line schedule carries, resolved by the caller.
///
/// `OcptOneLineSchedulePdfService` runs in the manager layer, where there is no `BuildContext` and
/// therefore no `Tr`: the same reason `OcptDayOutOfDaysLabels` and its own siblings already exist
/// for every export before it.
///
/// [dayTitles] and [directorLine] are the two entries resolved by the caller rather than formatted
/// here, exactly the trade `OcptShootingPlanLabels.dayTitles`/`.directorLine` already make: a day
/// band's own title needs `intl` in the UI's own locale, which a manager-layer service has no
/// `Localizations` to reach.
///
/// Every accessor returns an empty string for a key it holds nothing for, exactly as its siblings'
/// do: a missing translation prints as a blank rather than as a crash on a document a shoot is
/// waiting for.
class OcptOneLineScheduleLabels extends Equatable {
  /// The localized word telling this document apart from the other PDFs the app writes
  /// (`My Movie - one-line schedule.pdf`), read by
  /// `OcptOneLineSchedulePdfService.oneLineScheduleFileName`. A blank one falls back to the project
  /// name alone, exactly as its siblings do.
  final String fileNameSuffix;

  /// The document's own generic name, printed small above every page as its running head beside the
  /// project's, and as the title page's own document name (`Plan de travail synthétique`).
  final String documentTitle;

  /// The `"<title>" de <director>` line printed on the title page, or an empty string while the
  /// project names no director — see the class doc comment for why it is resolved by the caller.
  final String directorLine;

  /// The label the moment this export was produced is printed under (`Version`), on the title page
  /// and in every page's own running head alike — the same word every schedule document prints its
  /// own `ocptScheduleGeneratedAtStamp` behind.
  final String versionLabel;

  /// The day tag's own letter (`D`/`J`), printed on each day band beside that day's rank, exactly as
  /// `OcptShootingPlanLabels.dayTagPrefix` already is.
  final String dayTagPrefix;

  /// Each printed day's own full title, keyed by `OcptShootingDay.id` — the day band's own second
  /// entry, after its tag and before its location. See the class doc comment for why it is resolved
  /// by the caller.
  final Map<String, String> dayTitles;

  /// The main table's own `SEQ` column header.
  final String seqHeader;

  /// The main table's own `EFFET` column header.
  final String effectHeader;

  /// The main table's own `DÉCOR` column header.
  final String decorHeader;

  /// The main table's own `RÔLES` column header.
  final String rolesHeader;

  /// The main table's own `DURÉE` column header.
  final String durationHeader;

  /// The word a day band prints in place of a location name while its first live slot names none.
  final String noLocationLabel;

  /// The note printed in place of a day's own table when its own lines fold down to none — a day
  /// carrying only non-shooting blocks, or no block at all.
  final String emptyDayNote;

  /// The note printed in place of the whole document when [dayTitles]' own range names no live day
  /// at all.
  final String emptyDocumentNote;

  /// Class constructor
  const OcptOneLineScheduleLabels({
    required this.fileNameSuffix,
    required this.documentTitle,
    required this.directorLine,
    required this.versionLabel,
    required this.dayTagPrefix,
    required this.dayTitles,
    required this.seqHeader,
    required this.effectHeader,
    required this.decorHeader,
    required this.rolesHeader,
    required this.durationHeader,
    required this.noLocationLabel,
    required this.emptyDayNote,
    required this.emptyDocumentNote,
  });

  /// The title of the day [dayId], or an empty string if [dayTitles] holds none for it.
  String titleOfDay(String dayId) => dayTitles[dayId] ?? "";

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptOneLineScheduleLabels(documentTitle: $documentTitle, dayCount: ${dayTitles.length})";

  /// Object properties
  @override
  List<Object?> get props => [
    fileNameSuffix,
    documentTitle,
    directorLine,
    versionLabel,
    dayTagPrefix,
    dayTitles,
    seqHeader,
    effectHeader,
    decorHeader,
    rolesHeader,
    durationHeader,
    noLocationLabel,
    emptyDayNote,
    emptyDocumentNote,
  ];
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_out_of_days.dart';

/// Every localized string the exported *Day Out of Days* carries, resolved by the caller.
///
/// `OcptDayOutOfDaysPdfService` runs in the manager layer, where there is no `BuildContext` and
/// therefore no `Tr`: the same reason `OcptShootingPlanLabels` and its own siblings already exist
/// for every export before it, and its class doc comment holds here word for word.
///
/// [dayDateLabels] and [directorLine] are the two entries resolved by the caller rather than
/// formatted here, exactly the trade `OcptShootingPlanLabels.dayTitles`/`.directorLine` already
/// make: a column's own date needs `intl` in the UI's own locale, which a manager-layer service has
/// no `Localizations` to reach.
///
/// Every accessor returns an empty string for a key it holds nothing for, exactly as its siblings'
/// do: a missing translation prints as a blank rather than as a crash on a document a shoot is
/// waiting for.
class OcptDayOutOfDaysLabels extends Equatable {
  /// The localized word telling this document apart from the other PDFs the app writes
  /// (`My Movie - day out of days.pdf`), read by `OcptDayOutOfDaysPdfService.dayOutOfDaysFileName`.
  /// A blank one falls back to the project name alone, exactly as its siblings do.
  final String fileNameSuffix;

  /// The document's own generic name, printed small above every page as its running head beside the
  /// project's, and as the title page's own document name (`Plan de travail comédiens`).
  final String documentTitle;

  /// The `"<title>" de <director>` line printed on the title page, or an empty string while the
  /// project names no director — see the class doc comment for why it is resolved by the caller.
  final String directorLine;

  /// The label the moment this export was produced is printed under (`Version`), on the title page
  /// and in every page's own running head alike — the same word every schedule document prints its
  /// own `ocptScheduleGeneratedAtStamp` behind.
  final String versionLabel;

  /// The day tag's own letter (`D`/`J`), printed above each column beside that day's rank, exactly
  /// as `OcptShootingPlanLabels.dayTagPrefix` already is.
  final String dayTagPrefix;

  /// Each printed day's own short date, keyed by `OcptShootingDay.id` — the second line of a column
  /// header, under its day tag. See the class doc comment for why it is resolved by the caller.
  final Map<String, String> dayDateLabels;

  /// The corner header of the table's own row-label column (`Rôle`).
  final String roleHeader;

  /// The header of the trailing count of the days a role is convoked on (`Jours travaillés`).
  final String workedDaysHeader;

  /// The header of the trailing count of a role's own hold days (`Jours d'attente`).
  final String heldDaysHeader;

  /// The letters printed in the cells themselves, keyed by [OcptDayOutOfDaysCode] — `SW`, `W`,
  /// `WF`, `SWF` and `H`, the codes a *Day Out of Days* is read by the world over. They are carried
  /// here rather than hard-coded so a production working in another convention can be given its own,
  /// and they are printed beside [codeDescriptions] on the legend for the reader who does not know
  /// them.
  final Map<OcptDayOutOfDaysCode, String> codeLabels;

  /// What each code of [codeLabels] means, in a full sentence-case phrase, keyed by the same enum —
  /// the legend's own right-hand column.
  final Map<OcptDayOutOfDaysCode, String> codeDescriptions;

  /// The heading of the legend printed under the table (`Légende`).
  final String legendSectionTitle;

  /// The label a role with a blank name prints under — the same fallback every other reader of the
  /// cast in this app uses, so a nameless part is still a readable row.
  final String unnamedRoleLabel;

  /// The note printed in place of the whole table when the printed range names no live day, or no
  /// role is convoked anywhere in it.
  final String emptyTableNote;

  /// Class constructor
  const OcptDayOutOfDaysLabels({
    required this.fileNameSuffix,
    required this.documentTitle,
    required this.directorLine,
    required this.versionLabel,
    required this.dayTagPrefix,
    required this.dayDateLabels,
    required this.roleHeader,
    required this.workedDaysHeader,
    required this.heldDaysHeader,
    required this.codeLabels,
    required this.codeDescriptions,
    required this.legendSectionTitle,
    required this.unnamedRoleLabel,
    required this.emptyTableNote,
  });

  /// The short date of the day [dayId], or an empty string if [dayDateLabels] holds none for it.
  String dateOfDay(String dayId) => dayDateLabels[dayId] ?? "";

  /// The letter printed for [code], or an empty string if [codeLabels] holds none for it.
  String codeLabelOf(OcptDayOutOfDaysCode code) => codeLabels[code] ?? "";

  /// What [code] means, or an empty string if [codeDescriptions] holds none for it.
  String codeDescriptionOf(OcptDayOutOfDaysCode code) => codeDescriptions[code] ?? "";

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptDayOutOfDaysLabels(documentTitle: $documentTitle, dayCount: ${dayDateLabels.length})";

  /// Object properties
  @override
  List<Object?> get props => [
    fileNameSuffix,
    documentTitle,
    directorLine,
    versionLabel,
    dayTagPrefix,
    dayDateLabels,
    roleHeader,
    workedDaysHeader,
    heldDaysHeader,
    codeLabels,
    codeDescriptions,
    legendSectionTitle,
    unnamedRoleLabel,
    emptyTableNote,
  ];
}

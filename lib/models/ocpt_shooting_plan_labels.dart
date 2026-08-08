// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';

/// Every localized string the exported shooting plan carries, resolved by the caller.
///
/// `OcptShootingPlanPdfService` runs in the manager layer, where there is no `BuildContext` and
/// therefore no `Tr`: the same reason `OcptCallSheetLabels` and its own siblings already exist for
/// the exports before it.
///
/// [dayTitles] and [directorLine] are the two entries resolved by the caller rather than formatted
/// here, exactly the trade `OcptCallSheetLabels.dayTitles`/`.directorLine` already make: a day's
/// own title (`Planning de la journée du mercredi 9 août`) needs its date formatted through `intl`
/// in the UI's own locale, and the `"<title>" de <director>` line needs the same locale-sensitive
/// wording — a manager-layer service has no `Localizations` to reach either with.
///
/// Every accessor returns an empty string (or, for a map keyed by an enum, the same) for a key it
/// holds nothing for, exactly as `OcptCallSheetLabels`'s own accessors do: a missing translation
/// prints as a blank rather than as a crash on a document a shoot is waiting for.
class OcptShootingPlanLabels extends Equatable {
  /// The localized word telling this document apart from the other PDFs the app writes
  /// (`My Movie - shooting plan.pdf`), read by `OcptShootingPlanPdfService.shootingPlanFileName`. A
  /// blank one falls back to the project name alone, exactly as
  /// `OcptBreakdownSheetsPdfService.sheetsFileName` does.
  final String fileNameSuffix;

  /// The document's own generic name, printed small above every page as its running head beside the
  /// project's, and as the title page's own document name (`Planning de tournage`).
  final String documentTitle;

  /// The full title of each day's own agenda page, keyed by `OcptShootingDay.id` — see the class
  /// doc comment for why it is resolved by the caller.
  final Map<String, String> dayTitles;

  /// The `"<title>" de <director>` line printed on the title page, or an empty string while the
  /// project names no director — see the class doc comment for why it is resolved by the caller.
  final String directorLine;

  /// The label the moment this export was produced is printed under (`Version`), on the title page
  /// and in every page's own running head alike — one word for one stamp, the running head being
  /// where a reader of page six finds out which issue of the plan they are holding.
  final String versionLabel;

  /// The day tag's own letter (`D`/`J`), printed beside a day's rank in every grid column and every
  /// agenda page, exactly as `OcptCallSheetLabels.dayTagPrefix` already is.
  final String dayTagPrefix;

  /// The heading of the locations summary grid (`Résumé - Lieux`).
  final String locationsGridTitle;

  /// The heading of the sequences summary grid (`Résumé - Séquences`).
  final String sequencesGridTitle;

  /// The heading of the crew and cast summary grid (`Résumé - Équipe technique et comédiens`).
  final String peopleGridTitle;

  /// The corner header of the locations grid's own row-label column.
  final String locationsGridRowHeader;

  /// The corner header of the sequences grid's own row-label column.
  final String sequencesGridRowHeader;

  /// The corner header of the crew and cast grid's own row-label column.
  final String peopleGridRowHeader;

  /// The word `Perso.`, reused both as a shot table's own characters column header and as the
  /// locations grid's own nested row naming who is present — the reference document uses the same
  /// word for both, and so does this one.
  final String persoLabel;

  /// The prefix a sequences grid's own row label is built with (`Séq. 2`).
  final String sequenceRowPrefix;

  /// The mark a crew and cast grid prints for an uncast role present in a slot with nobody to name
  /// (`x`).
  final String presenceMark;

  /// The display label of every catalogued crew position (`ocptCrewPositions`), keyed by its stable
  /// id — the same map `OcptCallSheetLabels.crewPositionLabels` already carries.
  final Map<String, String> crewPositionLabels;

  /// The label a day agenda's own location line is printed under (`Le lieu :`).
  final String dayLocationLabel;

  /// The label a day agenda's own per-slot hours line is printed under (`Les horaires :`).
  final String dayHoursLabel;

  /// The label a day agenda's own per-location sets line is printed under (`Détails des lieux :`).
  final String daySetsLabel;

  /// The label a day agenda's own interleaved timetable is printed under (`Planning détaillé :`).
  final String dayTimetableLabel;

  /// The word introducing a slot's own resolved start on its hours line (`rendez-vous à`).
  final String callTimeLabel;

  /// The word introducing a slot's own resolved end on its hours line (`fin estimée vers`).
  final String estimatedEndLabel;

  /// The word introducing a milestone line's own start (`De`, prose: `De 16h45 à 17h15 : …`).
  final String milestoneFromLabel;

  /// The word joining a milestone line's own start and end (`à`, prose: `De 16h45 à 17h15 : …`).
  final String milestoneToLabel;

  /// The default caption of every non-shooting block kind but [OcptShootingBlockKind.shot], printed
  /// on a milestone line that carries no free-text label of its own — the same map
  /// `OcptCallSheetLabels.blockKindLabels` already carries, and a [OcptShootingBlockKind.hold]
  /// block's own sequence heading is read the same way it is there too.
  final Map<OcptShootingBlockKind, String> blockKindLabels;

  /// The label a [OcptShootingBlockKind.hairMakeUp] milestone's own second line names its expected
  /// role numbers behind (`RÔLES : 3, 5`) — the same heading `OcptCallSheetLabels.rolesHeader`
  /// carries, so the two documents label that line identically.
  final String rolesLabel;

  /// A shot table's own `Hours` column header, printing the block's resolved start over its
  /// resolved end — the one column the reference document's own shot table carries no equivalent
  /// of, printed first so a reader can tell at a glance when each plan happens.
  final String hoursHeader;

  /// A shot table's own `Plan` column header.
  final String planHeader;

  /// A shot table's own `Valeur de plan` column header.
  final String shotSizeHeader;

  /// A shot table's own `Move.` column header.
  final String moveHeader;

  /// A shot table's own `Cadre` column header — the reference document's own `Description` column,
  /// replaced: no field of this app answers "what happens in this shot" (`OcptShot.framing` is the
  /// angle and composition of the frame, not the action), so the header promises what the column
  /// actually prints.
  final String framingHeader;

  /// A shot table's own `Commentaire` column header, printing `OcptShot.notes` — never alongside a
  /// second column that would print the very same field under another heading.
  final String commentHeader;

  /// The note printed in place of the whole document when the printed range names no live day at
  /// all, and in place of a grid whose own range holds nothing to show.
  final String emptyPlanNote;

  /// The note printed in place of a day agenda's own timetable when that day carries no slot, or no
  /// block on any of them.
  final String emptyDayScheduleNote;

  /// The heading of a day agenda's own events section — what the day does not control, at an
  /// absolute hour, printed next to the day's own hours section and skipped entirely on a day with
  /// none. The same word `OcptCallSheetLabels.eventsSectionTitle` already carries, itself the same
  /// word the day view's own bordered band and the day inspector's own section carry on screen — a
  /// printed document must not name a thing differently from the screen it was planned on.
  final String eventsSectionTitle;

  /// The heading of a day agenda's own trailing guest table (`NOM / MOTIF / HORAIRES`) — the same
  /// word `OcptCallSheetLabels.guestsSectionTitle` already carries, for the same reason.
  final String guestsSectionTitle;

  /// The guest table's own `MOTIF` column header — the same word `OcptCallSheetLabels
  /// .guestReasonHeader` already carries.
  final String guestReasonHeader;

  /// The guest table's own `NOM` column header — the same word `OcptCallSheetLabels.nameHeader`
  /// already carries.
  final String nameHeader;

  /// The guest table's own `HORAIRES` column header, printing a guest's own arrival – departure
  /// band — the same word `OcptCallSheetLabels.hoursLinePrefix` already carries for the very same
  /// column of its own trailing guest table.
  final String hoursLinePrefix;

  /// The label a guest prints under when neither their address-book entry nor their own free name
  /// names anybody printable — the same word `OcptCallSheetLabels.unnamedPersonLabel` already
  /// carries.
  final String unnamedPersonLabel;

  /// Class constructor
  const OcptShootingPlanLabels({
    required this.fileNameSuffix,
    required this.documentTitle,
    required this.dayTitles,
    required this.directorLine,
    required this.versionLabel,
    required this.dayTagPrefix,
    required this.locationsGridTitle,
    required this.sequencesGridTitle,
    required this.peopleGridTitle,
    required this.locationsGridRowHeader,
    required this.sequencesGridRowHeader,
    required this.peopleGridRowHeader,
    required this.persoLabel,
    required this.sequenceRowPrefix,
    required this.presenceMark,
    required this.crewPositionLabels,
    required this.dayLocationLabel,
    required this.dayHoursLabel,
    required this.daySetsLabel,
    required this.dayTimetableLabel,
    required this.callTimeLabel,
    required this.estimatedEndLabel,
    required this.milestoneFromLabel,
    required this.milestoneToLabel,
    required this.blockKindLabels,
    required this.rolesLabel,
    required this.hoursHeader,
    required this.planHeader,
    required this.shotSizeHeader,
    required this.moveHeader,
    required this.framingHeader,
    required this.commentHeader,
    required this.emptyPlanNote,
    required this.emptyDayScheduleNote,
    required this.eventsSectionTitle,
    required this.guestsSectionTitle,
    required this.guestReasonHeader,
    required this.nameHeader,
    required this.hoursLinePrefix,
    required this.unnamedPersonLabel,
  });

  /// The title of the day [dayId], or an empty string if [dayTitles] holds none for it.
  String titleOfDay(String dayId) => dayTitles[dayId] ?? "";

  /// The label of the crew position [positionId] names, or an empty string if [crewPositionLabels]
  /// holds none for it.
  String crewPositionLabelOf(String positionId) => crewPositionLabels[positionId] ?? "";

  /// The default caption of [kind], or an empty string if [blockKindLabels] holds none for it.
  String blockKindLabelOf(OcptShootingBlockKind kind) => blockKindLabels[kind] ?? "";

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptShootingPlanLabels(documentTitle: $documentTitle, dayCount: ${dayTitles.length})";

  /// Object properties
  @override
  List<Object?> get props => [
    fileNameSuffix,
    documentTitle,
    dayTitles,
    directorLine,
    versionLabel,
    dayTagPrefix,
    locationsGridTitle,
    sequencesGridTitle,
    peopleGridTitle,
    locationsGridRowHeader,
    sequencesGridRowHeader,
    peopleGridRowHeader,
    persoLabel,
    sequenceRowPrefix,
    presenceMark,
    crewPositionLabels,
    dayLocationLabel,
    dayHoursLabel,
    daySetsLabel,
    dayTimetableLabel,
    callTimeLabel,
    estimatedEndLabel,
    milestoneFromLabel,
    milestoneToLabel,
    blockKindLabels,
    rolesLabel,
    hoursHeader,
    planHeader,
    shotSizeHeader,
    moveHeader,
    framingHeader,
    commentHeader,
    emptyPlanNote,
    emptyDayScheduleNote,
    eventsSectionTitle,
    guestsSectionTitle,
    guestReasonHeader,
    nameHeader,
    hoursLinePrefix,
    unnamedPersonLabel,
  ];
}

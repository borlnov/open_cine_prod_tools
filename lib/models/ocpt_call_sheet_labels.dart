// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';

/// Every localized string the exported call sheets — general and named alike — carry, resolved by
/// the caller.
///
/// `OcptCallSheetPdfService` runs in the manager layer, where there is no `BuildContext` and
/// therefore no `Tr`: the same reason `OcptBreakdownSheetsLabels` and
/// `OcptScenarioCoverageLabels` already exist for the exports before it.
///
/// [dayTitles] and [directorLine] are the two entries resolved by the caller rather than formatted
/// here, exactly the trade `OcptBreakdownSheetsLabels.sceneTitles` already makes: a day's own
/// title (`FEUILLE DE SERVICE DU JEUDI 10 AOÛT 2023`) needs its date formatted through `intl` in the
/// UI's own locale, which a manager-layer service has no `Localizations` to reach, and a director's
/// name is the project's own text rather than something to translate.
///
/// Every accessor returns an empty string (or, for a map keyed by an enum, the same) for a key it
/// holds nothing for, exactly as `OcptBreakdownSheetsLabels`'s own accessors do: a missing
/// translation prints as a blank rather than as a crash on a document a crew is waiting for.
class OcptCallSheetLabels extends Equatable {
  /// The prefix the suggested file name is built with (`FDS-J2.pdf`, `FDS-J2-Elisa-Mabit.pdf`).
  final String fileNamePrefix;

  /// The document's own generic name, printed small above every sheet as its running head beside
  /// the project's — the flowing page may run onto a second sheet on a busy day, exactly as a
  /// breakdown sheet may.
  final String documentTitle;

  /// The full title of each day's sheet, keyed by `OcptShootingDay.id` — see the class doc comment
  /// for why it is resolved by the caller.
  final Map<String, String> dayTitles;

  /// The `Un film de <director>` line printed under the project's own title, or an empty string
  /// while the project names no director — see the class doc comment for why it is resolved by the
  /// caller.
  final String directorLine;

  /// The label the moment this sheet was produced is printed under, in the title block
  /// (`Version 2026-08-08 14:32`) — the same word `OcptShootingPlanLabels.versionLabel` carries, so
  /// the two documents of one shoot name their own issue identically.
  final String versionLabel;

  /// The day tag's own letter (`D`/`J`), printed beside a day's rank exactly as
  /// `OcptShotListXlsxLabels.dayTagPrefix` already is.
  final String dayTagPrefix;

  /// The label of the day-number line (`JOUR : 2`).
  final String dayNumberLabel;

  /// The heading of the general sheet's recipients line — the day's own convoked people, by first
  /// name.
  final String recipientsSectionTitle;

  /// The label a named sheet's own header line is printed under (`Pour : <name>`).
  final String namedRecipientLabel;

  /// The heading of the crew note section.
  final String crewNoteSectionTitle;

  /// The heading of the location section.
  final String locationSectionTitle;

  /// The label printed before a location's Google Maps link, when it has coordinates to build one
  /// from.
  final String mapsLinkLabel;

  /// The heading of the sun and twilight block.
  final String sunSectionTitle;

  /// The label of the morning civil twilight figure.
  final String civilDawnLabel;

  /// The label of the sunrise figure.
  final String sunriseLabel;

  /// The label of the sunset figure.
  final String sunsetLabel;

  /// The label of the evening civil twilight figure.
  final String civilDuskLabel;

  /// The heading of the key-contacts block (production and direction) and of the by-department
  /// contacts table alike.
  final String contactsSectionTitle;

  /// The display label of every [OcptCrewDepartment], naming a contacts column or a crew list's own
  /// department grouping.
  final Map<OcptCrewDepartment, String> crewDepartmentLabels;

  /// The display label of every catalogued crew position (`ocptCrewPositions`), keyed by
  /// [OcptCrewDepartment]-agnostic position id — the same map `OcptResourcesXlsxLabels
  /// .crewPositionLabels` already carries for the resources workbook.
  final Map<String, String> crewPositionLabels;

  /// The prefix of a time-band line (`HORAIRES <slot> : 16:45 – 22:45`), and the header of a
  /// people list's own schedule column (`HORAIRES`) — the same word either way.
  final String hoursLinePrefix;

  /// The label of the *prêt à tourner* band (`PAT`), printed as the cast table's own column header
  /// and as the `HORAIRES PAT :` band line alike.
  final String patLabel;

  /// The header of a person's arrival figure — the cast table's own `ARRIVÉE` column, and a named
  /// sheet's own band line.
  final String arrivalHeader;

  /// The label of a person's departure figure on a named sheet's own band line.
  final String departureLabel;

  /// The heading of a named sheet's own "to bring" section — the elements its recipient is due to
  /// bring to the scenes the day plays. Never printed on the general sheet, which is the day's own
  /// paperwork rather than any one recipient's: see the class doc comment.
  final String toBringSectionTitle;

  /// The default caption of every non-shooting block kind but [OcptShootingBlockKind.shot], printed
  /// on a milestone row that carries no free-text label of its own. A [OcptShootingBlockKind.hold]
  /// block prints its own sequence's heading instead when it has one (`sceneId`), and only falls
  /// back to this map when it doesn't.
  final Map<OcptShootingBlockKind, String> blockKindLabels;

  /// The main table's `SEQ` column header, shared with the cast table's own `SEQ` column.
  final String seqHeader;

  /// The main table's `PLANS` column header.
  final String plansHeader;

  /// The main table's `EFFET` column header.
  final String effetHeader;

  /// The main table's `DÉCORS` column header.
  final String decorsHeader;

  /// The main table's `RÔLES` column header.
  final String rolesHeader;

  /// The heading of the day's own cast table (`RÔLE / COMÉDIEN / SEQ / ARRIVÉE / PAT`).
  final String castSectionTitle;

  /// The cast table's `RÔLE` column header, also used as a named sheet's own label when its
  /// recipient is an uncast role.
  final String roleHeader;

  /// The cast table's `COMÉDIEN` column header.
  final String actorHeader;

  /// A people list's `NOM` column header.
  final String nameHeader;

  /// A people list's `POSTE(S)` column header, also used as a named sheet's own label for the
  /// positions or role its recipient is convoked under.
  final String positionsHeader;

  /// A people list's `TEL.` column header.
  final String phoneHeader;

  /// A people list's `MAIL` column header.
  final String emailHeader;

  /// The heading of the closing crew list (`MEMBRES DE L'ÉQUIPE`).
  final String crewListSectionTitle;

  /// The heading of the closing cast-and-extras list.
  final String castAndExtrasListSectionTitle;

  /// The note printed in place of the main table on a day with no slot, or no block on any of them.
  final String emptyDayNote;

  /// The label a person prints under when they hold no usable name — the person a named sheet's own
  /// file name falls back to as well, so the two never disagree.
  final String unnamedPersonLabel;

  /// The heading of the day's own events section — what the day does not control, at an absolute
  /// hour, printed on both sheets alike. The same word the day view's own bordered band and the day
  /// inspector's own section already carry on screen, so a printed sheet cannot name it differently.
  final String eventsSectionTitle;

  /// The heading of the day's own trailing guest table (`NOM / MOTIF / HORAIRES`) — the same word
  /// the `Convocations` dock panel's own trailing guest group already carries, a guest being on the
  /// day and owed an hour without being part of the call an assistant director reads down.
  final String guestsSectionTitle;

  /// The guest table's own `MOTIF` column header — why a guest is on set, joined from that guest's
  /// own `shooting_slot_guests` rows rather than read off the convocation, which carries none.
  final String guestReasonHeader;

  /// Class constructor
  const OcptCallSheetLabels({
    required this.fileNamePrefix,
    required this.documentTitle,
    required this.dayTitles,
    required this.directorLine,
    required this.versionLabel,
    required this.dayTagPrefix,
    required this.dayNumberLabel,
    required this.recipientsSectionTitle,
    required this.namedRecipientLabel,
    required this.crewNoteSectionTitle,
    required this.locationSectionTitle,
    required this.mapsLinkLabel,
    required this.sunSectionTitle,
    required this.civilDawnLabel,
    required this.sunriseLabel,
    required this.sunsetLabel,
    required this.civilDuskLabel,
    required this.contactsSectionTitle,
    required this.crewDepartmentLabels,
    required this.crewPositionLabels,
    required this.hoursLinePrefix,
    required this.patLabel,
    required this.arrivalHeader,
    required this.departureLabel,
    required this.toBringSectionTitle,
    required this.blockKindLabels,
    required this.seqHeader,
    required this.plansHeader,
    required this.effetHeader,
    required this.decorsHeader,
    required this.rolesHeader,
    required this.castSectionTitle,
    required this.roleHeader,
    required this.actorHeader,
    required this.nameHeader,
    required this.positionsHeader,
    required this.phoneHeader,
    required this.emailHeader,
    required this.crewListSectionTitle,
    required this.castAndExtrasListSectionTitle,
    required this.emptyDayNote,
    required this.unnamedPersonLabel,
    required this.eventsSectionTitle,
    required this.guestsSectionTitle,
    required this.guestReasonHeader,
  });

  /// The title of the day [dayId], or an empty string if [dayTitles] holds none for it.
  String titleOfDay(String dayId) => dayTitles[dayId] ?? "";

  /// The label of [department], or an empty string if [crewDepartmentLabels] holds none for it.
  String crewDepartmentLabelOf(OcptCrewDepartment department) => crewDepartmentLabels[department] ?? "";

  /// The label of the crew position [positionId] names, or an empty string if [crewPositionLabels]
  /// holds none for it.
  String crewPositionLabelOf(String positionId) => crewPositionLabels[positionId] ?? "";

  /// The default caption of [kind], or an empty string if [blockKindLabels] holds none for it.
  String blockKindLabelOf(OcptShootingBlockKind kind) => blockKindLabels[kind] ?? "";

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptCallSheetLabels(documentTitle: $documentTitle, dayCount: ${dayTitles.length})";

  /// Object properties
  @override
  List<Object?> get props => [
    fileNamePrefix,
    documentTitle,
    dayTitles,
    directorLine,
    versionLabel,
    dayTagPrefix,
    dayNumberLabel,
    recipientsSectionTitle,
    namedRecipientLabel,
    crewNoteSectionTitle,
    locationSectionTitle,
    mapsLinkLabel,
    sunSectionTitle,
    civilDawnLabel,
    sunriseLabel,
    sunsetLabel,
    civilDuskLabel,
    contactsSectionTitle,
    crewDepartmentLabels,
    crewPositionLabels,
    hoursLinePrefix,
    patLabel,
    arrivalHeader,
    departureLabel,
    toBringSectionTitle,
    blockKindLabels,
    seqHeader,
    plansHeader,
    effetHeader,
    decorsHeader,
    rolesHeader,
    castSectionTitle,
    roleHeader,
    actorHeader,
    nameHeader,
    positionsHeader,
    phoneHeader,
    emailHeader,
    crewListSectionTitle,
    castAndExtrasListSectionTitle,
    emptyDayNote,
    unnamedPersonLabel,
    eventsSectionTitle,
    guestsSectionTitle,
    guestReasonHeader,
  ];
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';

/// Every localized string the exported contact list carries, resolved by the caller.
///
/// `OcptContactListPdfService` runs in the manager layer, where there is no `BuildContext` and
/// therefore no `Tr`: the same reason `OcptBreakdownSheetsLabels` and `OcptResourcesXlsxLabels`
/// already exist for the two exports before it. The UI builds this once through
/// `ocptContactListLabelsOf`, which reuses the very `ocptCrewDepartmentLabel`/`ocptCrewPositionLabel`
/// helpers the resources mode's own person sheet calls, so a printed department or position can
/// never read differently from the screen.
///
/// Every accessor returns an empty string for a key it holds nothing for, exactly as
/// `OcptResourcesXlsxLabels`'s own accessors do: a missing translation prints as a blank rather than
/// as a crash on a document a whole crew is waiting for.
class OcptContactListLabels extends Equatable {
  /// The suffix the suggested file name is built with (`<project> - <suffix>.pdf`).
  final String fileNameSuffix;

  /// The document's own name, printed small in the running head beside the project's, and once
  /// more, large, at the top of the first page.
  final String documentTitle;

  /// The label the moment this document was produced is printed under, in the running head
  /// (`Version 2026-08-08 14:32`) — the same word the schedule's own PDF exports carry, so a
  /// production reissuing this list can tell two copies of it apart.
  final String versionLabel;

  /// The heading of the crew section, grouped by department.
  final String crewSectionTitle;

  /// The heading of the cast section, one row per role.
  final String castSectionTitle;

  /// The header of the name column, shared by the crew and the cast tables.
  final String nameHeader;

  /// The header of the position column: a crew row's own catalogued or free-text position, a cast
  /// row's role number and name.
  final String positionHeader;

  /// The header of the phone column.
  final String phoneHeader;

  /// The header of the email column.
  final String emailHeader;

  /// The display label of every [OcptCrewDepartment], naming a crew group's own band.
  final Map<OcptCrewDepartment, String> crewDepartmentLabels;

  /// The display label of every catalogued crew position (`ocptCrewPositions`), keyed by its id —
  /// the same map `OcptResourcesXlsxLabels.crewPositionLabels` already carries for the resources
  /// workbook.
  final Map<String, String> crewPositionLabels;

  /// The heading of the trailing group a free-label position (or one naming a catalogue entry
  /// retired since) lands in — no department of its own, grouped last, exactly as the schedule
  /// mode's own positions matrix already groups them.
  final String unassignedDepartmentLabel;

  /// The note printed in place of the whole document when nobody in the address book holds a
  /// position and no role is cast either — there is no line to print.
  final String emptyDocumentNote;

  /// Class constructor
  const OcptContactListLabels({
    required this.fileNameSuffix,
    required this.documentTitle,
    required this.versionLabel,
    required this.crewSectionTitle,
    required this.castSectionTitle,
    required this.nameHeader,
    required this.positionHeader,
    required this.phoneHeader,
    required this.emailHeader,
    required this.crewDepartmentLabels,
    required this.crewPositionLabels,
    required this.unassignedDepartmentLabel,
    required this.emptyDocumentNote,
  });

  /// The label of [department], or an empty string if [crewDepartmentLabels] holds none for it.
  String crewDepartmentLabelOf(OcptCrewDepartment department) => crewDepartmentLabels[department] ?? "";

  /// The label of the crew position [positionId] names, or an empty string if [crewPositionLabels]
  /// holds none for it.
  String crewPositionLabelOf(String positionId) => crewPositionLabels[positionId] ?? "";

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptContactListLabels(documentTitle: $documentTitle)";

  /// Object properties
  @override
  List<Object?> get props => [
    fileNameSuffix,
    documentTitle,
    versionLabel,
    crewSectionTitle,
    castSectionTitle,
    nameHeader,
    positionHeader,
    phoneHeader,
    emailHeader,
    crewDepartmentLabels,
    crewPositionLabels,
    unassignedDepartmentLabel,
    emptyDocumentNote,
  ];
}

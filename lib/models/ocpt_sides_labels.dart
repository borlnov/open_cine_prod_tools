// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';

/// Every localized string the exported sides booklet carries, resolved by the caller.
///
/// `OcptSidesPdfService` runs in the manager layer, where there is no `BuildContext` and therefore
/// no `Tr`: the same reason `OcptOneLineScheduleLabels` and its own siblings already exist for
/// every export before it.
///
/// [dayTitle] is the one entry resolved by the caller rather than formatted here, exactly the trade
/// `OcptOneLineScheduleLabels.dayTitles` already makes — a day band's own title needs `intl` in the
/// UI's own locale, which a manager-layer service has no `Localizations` to reach. It is a single
/// string rather than a map keyed by day id: unlike the one-line schedule, which prints a whole
/// shoot's worth of days in one flow, a sides booklet is produced **for one day**, so there is only
/// ever one title to carry.
class OcptSidesLabels extends Equatable {
  /// The localized word telling this document apart from the other PDFs the app writes
  /// (`My Movie - sides - D3.pdf`), read by `OcptSidesPdfService.sidesFileName`. A blank one drops
  /// that segment of the file name, exactly as its siblings' own suffix does.
  final String fileNameSuffix;

  /// The document's own generic name, printed on every page's own running head beside the day tag
  /// (`Sides`).
  final String documentTitle;

  /// The label the moment this export was produced is printed under (`Version`), in every page's
  /// own running foot — the same word every schedule document prints its own
  /// `ocptScheduleGeneratedAtStamp` behind.
  final String versionLabel;

  /// The day tag's own letter (`D`/`J`), printed in the running head beside the printed day's own
  /// number, exactly as `OcptOneLineScheduleLabels.dayTagPrefix` already is.
  final String dayTagPrefix;

  /// The printed day's own full title, printed in the running head after its tag — see the class
  /// doc comment for why it is a single string, resolved by the caller.
  final String dayTitle;

  /// The word a screenplay page number is printed behind in the running head (`p.`), for a
  /// `OcptSidesPresentation.scriptPages` page — the screenplay's own pagination, which is the whole
  /// point of a side, so it is named rather than merely shown as a bare figure.
  final String scriptPagePrefix;

  /// The note printed in place of the whole booklet when the printed day plays no scene the
  /// screenplay still holds.
  final String emptyDayNote;

  /// Class constructor
  const OcptSidesLabels({
    required this.fileNameSuffix,
    required this.documentTitle,
    required this.versionLabel,
    required this.dayTagPrefix,
    required this.dayTitle,
    required this.scriptPagePrefix,
    required this.emptyDayNote,
  });

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptSidesLabels(documentTitle: $documentTitle, dayTitle: $dayTitle)";

  /// Object properties
  @override
  List<Object?> get props => [
    fileNameSuffix,
    documentTitle,
    versionLabel,
    dayTagPrefix,
    dayTitle,
    scriptPagePrefix,
    emptyDayNote,
  ];
}

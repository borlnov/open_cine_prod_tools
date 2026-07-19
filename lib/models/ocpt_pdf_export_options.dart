// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// The options a one-off PDF export runs with: the physical page [format], its [margins], and
/// the two content toggles [includeSceneNumbers]/[includeTitlePage].
///
/// [margins] is always carried through unedited from the `OcptPageSetup` the export dialog was
/// opened with (`OcptEditorExportPdfOptionsDialog` never lets the user edit it, only the page
/// [format]): unlike `OcptPageSetup`, these options are never persisted, they only exist for the
/// single export they were built for.
class OcptPdfExportOptions extends Equatable {
  /// The physical page format to typeset the exported PDF with.
  final OcptPageFormat format;

  /// The page margins to typeset the exported PDF with, carried through unedited from the page
  /// setup the export dialog was opened with.
  final FountainPageMargins margins;

  /// Whether scene numbers are printed in both margins opposite each scene heading.
  final bool includeSceneNumbers;

  /// Whether a title page is generated from the screenplay's title-page metadata.
  final bool includeTitlePage;

  /// Class constructor
  const OcptPdfExportOptions({
    required this.format,
    required this.margins,
    required this.includeSceneNumbers,
    required this.includeTitlePage,
  });

  /// Copy the current options and update the given elements
  OcptPdfExportOptions copyWith({
    OcptPageFormat? format,
    FountainPageMargins? margins,
    bool? includeSceneNumbers,
    bool? includeTitlePage,
  }) => OcptPdfExportOptions(
    format: format ?? this.format,
    margins: margins ?? this.margins,
    includeSceneNumbers: includeSceneNumbers ?? this.includeSceneNumbers,
    includeTitlePage: includeTitlePage ?? this.includeTitlePage,
  );

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptPdfExportOptions(format: $format, margins: $margins, "
      "includeSceneNumbers: $includeSceneNumbers, includeTitlePage: $includeTitlePage)";

  /// Object properties
  @override
  List<Object?> get props => [format, margins, includeSceneNumbers, includeTitlePage];
}

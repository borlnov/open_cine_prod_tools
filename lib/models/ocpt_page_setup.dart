// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// The full page setup a screenplay is typeset with: its physical page [format] plus its
/// [margins].
///
/// [format] is a property of the open project (`project_info.pageFormat`), while [margins] are an
/// app-wide rendering preference (stored in `OcptPropertiesManager.pageMargins`); this class only
/// pairs them together and turns them into the [FountainLayoutMetrics] the editor/preview lay text
/// out with, through [toMetrics].
class OcptPageSetup extends Equatable {
  /// The physical page format the screenplay is typeset with.
  final OcptPageFormat format;

  /// The page margins the screenplay is typeset with.
  final FountainPageMargins margins;

  /// Class constructor
  const OcptPageSetup({required this.format, required this.margins});

  /// The default page setup: [OcptPageFormat.usLetter] with [FountainPageMargins.standard].
  const OcptPageSetup.standard()
    : format = OcptPageFormat.usLetter,
      margins = const FountainPageMargins.standard();

  /// Copy the current page setup and update the given elements
  OcptPageSetup copyWith({OcptPageFormat? format, FountainPageMargins? margins}) => OcptPageSetup(
    format: format ?? this.format,
    margins: margins ?? this.margins,
  );

  /// Builds the [FountainLayoutMetrics] matching this page setup.
  ///
  /// This is the single `switch (format)` of the whole app: every call site that needs the page
  /// metrics for a screenplay goes through this method instead of switching over [format] itself.
  FountainLayoutMetrics toMetrics() => switch (format) {
    OcptPageFormat.usLetter => FountainLayoutMetrics.usLetter(margins: margins),
    OcptPageFormat.a4 => FountainLayoutMetrics.a4(margins: margins),
  };

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() => "OcptPageSetup(format: $format, margins: $margins)";

  /// Object properties
  @override
  List<Object?> get props => [format, margins];
}

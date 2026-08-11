// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_export_file_name.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:pdf/widgets.dart' as pw;

/// Renders a parsed [FountainDocument] into a paginated, Courier-Prime-embedded screenplay PDF.
///
/// This is pure rendering logic with no dialog or file-system access of its own: it's owned by
/// `OcptExportManager` and exposed as a public final field, reached through the manager rather than
/// through `globalGetIt()` (RFL18). It consumes [FountainScriptComposer] (from `fountain_kit`,
/// which must stay Flutter-free) for the body's line-level pagination and [OcptScriptPagePainter]
/// for the drawing itself, so the screenplay it prints is the very same drawing the scenario
/// coverage export prints under its bars.
class OcptPdfExportService {
  /// Creates an [OcptPdfExportService].
  ///
  /// Deliberately not `const` (unlike the sibling `OcptFountainIoService`): this service loads its
  /// fonts through [fontsLoader], whose cache is mutable state. Pass the manager's own loader so
  /// every export of the app session shares one; a service built without one gets a loader of its
  /// own.
  OcptPdfExportService({OcptCourierPrimeFontsLoader? fontsLoader})
    : fontsLoader = fontsLoader ?? OcptCourierPrimeFontsLoader();

  /// The Fountain-to-page-layout engine, stateless so one instance is shared across every
  /// [generate] call.
  static const FountainScriptComposer _composer = FountainScriptComposer();

  /// The loader the embedded Courier Prime font set is read through.
  final OcptCourierPrimeFontsLoader fontsLoader;

  /// The `.pdf` file name to suggest when exporting the project named [projectName], mirroring
  /// `OcptFountainIoService.fountainFileName`. [episodeTag] is the selected episode's own tag,
  /// present only while the open project holds more than one episode — see
  /// `ocptExportFileNameOf`'s own doc comment.
  String pdfFileName({required String projectName, String? episodeTag}) => ocptExportFileNameOf(
    projectName: projectName,
    episodeTag: episodeTag,
    extension: "pdf",
  );

  /// Renders [document] into a complete screenplay PDF, returning its bytes.
  ///
  /// [pageSetup] supplies both the physical page geometry (via [OcptPageSetup.toMetrics]) and,
  /// indirectly, the body's pagination (which depends on that same geometry). [includeTitlePage]
  /// toggles a leading title page built from [document]'s title page metadata (or a minimal
  /// [projectName] fallback when that metadata is absent or has no usable title).
  /// [includeSceneNumbers] toggles the both-margins scene number annotations opposite every
  /// explicitly numbered scene heading.
  Future<Uint8List> generate({
    required FountainDocument document,
    required OcptPageSetup pageSetup,
    required String projectName,
    required bool includeSceneNumbers,
    required bool includeTitlePage,
  }) async {
    final metrics = pageSetup.toMetrics();
    final painter = OcptScriptPagePainter(metrics: metrics, fonts: await fontsLoader.load());
    final pdfDocument = pw.Document();

    if (includeTitlePage) {
      pdfDocument.addPage(
        painter.buildTitlePage(titlePage: document.titlePage, projectName: projectName),
      );
    }

    final layout = _composer.compose(document: document, metrics: metrics);
    for (var index = 0; index < layout.pages.length; index++) {
      pdfDocument.addPage(
        painter.buildScriptPage(
          page: layout.pages[index],
          // Script pages are 1-based for the printed page number, and the very first one is never
          // numbered (professional convention).
          pageNumber: index + 1,
          includeSceneNumbers: includeSceneNumbers,
        ),
      );
    }

    return pdfDocument.save();
  }
}

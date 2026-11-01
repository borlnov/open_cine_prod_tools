// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:open_cine_prod_tools/managers/abs_ocpt_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts_loader.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_export_file_name.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_floor_plan_shape_sections.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_floor_plan_style.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_symbol_shape.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_floor_plan_geometry.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Render the floor plans of a shot list: per sequence, per linked set, one page per shot that has
/// a camera placed on it — the set drawn in that shot's own focus, no ghosts — or, for a set no
/// shot has a camera on, one page of its bare décor.
///
/// This is pure rendering logic with no dialog or file-system access of its own: it's owned by
/// `OcptExportManager` and exposed as a public final field, reached through the manager rather than
/// through `globalGetIt()`, exactly like its siblings.
///
/// **It draws the very same [OcptFloorPlanSheet] the on-screen canvas draws**
/// (`OcptFloorPlanCanvasPainter`, `lib/ui/pages/workspace/modes/shot_list/widgets/
/// ocpt_floor_plan_canvas_painter.dart`): [OcptFloorPlanSheet.of] is called with no ghosts (a print
/// shows one shot's own blocking, never the previous or next one's), and every shape it returns —
/// already in metres, already carrying its [OcptFloorPlanSymbolShape.colorArgb] — is placed on the
/// page through the shared pure rule the canvas itself reads geometry from,
/// `lib/models/rules/ocpt_floor_plan_geometry.dart` ([ocptFloorPlanPixelsPerMetreAt],
/// [ocptFloorPlanMetresToPixels], [ocptFloorPlanScaleBarLengthM]): this service supplies the one
/// thing a printed page needs that a pannable, zoomable canvas doesn't — the zoom that fits a set's
/// own shapes onto the page — and hands every metre through the very same conversion from there on,
/// so the two can never disagree about what a given scale looks like.
///
/// **The underlay prints as the real referenced image, read at render time, exactly like a
/// storyboard panel's own frame** (`OcptStoryboardPdfService`, same `pw.MemoryImage`, JPEG/PNG
/// technique) — it is the visual reference the whole schematic is aligned against on screen, so a
/// floor plan printed without it would be missing the point of having one. It is drawn as a
/// [pw.Positioned] [pw.Transform.rotate]d [pw.Image] widget, sized and centred at its own stored
/// metres frame mapped through [OcptFloorPlanPageLayout], **beneath** the [pw.CustomPaint] that
/// draws every shape — never inside that `CustomPaint`'s own `PdfGraphics` calls, since a rotated
/// image has no axis-aligned `PdfGraphics.drawImage` equivalent, while the widget layer's own
/// `Transform.rotate` (mirroring the on-screen `OcptFloorPlanCanvas._buildUnderlayVisual`'s
/// `Positioned` + `Transform.rotate` around an unrotated `Positioned` rect) handles it for free. A
/// missing or undecodable file (ADR 0013) falls back to the schematic frame this class used to
/// always draw — [OcptFloorPlanShapeSections.paintUnderlayFrame], now the fallback rather than the
/// rule.
class OcptFloorPlanPdfService extends AbsOcptService {
  /// The loader the embedded Courier Prime font set is read through.
  final OcptCourierPrimeFontsLoader fontsLoader;

  /// Create an [OcptFloorPlanPdfService].
  ///
  /// Pass the manager's own [fontsLoader] so every export of the app session shares one font cache;
  /// a service built without one gets a loader of its own.
  OcptFloorPlanPdfService({required super.logger, OcptCourierPrimeFontsLoader? fontsLoader})
    : fontsLoader = fontsLoader ?? OcptCourierPrimeFontsLoader();

  /// Get the `.pdf` file name to suggest when exporting the floor plans of [projectName]. See
  /// `OcptScenarioCoveragePdfService.coverageFileName`'s own doc comment for [suffix] and
  /// [episodeTag].
  String floorPlansFileName({
    required String projectName,
    required String suffix,
    String? episodeTag,
  }) => ocptExportFileNameOf(
    projectName: projectName,
    suffix: suffix,
    episodeTag: episodeTag,
    extension: "pdf",
  );

  /// Render the floor plans of [snapshot]/[floorPlanSnapshot], returning the PDF's bytes.
  ///
  /// [pageSetup] supplies the page geometry (and, through it, the Courier Prime the running head
  /// and every label print in). The orphan group contributes nothing: a floor plan's tabs come
  /// from a scene's own `scene_sets` links, and the orphan group is no scene.
  Future<Uint8List> generate({
    required OcptShotListSnapshot snapshot,
    required OcptFloorPlanSnapshot floorPlanSnapshot,
    required OcptPageSetup pageSetup,
    required OcptFloorPlanLabels labels,
    required String projectName,
  }) async {
    final metrics = pageSetup.toMetrics();
    final painter = OcptScriptPagePainter(metrics: metrics, fonts: await fontsLoader.load());

    final pdfDocument = pw.Document();
    for (final sequence in snapshot.sequences) {
      if (sequence is! OcptSceneShotSequence) {
        continue;
      }
      final pages = await pagesOfSequence(
        painter: painter,
        labels: labels,
        sequence: sequence,
        floorPlanSnapshot: floorPlanSnapshot,
        projectName: projectName,
      );
      for (final page in pages) {
        pdfDocument.addPage(page);
      }
    }

    return pdfDocument.save();
  }

  /// Get every page [sequence]'s own linked sets print, in tab order — one page per shot with a
  /// camera,
  /// or one bare-décor page for a set with none.
  ///
  /// Public so `OcptStoryboardPdfService` can append the very same pages after a sequence's own
  /// shot rows, when its `Include the floor plans after each sequence` toggle is on — the two
  /// documents must never draw a set's plan two different ways. Async because a set's own
  /// underlay image is read here, once per
  /// set, ahead of building its (possibly several) pages, rather than once per page.
  Future<List<pw.Page>> pagesOfSequence({
    required OcptScriptPagePainter painter,
    required OcptFloorPlanLabels labels,
    required OcptSceneShotSequence sequence,
    required OcptFloorPlanSnapshot floorPlanSnapshot,
    required String projectName,
  }) async {
    final shotRankByShotId = <String, int>{
      for (var i = 0; i < sequence.shots.length; i++) sequence.shots[i].id: i + 1,
    };

    final pages = <pw.Page>[];
    for (final floorPlanSet in floorPlanSnapshot.setsOfScene(sequence.sceneId)) {
      final underlayImage = await _readImageOrNull(floorPlanSet.underlayPath);
      pages.addAll(
        _pagesOfSet(
          painter: painter,
          labels: labels,
          sequence: sequence,
          floorPlanSet: floorPlanSet,
          shotRankByShotId: shotRankByShotId,
          projectName: projectName,
          underlayImage: underlayImage,
        ),
      );
    }
    return pages;
  }

  /// Get the pages [floorPlanSet] itself contributes: one per shot of [sequence] holding a live
  /// camera
  /// on it, in the sequence's own order, or exactly one bare-décor page when none does.
  /// [underlayImage] is the set's own underlay, already resolved by [pagesOfSequence], or null
  /// while it has none placed or its file could not be read/decoded — the same image (or absence)
  /// prints on every page this set contributes.
  List<pw.Page> _pagesOfSet({
    required OcptScriptPagePainter painter,
    required OcptFloorPlanLabels labels,
    required OcptSceneShotSequence sequence,
    required OcptFloorPlanSet floorPlanSet,
    required Map<String, int> shotRankByShotId,
    required String projectName,
    required pw.MemoryImage? underlayImage,
  }) {
    final shotsWithCamera = [
      for (final shot in sequence.shots)
        if (floorPlanSet.symbols.any(
          (symbol) => symbol.shotId == shot.id && symbol.layer == OcptFloorPlanLayer.cameras,
        ))
          shot,
    ];

    if (shotsWithCamera.isEmpty) {
      final sheet = OcptFloorPlanSheet.of(
        floorPlanSet: floorPlanSet,
        focusSceneId: sequence.sceneId,
        focusShotId: null,
        shotRankByShotId: shotRankByShotId,
      );
      return [
        _buildPage(
          painter: painter,
          labels: labels,
          sequence: sequence,
          floorPlanSet: floorPlanSet,
          sheet: sheet,
          shot: null,
          projectName: projectName,
          underlayImage: underlayImage,
        ),
      ];
    }

    return [
      for (final shot in shotsWithCamera)
        _buildPage(
          painter: painter,
          labels: labels,
          sequence: sequence,
          floorPlanSet: floorPlanSet,
          sheet: OcptFloorPlanSheet.of(
            floorPlanSet: floorPlanSet,
            focusSceneId: sequence.sceneId,
            focusShotId: shot.id,
            shotRankByShotId: shotRankByShotId,
            // Never ghosted on paper: a printed sheet shows the one shot it was built for.
          ),
          shot: shot,
          projectName: projectName,
          underlayImage: underlayImage,
        ),
    ];
  }

  /// Get [path]'s bytes decoded as a `pw.MemoryImage`, or null when [path] is null, names no file,
  /// or
  /// cannot be decoded — the same normal state (ADR 0013) `OcptStoryboardPdfService` reads a
  /// panel's own image through.
  Future<pw.MemoryImage?> _readImageOrNull(String? path) async {
    if (path == null) {
      return null;
    }
    pw.MemoryImage? image;
    try {
      final bytes = await File(path).readAsBytes();
      image = pw.MemoryImage(bytes);
    } catch (error, stackTrace) {
      // A missing file is a normal state (ADR 0013): the picture is left out of the page.
      logger.d(
        'An image could not be read, leaving it out: ${error.runtimeType}',
        null,
        stackTrace,
      );
    }

    return image;
  }

  /// Build one page: the running head, the sequence/set title band, the shot's own key information
  /// (or
  /// the bare-décor note), then [sheet] drawn to fill the rest of the page.
  ///
  /// The canvas area is a [pw.Stack] over one shared layout ([OcptFloorPlanPageLayout]): the
  /// underlay image, when [underlayImage] resolved, is a [pw.Positioned] [pw.Transform.rotate]d
  /// [pw.Image] drawn **first**, so every shape prints over it; a [pw.CustomPaint] then draws every
  /// shape (the underlay's own schematic frame *only* when there is no real image to show instead,
  /// the arrows, the symbols' own footprints, the scale bar and the reference silhouette); and a
  /// [pw.Positioned] [pw.Text] is stacked over all of that for every caption — a symbol's own
  /// label, and the scale bar's length. `pdf`'s low-level `PdfGraphics.drawString` takes a
  /// `PdfFont` the widget-level `pw.Font` this app's `OcptCourierPrimeFonts` hands out cannot be
  /// converted to outside of a build context, so every piece of text this document prints goes
  /// through an ordinary `pw.Text` instead — the same choice `OcptScenarioCoveragePdfService`
  /// already made for its own bar labels.
  pw.Page _buildPage({
    required OcptScriptPagePainter painter,
    required OcptFloorPlanLabels labels,
    required OcptSceneShotSequence sequence,
    required OcptFloorPlanSet floorPlanSet,
    required OcptFloorPlanSheet sheet,
    required OcptShot? shot,
    required String projectName,
    required pw.MemoryImage? underlayImage,
  }) {
    final contentWidthPt = painter.pageWidthPt - 2 * painter.marginRightPt;
    final contentHeightPt = painter.pageHeightPt - painter.marginTopPt - painter.marginRightPt;
    final double canvasHeightPt = math.max(0, contentHeightPt - ocptFloorPlanHeaderHeightPt);
    final layout = OcptFloorPlanPageLayout.of(
      sheet: sheet,
      widthPt: contentWidthPt,
      heightPt: canvasHeightPt,
    );
    final underlay = sheet.underlay;

    return pw.Page(
      pageFormat: PdfPageFormat(
        painter.pageWidthPt,
        painter.pageHeightPt,
        marginLeft: painter.marginRightPt,
        marginTop: painter.marginTopPt,
        marginRight: painter.marginRightPt,
        marginBottom: painter.marginRightPt,
      ),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _runningHead(painter: painter, labels: labels, projectName: projectName),
          pw.SizedBox(height: 4),
          pw.Text(
            "${labels.titleOfSequence(sequence.id)} — ${floorPlanSet.name}",
            style: pw.TextStyle(font: painter.fonts.bold, fontSize: ocptFloorPlanTitleFontSizePt),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            shot == null ? labels.noCameraNote : _keyInfoLineOf(labels, shot),
            style: pw.TextStyle(
              font: painter.fonts.variant(bold: false, italic: shot == null),
              fontSize: ocptFloorPlanKeyInfoFontSizePt,
              color: shot == null ? ocptFloorPlanMutedColor : null,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.SizedBox(
            width: contentWidthPt,
            height: canvasHeightPt,
            child: pw.Stack(
              children: [
                if (underlay != null && underlayImage != null)
                  OcptFloorPlanShapeSections.underlayImageWidget(
                    underlay: underlay,
                    image: underlayImage,
                    layout: layout,
                  ),
                pw.CustomPaint(
                  size: PdfPoint(contentWidthPt, canvasHeightPt),
                  painter: (canvas, size) => OcptFloorPlanShapeSections.paintShapes(
                    canvas: canvas,
                    sheet: sheet,
                    layout: layout,
                    hasUnderlayImage: underlayImage != null,
                  ),
                ),
                ...OcptFloorPlanShapeSections.captionOverlays(
                  sheet: sheet,
                  layout: layout,
                  painter: painter,
                ),
                OcptFloorPlanShapeSections.scaleBarLabelOverlay(
                  layout: layout,
                  painter: painter,
                  labels: labels,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build the running head every page carries: the project and the document's own name.
  pw.Widget _runningHead({
    required OcptScriptPagePainter painter,
    required OcptFloorPlanLabels labels,
    required String projectName,
  }) => pw.Text(
    "$projectName — ${labels.documentTitle}",
    style: pw.TextStyle(
      font: painter.fonts.regular,
      fontSize: ocptFloorPlanHeadFontSizePt,
      color: ocptFloorPlanMutedColor,
    ),
  );

  /// Get [shot]'s own key-information line: its code, then every field [labels] names,
  /// dash-separated.
  String _keyInfoLineOf(OcptFloorPlanLabels labels, OcptShot shot) {
    final cast = shot.characters.isEmpty ? "—" : shot.characters.join(", ");
    return "${shot.code}  ·  ${labels.shotSizeLabel}: ${_orDash(shot.shotSize)}  ·  "
        "${labels.framingLabel}: ${_orDash(shot.framing)}  ·  "
        "${labels.cameraMoveLabel}: ${_orDash(shot.cameraMove)}  ·  "
        "${labels.lensLabel}: ${_orDash(shot.lens)}  ·  "
        "${labels.recordingFormatLabel}: ${_orDash(shot.recordingFormat)}  ·  "
        "${labels.castLabel}: $cast  ·  ${labels.labelOfStatus(shot.status)}";
  }

  /// Get [value] if it holds anything other than whitespace, an em dash otherwise.
  String _orDash(String value) => value.trim().isEmpty ? "—" : value;
}

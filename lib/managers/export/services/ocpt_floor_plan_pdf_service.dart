// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_export_file_name.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_arrow_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_layer.dart';
import 'package:open_cine_prod_tools/types/ocpt_floor_plan_set_element_shape.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_geometry.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The minimum half-span, in metres, a case's own bounding box is padded to on either axis when it
/// holds too little (or nothing at all) to size a sensible page from — a freshly created case with
/// one lone camera symbol still prints a legible sheet rather than one zoomed in on a single pixel.
const double _minimumHalfSpanM = 1.5;

/// The fraction of a case's own bounding box span added as breathing room on every side, so a
/// symbol sitting exactly on the edge of what was placed is never printed flush against the page's
/// own margin.
const double _boundingBoxPaddingFraction = 0.15;

/// The font size, in points, of the running head naming the project and the document.
const double _headFontSizePt = 7;

/// The font size, in points, of a page's own title band (the sequence and the case).
const double _titleFontSizePt = 13;

/// The font size, in points, of the shot's key-information line, or the bare-décor note.
const double _keyInfoFontSizePt = 9;

/// The height, in points, reserved for the header block above the canvas.
const double _headerHeightPt = 70;

/// The font size, in points, a symbol's own caption is printed at.
const double _symbolLabelFontSizePt = 7;

/// The stroke width, in points, a symbol's own border is drawn with.
const double _symbolStrokeWidthPt = 1;

/// The fill opacity a symbol's own footprint is drawn at, over its [OcptFloorPlanSymbolShape
/// .colorArgb].
const double _symbolFillOpacity = 0.3;

/// The stroke width, in points, an arrow's own shaft is drawn with.
const double _arrowStrokeWidthPt = 1.5;

/// The length, in points, of an arrow head's own two strokes.
const double _arrowHeadLengthPt = 8;

/// The angle, in radians, an arrow head's two strokes open at.
const double _arrowHeadAnglePt = 0.5;

/// The dash pattern (`[dash, gap]`, in points) a [OcptFloorPlanArrowKind.cameraMove] arrow's own
/// shaft, and a [OcptFloorPlanSetElementShape.freeform] décor primitive's own outline, are drawn
/// with — `PdfGraphics.setLineDashPattern`'s own units, the printed equivalent of the canvas
/// painter's manually dashed path.
const List<num> _dashPattern = [3, 2];

/// How far, in metres, a camera's own field-of-view wedge reaches from its lens.
const double _cameraFovWedgeLengthM = 2;

/// How far, in metres, a light's own beam reaches from its body.
const double _lightBeamLengthM = 1;

/// The colour every rule, band and running head is drawn with.
const PdfColor _mutedColor = PdfColor.fromInt(0xFF6E6E6E);

/// The colour the underlay's own placeholder frame is drawn with — a schematic rectangle rather
/// than the referenced image itself (see this class's own doc comment).
const PdfColor _underlayColor = PdfColor.fromInt(0xFFDDDDDD);

/// The colour the scale bar and the reference silhouette are drawn with.
const PdfColor _scaleColor = PdfColor.fromInt(0xFF3A3A3A);

/// The radius, in points, of the reference silhouette printed beside the scale bar, at neutral
/// zoom — scaled by the very same pixels-per-metre the rest of the page's shapes are.
const double _silhouetteMarginPt = 10;

/// Renders the floor plans of a shot list: per sequence, per case, one page per shot that has a
/// camera placed on it — the case drawn in that shot's own focus, no ghosts — or, for a case no
/// shot has a camera on, one page of its bare décor (`docs/plans/storyboard.md`, §5).
///
/// This is pure rendering logic with no dialog or file-system access of its own: it's owned by
/// `OcptExportManager` and exposed as a public final field, reached through the manager rather than
/// through `globalGetIt()` (RFL18), exactly like its siblings.
///
/// **It draws the very same [OcptFloorPlanSheet] the on-screen canvas draws**
/// (`OcptFloorPlanCanvasPainter`, `lib/ui/pages/workspace/modes/shot_list/widgets/
/// ocpt_floor_plan_canvas_painter.dart`): [OcptFloorPlanSheet.of] is called with no ghosts (a print
/// shows one shot's own blocking, never the previous or next one's), and every shape it returns —
/// already in metres, already carrying its [OcptFloorPlanSymbolShape.colorArgb] — is placed on the
/// page through the shared pure rule the canvas itself reads geometry from,
/// `lib/utils/ocpt_floor_plan_geometry.dart` ([ocptFloorPlanPixelsPerMetreAt],
/// [ocptFloorPlanMetresToPixels], [ocptFloorPlanScaleBarLengthM]): this service supplies the one
/// thing a printed page needs that a pannable, zoomable canvas doesn't — the zoom that fits a
/// case's own shapes onto the page — and hands every metre through the very same conversion from
/// there on, so the two can never disagree about what a given scale looks like.
///
/// **The underlay prints as the real referenced image, read at render time, exactly like a
/// storyboard panel's own frame** (`OcptStoryboardPdfService`, same `pw.MemoryImage`, JPEG/PNG
/// technique) — it is the visual reference the whole schematic is aligned against on screen, so a
/// floor plan printed without it would be missing the point of having one. It is drawn as a
/// [pw.Positioned] [pw.Transform.rotate]d [pw.Image] widget, sized and centred at its own stored
/// metres frame mapped through [_FloorPlanPageLayout], **beneath** the [pw.CustomPaint] that draws
/// every shape — never inside that `CustomPaint`'s own `PdfGraphics` calls, since a rotated image
/// has no axis-aligned `PdfGraphics.drawImage` equivalent, while the widget layer's own
/// `Transform.rotate` (mirroring the on-screen `OcptFloorPlanCanvas._buildUnderlayVisual`'s
/// `Positioned` + `Transform.rotate` around an unrotated `Positioned` rect) handles it for free. A
/// missing or undecodable file (ADR 0013) falls back to the schematic frame this class used to
/// always draw — [_paintUnderlayFrame], now the fallback rather than the rule.
class OcptFloorPlanPdfService {
  /// Creates an [OcptFloorPlanPdfService].
  ///
  /// Pass the manager's own [fontsLoader] so every export of the app session shares one font cache;
  /// a service built without one gets a loader of its own.
  OcptFloorPlanPdfService({OcptCourierPrimeFontsLoader? fontsLoader})
    : fontsLoader = fontsLoader ?? OcptCourierPrimeFontsLoader();

  /// The loader the embedded Courier Prime font set is read through.
  final OcptCourierPrimeFontsLoader fontsLoader;

  /// The `.pdf` file name to suggest when exporting the floor plans of [projectName]. See
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

  /// Renders the floor plans of [snapshot]/[floorPlanSnapshot], returning the PDF's bytes.
  ///
  /// [pageSetup] supplies the page geometry (and, through it, the Courier Prime the running head
  /// and every label print in). The orphan group contributes nothing: a floor plan case is per
  /// scene, and the orphan group is no scene.
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

  /// Every page [sequence]'s own cases print, in tab order — one page per shot with a camera, or
  /// one bare-décor page for a case with none.
  ///
  /// Public so `OcptStoryboardPdfService` can append the very same pages after a sequence's own
  /// shot rows, when its `Include the floor plans after each sequence` toggle is on
  /// (`docs/plans/storyboard.md`, §5, §8 decision 8) — the two documents must never draw a case's
  /// plan two different ways. Async because a case's own underlay image is read here, once per
  /// case, ahead of building its (possibly several) pages, rather than once per page.
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

  /// The pages [floorPlanSet] itself contributes: one per shot of [sequence] holding a live camera
  /// on it, in the sequence's own order, or exactly one bare-décor page when none does.
  /// [underlayImage] is the case's own underlay, already resolved by [pagesOfSequence], or null
  /// while it has none placed or its file could not be read/decoded — the same image (or absence)
  /// prints on every page this case contributes.
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

  /// [path]'s bytes decoded as a `pw.MemoryImage`, or null when [path] is null, names no file, or
  /// cannot be decoded — the same normal state (ADR 0013) `OcptStoryboardPdfService` reads a
  /// panel's own image through.
  Future<pw.MemoryImage?> _readImageOrNull(String? path) async {
    if (path == null) {
      return null;
    }
    try {
      final bytes = await File(path).readAsBytes();
      return pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  /// One page: the running head, the sequence/case title band, the shot's own key information (or
  /// the bare-décor note), then [sheet] drawn to fill the rest of the page.
  ///
  /// The canvas area is a [pw.Stack] over one shared layout ([_FloorPlanPageLayout]): the underlay
  /// image, when [underlayImage] resolved, is a [pw.Positioned] [pw.Transform.rotate]d [pw.Image]
  /// drawn **first**, so every shape prints over it; a [pw.CustomPaint] then draws every shape
  /// (the underlay's own schematic frame *only* when there is no real image to show instead, the
  /// arrows, the symbols' own footprints, the scale bar and the reference silhouette); and a
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
    final double canvasHeightPt = math.max(0, contentHeightPt - _headerHeightPt);
    final layout = _FloorPlanPageLayout.of(
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
            style: pw.TextStyle(font: painter.fonts.bold, fontSize: _titleFontSizePt),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            shot == null ? labels.noCameraNote : _keyInfoLineOf(labels, shot),
            style: pw.TextStyle(
              font: painter.fonts.variant(bold: false, italic: shot == null),
              fontSize: _keyInfoFontSizePt,
              color: shot == null ? _mutedColor : null,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.SizedBox(
            width: contentWidthPt,
            height: canvasHeightPt,
            child: pw.Stack(
              children: [
                if (underlay != null && underlayImage != null)
                  _underlayImageWidget(underlay: underlay, image: underlayImage, layout: layout),
                pw.CustomPaint(
                  size: PdfPoint(contentWidthPt, canvasHeightPt),
                  painter: (canvas, size) => _paintShapes(
                    canvas: canvas,
                    sheet: sheet,
                    layout: layout,
                    hasUnderlayImage: underlayImage != null,
                  ),
                ),
                ..._captionOverlays(sheet: sheet, layout: layout, painter: painter),
                _scaleBarLabelOverlay(layout: layout, painter: painter, labels: labels),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The running head every page carries: the project and the document's own name.
  pw.Widget _runningHead({
    required OcptScriptPagePainter painter,
    required OcptFloorPlanLabels labels,
    required String projectName,
  }) => pw.Text(
    "$projectName — ${labels.documentTitle}",
    style: pw.TextStyle(font: painter.fonts.regular, fontSize: _headFontSizePt, color: _mutedColor),
  );

  /// [shot]'s own key-information line: its code, then every field [labels] names, dash-separated.
  String _keyInfoLineOf(OcptFloorPlanLabels labels, OcptShot shot) {
    final cast = shot.characters.isEmpty ? "—" : shot.characters.join(", ");
    return "${shot.code}  ·  ${labels.shotSizeLabel}: ${_orDash(shot.shotSize)}  ·  "
        "${labels.framingLabel}: ${_orDash(shot.framing)}  ·  "
        "${labels.cameraMoveLabel}: ${_orDash(shot.cameraMove)}  ·  "
        "${labels.lensLabel}: ${_orDash(shot.lens)}  ·  "
        "${labels.recordingFormatLabel}: ${_orDash(shot.recordingFormat)}  ·  "
        "${labels.castLabel}: $cast  ·  ${labels.labelOfStatus(shot.status)}";
  }

  /// [value] if it holds anything other than whitespace, an em dash otherwise.
  String _orDash(String value) => value.trim().isEmpty ? "—" : value;

  /// The underlay's own real image: a [pw.Positioned], unrotated rect sized and centred at its
  /// stored metres frame (mapped through [layout]), wrapped in a [pw.Transform.rotate] for
  /// [OcptFloorPlanUnderlayShape.rotationDeg] — mirroring `OcptFloorPlanCanvas
  /// ._buildUnderlayVisual`'s own `Positioned` + `Transform.rotate` around an unrotated rect
  /// exactly, `pw.BoxFit.fill` included, so the printed frame matches the screen's.
  ///
  /// Deliberately a widget, not a `PdfGraphics.drawImage` call from inside [_paintShapes]: that
  /// low-level call only ever draws an axis-aligned rectangle, with no rotation of its own, while
  /// `Transform.rotate` (like its on-screen Flutter namesake) rotates around its own child's centre
  /// for free.
  pw.Widget _underlayImageWidget({
    required OcptFloorPlanUnderlayShape underlay,
    required pw.MemoryImage image,
    required _FloorPlanPageLayout layout,
  }) {
    final widthPt = underlay.widthM * layout.pixelsPerMetre;
    final heightPt = underlay.heightM * layout.pixelsPerMetre;
    final centre = layout.topDownPointOf(underlay.xM, underlay.yM);

    return pw.Positioned(
      left: centre.dx - widthPt / 2,
      top: centre.dy - heightPt / 2,
      child: pw.SizedBox(
        width: widthPt,
        height: heightPt,
        child: pw.Transform.rotate(
          angle: underlay.rotationDeg * math.pi / 180,
          child: pw.Image(image, fit: pw.BoxFit.fill),
        ),
      ),
    );
  }

  /// Draws [sheet]'s own arrows, symbol footprints, scale bar and reference silhouette onto
  /// [canvas] — every shape [layout] places, none of its captions (see [_buildPage]'s own doc
  /// comment for why those are separate [pw.Text] widgets instead). The underlay's own schematic
  /// frame is drawn here too, but only while [hasUnderlayImage] is false: a real image, drawn as
  /// its own widget beneath this `CustomPaint`, needs no placeholder rectangle under it as well.
  void _paintShapes({
    required PdfGraphics canvas,
    required OcptFloorPlanSheet sheet,
    required _FloorPlanPageLayout layout,
    required bool hasUnderlayImage,
  }) {
    if (layout.widthPt <= 0 || layout.heightPt <= 0) {
      return;
    }

    final underlay = sheet.underlay;
    if (underlay != null && !hasUnderlayImage) {
      _paintUnderlayFrame(canvas: canvas, layout: layout, underlay: underlay);
    }
    for (final arrow in sheet.arrows) {
      _paintArrow(canvas: canvas, layout: layout, arrow: arrow);
    }
    for (final symbol in sheet.symbols) {
      _paintSymbolShape(canvas: canvas, layout: layout, symbol: symbol);
    }
    _paintScaleAndSilhouette(canvas: canvas, layout: layout);
  }

  /// One [pw.Positioned] caption per symbol that carries one, placed near the symbol's own mapped
  /// centre: a camera's own derived number/letter ([OcptFloorPlanSymbolShape.cameraLabel], when
  /// set) as a filled pill in the camera's own colour — the printed equivalent of
  /// `OcptFloorPlanCanvasPainter._paintCameraLabelPill` — every other symbol's own free
  /// [OcptFloorPlanSymbolShape.label] as plain text, as before.
  List<pw.Widget> _captionOverlays({
    required OcptFloorPlanSheet sheet,
    required _FloorPlanPageLayout layout,
    required OcptScriptPagePainter painter,
  }) => [
    for (final symbol in sheet.symbols)
      if ((symbol.cameraLabel ?? symbol.label).isNotEmpty)
        _positionedTopDown(
          layout.topDownPointOf(symbol.xM, symbol.yM) + const Offset(4, 4),
          symbol.cameraLabel != null && symbol.cameraLabel!.isNotEmpty
              ? _cameraLabelPill(cameraLabel: symbol.cameraLabel!, colorArgb: symbol.colorArgb, painter: painter)
              : pw.Text(
                  symbol.label,
                  style: pw.TextStyle(font: painter.fonts.bold, fontSize: _symbolLabelFontSizePt),
                ),
        ),
  ];

  /// A camera's own derived [cameraLabel] (`3A`), as a filled pill in [colorArgb] — the mockup's
  /// own filled-pill style, white bold text on the camera's own colour.
  pw.Widget _cameraLabelPill({
    required String cameraLabel,
    required int colorArgb,
    required OcptScriptPagePainter painter,
  }) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromInt(colorArgb),
      borderRadius: pw.BorderRadius.circular(_symbolLabelFontSizePt),
    ),
    child: pw.Text(
      cameraLabel,
      style: pw.TextStyle(font: painter.fonts.bold, fontSize: _symbolLabelFontSizePt, color: PdfColors.white),
    ),
  );

  /// The scale bar's own printed length, positioned just above the bar [layout] placed.
  pw.Widget _scaleBarLabelOverlay({
    required _FloorPlanPageLayout layout,
    required OcptScriptPagePainter painter,
    required OcptFloorPlanLabels labels,
  }) => _positionedTopDown(
    Offset(layout.scaleBarLeftTopDown, layout.scaleBarTopDown - 12),
    pw.Text(
      labels.scaleBarLabelOf(ocptFloorPlanScaleBarLengthLabelOf(layout.scaleBarLengthM)),
      style: pw.TextStyle(font: painter.fonts.regular, fontSize: 8, color: _scaleColor),
    ),
  );

  /// [child] positioned at [topDown] — a `pw.Positioned` measures its own `left`/`top` from the
  /// stack's own top-left corner, exactly the convention every `topDownPointOf` in this file
  /// already computes in, so no flip is needed here (unlike every `PdfGraphics` call, which is not
  /// a widget and measures its own Y from the page's bottom).
  pw.Widget _positionedTopDown(Offset topDown, pw.Widget child) =>
      pw.Positioned(left: topDown.dx, top: topDown.dy, child: child);

  /// The underlay's own frame, drawn as a schematic rectangle — the fallback for a missing or
  /// undecodable underlay file (see this class's own doc comment).
  void _paintUnderlayFrame({
    required PdfGraphics canvas,
    required _FloorPlanPageLayout layout,
    required OcptFloorPlanUnderlayShape underlay,
  }) {
    final corners = _rotatedRectCorners(
      centreXM: underlay.xM,
      centreYM: underlay.yM,
      widthM: underlay.widthM,
      heightM: underlay.heightM,
      rotationDeg: underlay.rotationDeg,
    );
    _fillAndStrokePolygon(
      canvas: canvas,
      points: [for (final corner in corners) layout.graphicsOf(layout.topDownPointOf(corner.dx, corner.dy))],
      fillColor: _underlayColor,
      strokeColor: _underlayColor,
      strokeWidthPt: 0.75,
    );
  }

  /// One symbol's own glyph — [OcptFloorPlanSymbolShape.glyphKind] names which
  /// (a character's own disc, a camera's own body/lens/wedge, a light's own body/beam, or a décor
  /// primitive), drawn from the very same shape data `OcptFloorPlanCanvasPainter` reads, so the
  /// printed page and the screen agree. Its caption is a separate [pw.Text] overlay (see
  /// [_buildPage]'s own doc comment for why).
  void _paintSymbolShape({
    required PdfGraphics canvas,
    required _FloorPlanPageLayout layout,
    required OcptFloorPlanSymbolShape symbol,
  }) {
    switch (symbol.glyphKind) {
      case OcptFloorPlanSymbolGlyphKind.character:
        _paintCharacterGlyph(canvas: canvas, layout: layout, symbol: symbol);
      case OcptFloorPlanSymbolGlyphKind.camera:
        _paintCameraGlyph(canvas: canvas, layout: layout, symbol: symbol);
      case OcptFloorPlanSymbolGlyphKind.light:
        _paintLightGlyph(canvas: canvas, layout: layout, symbol: symbol);
      case OcptFloorPlanSymbolGlyphKind.setElement:
        _paintSetElementGlyph(canvas: canvas, layout: layout, symbol: symbol);
    }
  }

  /// `(localXM, localYM)` — metres in [symbol]'s own local frame, `(0, 0)` its own centre,
  /// unrotated, the sign convention [_rotatedRectCorners] already uses (negative Y is the symbol's
  /// own "front"/"up", matching `OcptFloorPlanCanvasPainter`'s own `canvas.rotate` convention) —
  /// rotated by [symbol]'s own [OcptFloorPlanSymbolShape.rotationDeg], translated to its own centre,
  /// then mapped into [layout]'s own graphics space. The single-point sibling of
  /// [_rotatedRectCorners], for every glyph feature beyond its own four corners: a camera's lens, a
  /// light's beam tip, a character's facing notch.
  Offset _localPointGraphics({
    required _FloorPlanPageLayout layout,
    required OcptFloorPlanSymbolShape symbol,
    required double localXM,
    required double localYM,
  }) {
    final radians = symbol.rotationDeg * math.pi / 180;
    final cosA = math.cos(radians);
    final sinA = math.sin(radians);
    final worldXM = symbol.xM + localXM * cosA - localYM * sinA;
    final worldYM = symbol.yM + localXM * sinA + localYM * cosA;
    return layout.graphicsOf(layout.topDownPointOf(worldXM, worldYM));
  }

  /// A character's own filled disc, in its own derived colour (`ocptFloorPlanCharacterColourOf` —
  /// resolved once, into [OcptFloorPlanSymbolShape.colorArgb], by `OcptFloorPlanSheet`), never
  /// white: a [ocptFloorPlanCharacterDiscFillAlpha] fill with a [ocptFloorPlanCharacterStrokeWidth]
  /// stroke, both in that same colour, plus a facing indicator (a short rim notch and two forward
  /// arms, both in that colour too) pointing the symbol's own "up" — see [_localPointGraphics]'s own
  /// doc comment for the shared bearing convention. Mirrors `OcptFloorPlanCanvasPainter
  /// ._paintCharacterGlyph`'s own geometry exactly, so paper and screen agree.
  void _paintCharacterGlyph({
    required PdfGraphics canvas,
    required _FloorPlanPageLayout layout,
    required OcptFloorPlanSymbolShape symbol,
  }) {
    final color = PdfColor.fromInt(symbol.colorArgb);
    final centre = layout.graphicsOf(layout.topDownPointOf(symbol.xM, symbol.yM));
    final radiusM = math.min(symbol.widthM, symbol.heightM) / 2;
    final radiusPt = radiusM * layout.pixelsPerMetre;

    canvas
      ..setFillColor(PdfColor(color.red, color.green, color.blue, ocptFloorPlanCharacterDiscFillAlpha).flatten())
      ..drawEllipse(centre.dx, centre.dy, radiusPt, radiusPt)
      ..fillPath();
    canvas
      ..setColor(color)
      ..setLineWidth(ocptFloorPlanCharacterStrokeWidth)
      ..drawEllipse(centre.dx, centre.dy, radiusPt, radiusPt)
      ..strokePath();

    Offset local(double xM, double yM) =>
        _localPointGraphics(layout: layout, symbol: symbol, localXM: xM, localYM: yM);

    // The unit direction at [angleRad] from local "up" (0° = up, clockwise positive) — the same
    // convention `_paintCameraGlyph`'s own wedge reads its `left`/`right` reach through.
    Offset unitDirectionAt(double angleRad) => Offset(math.sin(angleRad), -math.cos(angleRad));

    final noseRimOffsetM = ocptFloorPlanCharacterNoseRimOffset / layout.pixelsPerMetre;
    final noseTipVector = unitDirectionAt(0) * (radiusM + noseRimOffsetM);
    final noseHalfWidthM = math.max(2 / layout.pixelsPerMetre, radiusM * 0.22);
    final noseLeft = local(-noseHalfWidthM, -radiusM);
    final noseTip = local(noseTipVector.dx, noseTipVector.dy);
    final noseRight = local(noseHalfWidthM, -radiusM);
    canvas
      ..setFillColor(color)
      ..moveTo(noseLeft.dx, noseLeft.dy)
      ..lineTo(noseTip.dx, noseTip.dy)
      ..lineTo(noseRight.dx, noseRight.dy)
      ..fillPath();

    canvas
      ..setColor(color)
      ..setLineWidth(1);
    for (final sign in [-1, 1]) {
      final direction = unitDirectionAt(sign * ocptFloorPlanCharacterArmAngleRad);
      final armStartVector = direction * (radiusM * ocptFloorPlanCharacterArmStartFactor);
      final armEndVector = direction * (radiusM * ocptFloorPlanCharacterArmEndFactor);
      final armStart = local(armStartVector.dx, armStartVector.dy);
      final armEnd = local(armEndVector.dx, armEndVector.dy);
      canvas.drawLine(armStart.dx, armStart.dy, armEnd.dx, armEnd.dy);
    }
    canvas.strokePath();
  }

  /// A camera's own body, lens and, while [OcptFloorPlanSymbolShape.cameraFovWedgeDeg] is set, its
  /// field-of-view wedge — a cone [_cameraFovWedgeLengthM] long, spanning that angle, pointing the
  /// symbol's own "up" (see [_localPointGraphics]'s own doc comment).
  void _paintCameraGlyph({
    required PdfGraphics canvas,
    required _FloorPlanPageLayout layout,
    required OcptFloorPlanSymbolShape symbol,
  }) {
    final color = PdfColor.fromInt(symbol.colorArgb);
    Offset local(double xM, double yM) =>
        _localPointGraphics(layout: layout, symbol: symbol, localXM: xM, localYM: yM);

    final fovWedgeDeg = symbol.cameraFovWedgeDeg;
    if (fovWedgeDeg != null) {
      final halfAngle = fovWedgeDeg * math.pi / 180 / 2;
      final tipYM = -symbol.heightM / 2;
      final reachXM = _cameraFovWedgeLengthM * math.sin(halfAngle);
      final reachYM = tipYM - _cameraFovWedgeLengthM * math.cos(halfAngle);
      final tip = local(0, tipYM);
      final left = local(-reachXM, reachYM);
      final right = local(reachXM, reachYM);
      canvas
        ..setFillColor(PdfColor(color.red, color.green, color.blue, 0.16).flatten())
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..fillPath();
      canvas
        ..setColor(color)
        ..setLineWidth(0.5)
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..lineTo(tip.dx, tip.dy)
        ..strokePath();
    }

    final corners = _rotatedRectCorners(
      centreXM: symbol.xM,
      centreYM: symbol.yM,
      widthM: symbol.widthM,
      heightM: symbol.heightM,
      rotationDeg: symbol.rotationDeg,
    );
    _fillAndStrokePolygon(
      canvas: canvas,
      points: [for (final corner in corners) layout.graphicsOf(layout.topDownPointOf(corner.dx, corner.dy))],
      fillColor: PdfColor(color.red, color.green, color.blue, _symbolFillOpacity).flatten(),
      strokeColor: color,
      strokeWidthPt: _symbolStrokeWidthPt,
    );

    final lensRadiusM = math.min(symbol.widthM, symbol.heightM) * 0.24;
    final lensRadiusPt = lensRadiusM * layout.pixelsPerMetre;
    final lensCentre = local(0, -symbol.heightM / 2 - lensRadiusM * 0.5);
    canvas
      ..setColor(color)
      ..drawEllipse(lensCentre.dx, lensCentre.dy, lensRadiusPt, lensRadiusPt)
      ..fillPath();
    canvas
      ..setColor(color)
      ..setLineWidth(0.5)
      ..drawEllipse(lensCentre.dx, lensCentre.dy, lensRadiusPt, lensRadiusPt)
      ..strokePath();
  }

  /// A light/projector's own body, barn doors and a warm beam [_lightBeamLengthM] long, pointing
  /// the symbol's own "up" (see [_localPointGraphics]'s own doc comment).
  void _paintLightGlyph({
    required PdfGraphics canvas,
    required _FloorPlanPageLayout layout,
    required OcptFloorPlanSymbolShape symbol,
  }) {
    final color = PdfColor.fromInt(symbol.colorArgb);
    Offset local(double xM, double yM) =>
        _localPointGraphics(layout: layout, symbol: symbol, localXM: xM, localYM: yM);

    final tipYM = -symbol.heightM / 2;
    final beamYM = tipYM - _lightBeamLengthM;
    final beamHalfWidthM = symbol.widthM * 0.9;
    final tip = local(0, tipYM);
    final beamLeft = local(-beamHalfWidthM, beamYM);
    final beamRight = local(beamHalfWidthM, beamYM);
    canvas
      ..setFillColor(PdfColor(color.red, color.green, color.blue, 0.22).flatten())
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(beamLeft.dx, beamLeft.dy)
      ..lineTo(beamRight.dx, beamRight.dy)
      ..fillPath();

    final corners = _rotatedRectCorners(
      centreXM: symbol.xM,
      centreYM: symbol.yM,
      widthM: symbol.widthM,
      heightM: symbol.heightM,
      rotationDeg: symbol.rotationDeg,
    );
    _fillAndStrokePolygon(
      canvas: canvas,
      points: [for (final corner in corners) layout.graphicsOf(layout.topDownPointOf(corner.dx, corner.dy))],
      fillColor: PdfColor(color.red, color.green, color.blue, 0.5).flatten(),
      strokeColor: color,
      strokeWidthPt: _symbolStrokeWidthPt,
    );

    final doorLeftStart = local(-symbol.widthM / 2, tipYM);
    final doorLeftEnd = local(-symbol.widthM / 2 - symbol.widthM * 0.3, tipYM - symbol.heightM * 0.4);
    final doorRightStart = local(symbol.widthM / 2, tipYM);
    final doorRightEnd = local(symbol.widthM / 2 + symbol.widthM * 0.3, tipYM - symbol.heightM * 0.4);
    canvas
      ..setColor(color)
      ..setLineWidth(0.75)
      ..drawLine(doorLeftStart.dx, doorLeftStart.dy, doorLeftEnd.dx, doorLeftEnd.dy)
      ..drawLine(doorRightStart.dx, doorRightStart.dy, doorRightEnd.dx, doorRightEnd.dy)
      ..strokePath();
  }

  /// A décor symbol's own typed primitive: [OcptFloorPlanSetElementShape.wall] a thick filled
  /// segment, [OcptFloorPlanSetElementShape.door] an open-sided frame plus its own swing arc,
  /// [OcptFloorPlanSetElementShape.furniture] a filled, stroked rectangle in its own colour (today's
  /// generic look, kept for this one shape — the previous, undifferentiated footprint this method
  /// itself used to draw for every symbol), [OcptFloorPlanSetElementShape.freeform] the same
  /// rectangle with a dashed outline ([_dashPattern]) instead of a solid one, telling it apart from
  /// furniture.
  void _paintSetElementGlyph({
    required PdfGraphics canvas,
    required _FloorPlanPageLayout layout,
    required OcptFloorPlanSymbolShape symbol,
  }) {
    final color = PdfColor.fromInt(symbol.colorArgb);
    final corners = _rotatedRectCorners(
      centreXM: symbol.xM,
      centreYM: symbol.yM,
      widthM: symbol.widthM,
      heightM: symbol.heightM,
      rotationDeg: symbol.rotationDeg,
    );
    final points = [
      for (final corner in corners) layout.graphicsOf(layout.topDownPointOf(corner.dx, corner.dy)),
    ];

    switch (symbol.setElementShape ?? OcptFloorPlanSetElementShape.freeform) {
      case OcptFloorPlanSetElementShape.wall:
        _fillAndStrokePolygon(
          canvas: canvas,
          points: points,
          fillColor: PdfColor(color.red, color.green, color.blue, 0.9).flatten(),
          strokeColor: color,
          strokeWidthPt: _symbolStrokeWidthPt + 0.5,
        );
      case OcptFloorPlanSetElementShape.door:
        _paintDoorGlyph(canvas: canvas, layout: layout, symbol: symbol, color: color, points: points);
      case OcptFloorPlanSetElementShape.furniture:
        _fillAndStrokePolygon(
          canvas: canvas,
          points: points,
          fillColor: PdfColor(color.red, color.green, color.blue, _symbolFillOpacity).flatten(),
          strokeColor: color,
          strokeWidthPt: _symbolStrokeWidthPt,
        );
      case OcptFloorPlanSetElementShape.freeform:
        canvas
          ..setFillColor(PdfColor(color.red, color.green, color.blue, 0.2).flatten())
          ..moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) {
          canvas.lineTo(point.dx, point.dy);
        }
        canvas
          ..lineTo(points.first.dx, points.first.dy)
          ..fillPath();

        canvas
          ..setColor(color)
          ..setLineWidth(_symbolStrokeWidthPt)
          ..setLineDashPattern(_dashPattern)
          ..moveTo(points.first.dx, points.first.dy);
        for (final point in points.skip(1)) {
          canvas.lineTo(point.dx, point.dy);
        }
        canvas
          ..lineTo(points.first.dx, points.first.dy)
          ..strokePath(close: true);
        canvas.setLineDashPattern();
    }
  }

  /// A door's own frame — its opening rect, tinted; three of its own four sides (the fourth is the
  /// opening); and its swing arc, a quarter circle traced from its own hinge (the rect's own
  /// bottom-left corner pre-rotation, [points]`[3]`) with a short polyline rather than
  /// `PdfGraphics.bezierArc` (an SVG-style arc whose parameters this simple quarter-turn does not
  /// need).
  void _paintDoorGlyph({
    required PdfGraphics canvas,
    required _FloorPlanPageLayout layout,
    required OcptFloorPlanSymbolShape symbol,
    required PdfColor color,
    required List<Offset> points,
  }) {
    canvas
      ..setFillColor(PdfColor(color.red, color.green, color.blue, 0.15).flatten())
      ..moveTo(points[0].dx, points[0].dy);
    for (final point in points.skip(1)) {
      canvas.lineTo(point.dx, point.dy);
    }
    canvas
      ..lineTo(points[0].dx, points[0].dy)
      ..fillPath();

    // The frame's own three sides: top-left → bottom-left → bottom-right → top-right, leaving the
    // top-left → top-right edge (`points[0]` to `points[1]`) open as the opening.
    canvas
      ..setColor(color)
      ..setLineWidth(_symbolStrokeWidthPt)
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[3].dx, points[3].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..strokePath();

    const arcSteps = 8;
    final halfWidthM = symbol.widthM / 2;
    final halfHeightM = symbol.heightM / 2;
    final swingRadiusM = symbol.heightM;
    final arcPoints = [
      for (var i = 0; i <= arcSteps; i++)
        _localPointGraphics(
          layout: layout,
          symbol: symbol,
          localXM: -halfWidthM + swingRadiusM * math.sin(math.pi / 2 * i / arcSteps),
          localYM: halfHeightM - swingRadiusM * math.cos(math.pi / 2 * i / arcSteps),
        ),
    ];
    canvas
      ..setColor(color)
      ..setLineWidth(0.5)
      ..moveTo(arcPoints.first.dx, arcPoints.first.dy);
    for (final point in arcPoints.skip(1)) {
      canvas.lineTo(point.dx, point.dy);
    }
    canvas.strokePath();
  }

  /// One arrow: a quadratic bezier shaft through [OcptFloorPlanArrowShape.ctrlXM]/
  /// [OcptFloorPlanArrowShape.ctrlYM] when set (converted to the cubic bezier `PdfGraphics.curveTo`
  /// draws, through the standard quadratic-to-cubic control-point formula
  /// `cp = end + 2/3 * (quadraticControl - end)`), a straight shaft otherwise, with a small filled
  /// arrowhead at its own end, in its own colour. A [OcptFloorPlanArrowKind.cameraMove] arrow's own
  /// shaft is drawn dashed ([_dashPattern]), the printed equivalent of the canvas painter's own
  /// dashing, keeping it visually distinct from a movement arrow's solid one, straight or curved
  /// alike.
  void _paintArrow({
    required PdfGraphics canvas,
    required _FloorPlanPageLayout layout,
    required OcptFloorPlanArrowShape arrow,
  }) {
    final from = layout.graphicsOf(layout.topDownPointOf(arrow.fromXM, arrow.fromYM));
    final to = layout.graphicsOf(layout.topDownPointOf(arrow.toXM, arrow.toYM));
    final ctrlXM = arrow.ctrlXM;
    final ctrlYM = arrow.ctrlYM;
    final ctrl = ctrlXM != null && ctrlYM != null
        ? layout.graphicsOf(layout.topDownPointOf(ctrlXM, ctrlYM))
        : null;
    final color = PdfColor.fromInt(arrow.colorArgb);
    final isDashed = arrow.kind == OcptFloorPlanArrowKind.cameraMove;

    canvas
      ..setColor(color)
      ..setLineWidth(_arrowStrokeWidthPt);
    if (isDashed) {
      canvas.setLineDashPattern(_dashPattern);
    }
    canvas.moveTo(from.dx, from.dy);
    if (ctrl != null) {
      final cp1 = Offset(from.dx + 2 / 3 * (ctrl.dx - from.dx), from.dy + 2 / 3 * (ctrl.dy - from.dy));
      final cp2 = Offset(to.dx + 2 / 3 * (ctrl.dx - to.dx), to.dy + 2 / 3 * (ctrl.dy - to.dy));
      canvas.curveTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, to.dx, to.dy);
    } else {
      canvas.lineTo(to.dx, to.dy);
    }
    canvas.strokePath();
    if (isDashed) {
      canvas.setLineDashPattern();
    }

    // The arrowhead's own direction: the shaft's tangent at its own `to` end — `to - ctrl` for a
    // curved shaft (a quadratic bezier's own tangent at t=1), `to - from` for a straight one.
    final headDirection = ctrl != null ? (to - ctrl) : (to - from);
    final angle = math.atan2(headDirection.dy, headDirection.dx);
    final left = Offset(
      to.dx - _arrowHeadLengthPt * math.cos(angle - _arrowHeadAnglePt),
      to.dy - _arrowHeadLengthPt * math.sin(angle - _arrowHeadAnglePt),
    );
    final right = Offset(
      to.dx - _arrowHeadLengthPt * math.cos(angle + _arrowHeadAnglePt),
      to.dy - _arrowHeadLengthPt * math.sin(angle + _arrowHeadAnglePt),
    );
    canvas
      ..setColor(color)
      ..moveTo(to.dx, to.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..fillPath();
  }

  /// The scale bar and the reference silhouette, bottom-right of the canvas — the printed
  /// equivalent of `ocpt_floor_plan_canvas_painter.dart`'s always-on pair, at the zoom [layout]
  /// fitted the case's own shapes at. The scale bar's own length is a separate [pw.Text] overlay
  /// (see [_buildPage]'s own doc comment for why).
  void _paintScaleAndSilhouette({required PdfGraphics canvas, required _FloorPlanPageLayout layout}) {
    canvas
      ..setColor(_scaleColor)
      ..setLineWidth(1)
      ..drawEllipse(
        layout.silhouetteCentreGraphics.dx,
        layout.silhouetteCentreGraphics.dy,
        layout.silhouetteRadiusPt,
        layout.silhouetteRadiusPt,
      )
      ..strokePath();

    final barY = layout.graphicsOf(Offset(0, layout.scaleBarTopDown)).dy;
    final barLeft = layout.scaleBarLeftTopDown;
    final barRight = layout.scaleBarRightTopDown;
    canvas
      ..setColor(_scaleColor)
      ..setLineWidth(1.5)
      ..drawLine(barLeft, barY, barRight, barY)
      ..drawLine(barLeft, barY - 3, barLeft, barY + 3)
      ..drawLine(barRight, barY - 3, barRight, barY + 3)
      ..strokePath();
  }

  /// The four corners, in metres, of a footprint [widthM] × [heightM] centred at
  /// `(centreXM, centreYM)` and rotated by [rotationDeg] — the screen convention every floor plan
  /// renderer shares (clockwise, Y growing downward — `ocpt_floor_plan_canvas_painter.dart`'s own
  /// `canvas.rotate`), reproduced here rather than imported from that Flutter widget file, which the
  /// manager layer does not depend on.
  List<Offset> _rotatedRectCorners({
    required double centreXM,
    required double centreYM,
    required double widthM,
    required double heightM,
    required double rotationDeg,
  }) {
    final radians = rotationDeg * math.pi / 180;
    final cosA = math.cos(radians);
    final sinA = math.sin(radians);
    final halfW = widthM / 2;
    final halfH = heightM / 2;

    Offset corner(double x, double y) =>
        Offset(centreXM + x * cosA - y * sinA, centreYM + x * sinA + y * cosA);

    return [
      corner(-halfW, -halfH),
      corner(halfW, -halfH),
      corner(halfW, halfH),
      corner(-halfW, halfH),
    ];
  }

  /// Fills then strokes the closed polygon [points] (already in the canvas's own graphics space).
  void _fillAndStrokePolygon({
    required PdfGraphics canvas,
    required List<Offset> points,
    required PdfColor fillColor,
    required PdfColor strokeColor,
    required double strokeWidthPt,
  }) {
    if (points.isEmpty) {
      return;
    }

    canvas
      ..setFillColor(fillColor)
      ..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      canvas.lineTo(point.dx, point.dy);
    }
    canvas
      ..lineTo(points.first.dx, points.first.dy)
      ..fillPath();

    canvas
      ..setStrokeColor(strokeColor)
      ..setLineWidth(strokeWidthPt)
      ..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      canvas.lineTo(point.dx, point.dy);
    }
    canvas
      ..lineTo(points.first.dx, points.first.dy)
      ..strokePath(close: true);
  }
}

/// One page's own fit-to-content layout: the metre-space bounding box a sheet's own symbols and
/// underlay are fit to a page of `widthPt` × `heightPt`, the pixels-per-metre scale that follows
/// from it (through the very same `ocpt_floor_plan_geometry.dart` rule the on-screen canvas reads,
/// `ocptFloorPlanPixelsPerMetreAt`), and the scale bar's own geometry at that scale.
///
/// Every point this class hands out is in **top-down page space** (`(0, 0)` at the canvas's own
/// top-left corner, Y growing downward) — the convention a `pw.Positioned` widget already measures
/// its own `left`/`top` in, and the one every `topDownPointOf` caller in this file uses directly
/// for text. [graphicsOf] is the one conversion into `PdfGraphics`'s own bottom-up space, applied
/// only where this file draws through a raw canvas call.
class _FloorPlanPageLayout {
  /// Class constructor
  const _FloorPlanPageLayout({
    required this.widthPt,
    required this.heightPt,
    required this.centerXM,
    required this.centerYM,
    required this.pixelsPerMetre,
  });

  /// Builds the layout [sheet] is drawn under, fit to a page of [widthPt] × [heightPt].
  factory _FloorPlanPageLayout.of({
    required OcptFloorPlanSheet sheet,
    required double widthPt,
    required double heightPt,
  }) {
    double? minX;
    double? maxX;
    double? minY;
    double? maxY;

    void include(double x, double y) {
      minX = minX == null ? x : math.min(minX!, x);
      maxX = maxX == null ? x : math.max(maxX!, x);
      minY = minY == null ? y : math.min(minY!, y);
      maxY = maxY == null ? y : math.max(maxY!, y);
    }

    for (final symbol in sheet.symbols) {
      final halfDiagonal =
          math.sqrt(symbol.widthM * symbol.widthM + symbol.heightM * symbol.heightM) / 2;
      include(symbol.xM - halfDiagonal, symbol.yM - halfDiagonal);
      include(symbol.xM + halfDiagonal, symbol.yM + halfDiagonal);
    }
    final underlay = sheet.underlay;
    if (underlay != null) {
      // The half-diagonal, not the half-width/height: a rotated underlay's own true footprint can
      // reach further than its unrotated width/height, and the page's own fit-to-content box must
      // never clip it.
      final halfDiagonal =
          math.sqrt(underlay.widthM * underlay.widthM + underlay.heightM * underlay.heightM) / 2;
      include(underlay.xM - halfDiagonal, underlay.yM - halfDiagonal);
      include(underlay.xM + halfDiagonal, underlay.yM + halfDiagonal);
    }

    final resolvedMinX = minX;
    final resolvedMaxX = maxX;
    final resolvedMinY = minY;
    final resolvedMaxY = maxY;

    double boxWidthM;
    double boxHeightM;
    double centerXM;
    double centerYM;
    if (resolvedMinX == null || resolvedMaxX == null || resolvedMinY == null || resolvedMaxY == null) {
      boxWidthM = _minimumHalfSpanM * 2;
      boxHeightM = _minimumHalfSpanM * 2;
      centerXM = 0;
      centerYM = 0;
    } else {
      centerXM = (resolvedMinX + resolvedMaxX) / 2;
      centerYM = (resolvedMinY + resolvedMaxY) / 2;
      boxWidthM =
          math.max(_minimumHalfSpanM, (resolvedMaxX - resolvedMinX) / 2 * (1 + _boundingBoxPaddingFraction)) * 2;
      boxHeightM =
          math.max(_minimumHalfSpanM, (resolvedMaxY - resolvedMinY) / 2 * (1 + _boundingBoxPaddingFraction)) * 2;
    }

    final pixelsPerMetre = widthPt <= 0 || heightPt <= 0
        ? 0.0
        : math.min(widthPt / boxWidthM, heightPt / boxHeightM);

    return _FloorPlanPageLayout(
      widthPt: widthPt,
      heightPt: heightPt,
      centerXM: centerXM,
      centerYM: centerYM,
      pixelsPerMetre: pixelsPerMetre,
    );
  }

  /// The page's own content width, in points.
  final double widthPt;

  /// The page's own content height, in points.
  final double heightPt;

  /// The metre-space bounding box's own centre X, mapped to the page's own centre.
  final double centerXM;

  /// The metre-space bounding box's own centre Y, mapped to the page's own centre.
  final double centerYM;

  /// How many points one metre draws at, on this page (`ocptFloorPlanPixelsPerMetreAt`'s own
  /// "logical pixel" read as a page point).
  final double pixelsPerMetre;

  /// The zoom [pixelsPerMetre] corresponds to, for `ocpt_floor_plan_geometry.dart`'s own
  /// zoom-keyed rules ([ocptFloorPlanScaleBarLengthM]).
  double get zoom => pixelsPerMetre / ocptFloorPlanBasePixelsPerMetre;

  /// The screen point, in this page's own top-down space, `(xM, yM)` maps to — the fit-to-page
  /// sibling of `ocptFloorPlanScreenPointOf`'s own canvas-centred convention.
  Offset topDownPointOf(double xM, double yM) => Offset(
    widthPt / 2 + (xM - centerXM) * pixelsPerMetre,
    heightPt / 2 + (yM - centerYM) * pixelsPerMetre,
  );

  /// [topDown] converted into `PdfGraphics`'s own bottom-up space — the one flip every raw canvas
  /// call in this file applies, and the only one (see this class's own doc comment).
  Offset graphicsOf(Offset topDown) => Offset(topDown.dx, heightPt - topDown.dy);

  /// The reference silhouette's own radius, in points, at [pixelsPerMetre].
  double get silhouetteRadiusPt => ocptFloorPlanCharacterFootprintM * pixelsPerMetre / 2;

  /// The reference silhouette's own centre, in graphics space, bottom-right of the page.
  Offset get silhouetteCentreGraphics => Offset(
    widthPt - _silhouetteMarginPt - silhouetteRadiusPt,
    heightPt - _silhouetteMarginPt - silhouetteRadiusPt,
  );

  /// The scale bar's own length, in metres, at [zoom] (`ocptFloorPlanScaleBarLengthM`).
  double get scaleBarLengthM => ocptFloorPlanScaleBarLengthM(zoom: zoom, targetPixelLength: 72);

  /// The scale bar's own length, in points.
  double get _scaleBarLengthPt => ocptFloorPlanMetresToPixels(metres: scaleBarLengthM, zoom: zoom);

  /// The scale bar's own top-down Y — just above the reference silhouette.
  double get scaleBarTopDown =>
      heightPt - _silhouetteMarginPt - silhouetteRadiusPt * 2 - 10;

  /// The scale bar's own right edge, in top-down X (and graphics X, the two coinciding on this
  /// axis since no flip ever touches X).
  double get scaleBarRightTopDown => widthPt - _silhouetteMarginPt;

  /// The scale bar's own left edge.
  double get scaleBarLeftTopDown => scaleBarRightTopDown - _scaleBarLengthPt;
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_export_file_name.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_floor_plan_pdf_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_annotation.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_panel.dart';
import 'package:open_cine_prod_tools/models/ocpt_storyboard_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_storyboard_annotation_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_storyboard_annotation_geometry.dart';
import 'package:open_cine_prod_tools/utils/ocpt_storyboard_aspect_ratio.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The common height, in points, every panel frame of a row is drawn at — the printed equivalent
/// of the board's own common row height (`docs/plans/storyboard.md`, §1).
const double _frameHeightPt = 120;

/// The narrowest and widest a frame's own derived aspect ratio is allowed to size its width to,
/// relative to [_frameHeightPt] — a very wide anamorphic or very tall portrait format still prints
/// a frame that fits beside its neighbours rather than one that swallows the row.
const double _minimumAspectRatio = 0.5;
const double _maximumAspectRatio = 2.6;

/// The fixed width, in points, of the key-information block leading every shot row.
const double _keyInfoWidthPt = 130;

/// The horizontal gap, in points, between two frames of the same row, and between the
/// key-information block and the first frame.
const double _rowGapPt = 8;

/// The vertical gap, in points, between two shot rows.
const double _rowSpacingPt = 12;

/// The font size, in points, of a shot's own code, leading its key-information block.
const double _codeFontSizePt = 10;

/// The font size, in points, of every other line of a shot's key-information block, and of a
/// panel's own comment.
const double _bodyFontSizePt = 7;

/// The font size, in points, of the sequence band's own title.
const double _sequenceBandFontSizePt = 12;

/// The font size, in points, of the running head naming the project and the document.
const double _headFontSizePt = 7;

/// The colour every rule and placeholder frame border is drawn with.
const PdfColor _ruleColor = PdfColor.fromInt(0xFFB0B0B0);

/// The background colour of the sequence band.
const PdfColor _bandColor = PdfColor.fromInt(0xFFEDEDED);

/// The grey the running head, the placeholder note and every muted label print in.
const PdfColor _mutedColor = PdfColor.fromInt(0xFF6E6E6E);

/// The colour a movement-arrow annotation prints in.
const PdfColor _movementArrowColor = PdfColor.fromInt(0xFF37474F);

/// The colour a camera-move-arrow annotation prints in.
const PdfColor _cameraMoveArrowColor = PdfColor.fromInt(0xFF1565C0);

/// The colour a label annotation's own dot and text print in.
const PdfColor _labelAnnotationColor = PdfColor.fromInt(0xFF6C5CE7);

/// The length, in points, of an arrow annotation's own head strokes.
const double _annotationHeadLengthPt = 7;

/// The angle, in radians, an arrow annotation's head strokes open at.
const double _annotationHeadAnglePt = 0.45;

/// Renders the storyboard of a shot list: per sequence, a header band, then per shot a row — its
/// key information beside its frames, printed at a common height and their own derived aspect
/// ratios, each frame's annotations drawn over it, its comment underneath
/// (`docs/plans/storyboard.md`, §1, §5).
///
/// This is pure rendering logic with no dialog or file-system access of its own beyond reading a
/// panel's own image file at render time (see below); it's owned by `OcptExportManager` and
/// exposed as a public final field, reached through the manager rather than through
/// `globalGetIt()` (RFL18), exactly like its siblings.
///
/// **Image bytes are read at render time, off the asset's own resolved path**
/// (`OcptStoryboardPanel.imagePath`, ADR 0013), as `pw.MemoryImage` — the `pdf` package decodes
/// JPEG and PNG, which is exactly what the board's own import picker is filtered to
/// (`docs/plans/storyboard.md`, §4.2, §8 decision 5), so what draws on screen always prints. A
/// panel with no image reference at all, a reference whose file has moved or gone, or a file that
/// fails to decode are all the same printed state: the placeholder frame, carrying
/// [OcptStoryboardLabels.fileNotFoundNote] — the ADR 0013 "missing file is a normal state", on
/// paper.
///
/// **Annotations are drawn from the very same normalised coordinate convention the on-screen
/// overlay reads** (`OcptStoryboardAnnotationOverlayPainter`,
/// `lib/ui/pages/workspace/modes/shot_list/widgets/ocpt_storyboard_annotation_painter.dart`): each
/// mark's `x1`/`y1`/`x2`/`y2` is normalised 0..1 to the frame and mapped by a plain product against
/// the frame's own printed width/height, no other transform — only the vertical axis is flipped
/// once, at the lowest drawing call, because `PdfGraphics` measures Y from the page's own bottom
/// while the stored convention (and the screen painter) measures it from the frame's own top.
///
/// **When `OcptStoryboardExportOptions.includeFloorPlansAfterEachSequence` is on, the floor plan
/// sheets print right after that sequence's own rows** — through [floorPlanPdfService], the very
/// same service (and the very same `OcptFloorPlanSheet`-drawing code) the standalone floor plans
/// PDF uses, so the two documents can never draw one case's plan two different ways.
class OcptStoryboardPdfService {
  /// Creates an [OcptStoryboardPdfService].
  ///
  /// Pass the manager's own [fontsLoader] so every export of the app session shares one font
  /// cache, and its own [floorPlanPdfService] so the two documents' shared font cache and shared
  /// page-building code are truly the same instance; a service built without either gets one of
  /// its own.
  OcptStoryboardPdfService({OcptCourierPrimeFontsLoader? fontsLoader, OcptFloorPlanPdfService? floorPlanPdfService})
    : this._(
        fontsLoader: fontsLoader ?? OcptCourierPrimeFontsLoader(),
        floorPlanPdfService: floorPlanPdfService,
      );

  /// Class constructor, taking the resolved [fontsLoader] so [floorPlanPdfService]'s own default
  /// can share it.
  OcptStoryboardPdfService._({
    required OcptCourierPrimeFontsLoader fontsLoader,
    required OcptFloorPlanPdfService? floorPlanPdfService,
  }) : fontsLoader = fontsLoader,
       floorPlanPdfService = floorPlanPdfService ?? OcptFloorPlanPdfService(fontsLoader: fontsLoader);

  /// The loader the embedded Courier Prime font set is read through.
  final OcptCourierPrimeFontsLoader fontsLoader;

  /// The service the floor plan sheets are drawn through, when appended after a sequence.
  final OcptFloorPlanPdfService floorPlanPdfService;

  /// The `.pdf` file name to suggest when exporting the storyboard of [projectName]. See
  /// `OcptScenarioCoveragePdfService.coverageFileName`'s own doc comment for [suffix] and
  /// [episodeTag].
  String storyboardFileName({
    required String projectName,
    required String suffix,
    String? episodeTag,
  }) => ocptExportFileNameOf(
    projectName: projectName,
    suffix: suffix,
    episodeTag: episodeTag,
    extension: "pdf",
  );

  /// Renders the storyboard of [snapshot]/[storyboardSnapshot], returning the PDF's bytes.
  ///
  /// [shotsPerPage] is how many shot rows print before a fresh page starts (clamped to at least
  /// 1); a sequence with more shots than that spans several pages, its own header band repeated at
  /// the top of each. [includeFloorPlansAfterEachSequence], [floorPlanSnapshot] and
  /// [floorPlanLabels] together drive the appended floor plan sheets — the last two are required
  /// exactly when the first is true, since there is nothing to append otherwise.
  Future<Uint8List> generate({
    required OcptShotListSnapshot snapshot,
    required OcptStoryboardSnapshot storyboardSnapshot,
    required OcptPageSetup pageSetup,
    required OcptStoryboardLabels labels,
    required String projectName,
    required int shotsPerPage,
    bool includeFloorPlansAfterEachSequence = false,
    OcptFloorPlanSnapshot? floorPlanSnapshot,
    OcptFloorPlanLabels? floorPlanLabels,
  }) async {
    final metrics = pageSetup.toMetrics();
    final painter = OcptScriptPagePainter(metrics: metrics, fonts: await fontsLoader.load());
    final clampedShotsPerPage = shotsPerPage < 1 ? 1 : shotsPerPage;
    final imagesByPanelId = await _loadPanelImages(storyboardSnapshot);

    final pdfDocument = pw.Document();

    for (final sequence in snapshot.sequences) {
      if (sequence.shots.isEmpty) {
        continue;
      }

      for (final chunk in _chunked(sequence.shots, clampedShotsPerPage)) {
        pdfDocument.addPage(
          _buildChunkPage(
            painter: painter,
            labels: labels,
            sequence: sequence,
            shots: chunk,
            storyboardSnapshot: storyboardSnapshot,
            imagesByPanelId: imagesByPanelId,
            projectName: projectName,
          ),
        );
      }

      if (includeFloorPlansAfterEachSequence &&
          sequence is OcptSceneShotSequence &&
          floorPlanSnapshot != null &&
          floorPlanLabels != null) {
        final floorPlanPages = await floorPlanPdfService.pagesOfSequence(
          painter: painter,
          labels: floorPlanLabels,
          sequence: sequence,
          floorPlanSnapshot: floorPlanSnapshot,
          projectName: projectName,
        );
        for (final page in floorPlanPages) {
          pdfDocument.addPage(page);
        }
      }
    }

    return pdfDocument.save();
  }

  /// Reads every referenced panel image once, ahead of building the page widgets — a `pw.Document`
  /// is built synchronously, so every file this render touches is read up front rather than from
  /// inside a widget's own `build`.
  ///
  /// A panel with no image reference, an unreadable path or bytes the `pdf` package cannot decode
  /// all resolve to `null` here — the placeholder frame's own trigger, never a thrown error (ADR
  /// 0013: a missing file is a normal state).
  Future<Map<String, pw.MemoryImage?>> _loadPanelImages(
    OcptStoryboardSnapshot storyboardSnapshot,
  ) async {
    final result = <String, pw.MemoryImage?>{};
    for (final panels in storyboardSnapshot.panelsByShotId.values) {
      for (final panel in panels) {
        result[panel.id] = await _readImageOrNull(panel.imagePath);
      }
    }
    return result;
  }

  /// [path]'s bytes decoded as a `pw.MemoryImage`, or null when [path] is null, names no file, or
  /// cannot be decoded.
  Future<pw.MemoryImage?> _readImageOrNull(String? path) async {
    if (path == null) {
      return null;
    }
    try {
      final bytes = await File(path).readAsBytes();
      return pw.MemoryImage(bytes);
    } catch (_) {
      // A missing file (ADR 0013), a path that no longer names a file at all, or bytes the `pdf`
      // package cannot decode: all the same printed state, the placeholder frame.
      return null;
    }
  }

  /// [shots] split into chunks of at most [size], in order.
  List<List<OcptShot>> _chunked(List<OcptShot> shots, int size) {
    final chunks = <List<OcptShot>>[];
    for (var start = 0; start < shots.length; start += size) {
      chunks.add(shots.sublist(start, math.min(start + size, shots.length)));
    }
    return chunks;
  }

  /// One page (a `pw.MultiPage`, so a chunk whose rows still overflow it flows onto a continuation
  /// page rather than clipping): the running head, [sequence]'s own header band, then one row per
  /// shot of [shots].
  pw.MultiPage _buildChunkPage({
    required OcptScriptPagePainter painter,
    required OcptStoryboardLabels labels,
    required OcptShotSequence sequence,
    required List<OcptShot> shots,
    required OcptStoryboardSnapshot storyboardSnapshot,
    required Map<String, pw.MemoryImage?> imagesByPanelId,
    required String projectName,
  }) => pw.MultiPage(
    pageFormat: PdfPageFormat(
      painter.pageWidthPt,
      painter.pageHeightPt,
      marginLeft: painter.marginRightPt,
      marginTop: painter.marginTopPt,
      marginRight: painter.marginRightPt,
      marginBottom: painter.marginRightPt,
    ),
    header: (context) => _runningHead(painter: painter, labels: labels, projectName: projectName),
    build: (context) => [
      _sequenceBand(painter: painter, labels: labels, sequence: sequence),
      pw.SizedBox(height: _rowSpacingPt),
      for (final shot in shots) ...[
        _shotRow(
          painter: painter,
          labels: labels,
          shot: shot,
          panels: storyboardSnapshot.panelsOfShot(shot.id),
          imagesByPanelId: imagesByPanelId,
        ),
        pw.SizedBox(height: _rowSpacingPt),
      ],
    ],
  );

  /// The running head every page carries: the project and the document's own name.
  pw.Widget _runningHead({
    required OcptScriptPagePainter painter,
    required OcptStoryboardLabels labels,
    required String projectName,
  }) => pw.Text(
    "$projectName — ${labels.documentTitle}",
    style: pw.TextStyle(font: painter.fonts.regular, fontSize: _headFontSizePt, color: _mutedColor),
  );

  /// The full-width band introducing [sequence]'s own rows.
  pw.Widget _sequenceBand({
    required OcptScriptPagePainter painter,
    required OcptStoryboardLabels labels,
    required OcptShotSequence sequence,
  }) => pw.Container(
    constraints: const pw.BoxConstraints(minWidth: double.infinity),
    color: _bandColor,
    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
    child: pw.Text(
      labels.titleOfSequence(sequence.id),
      style: pw.TextStyle(font: painter.fonts.bold, fontSize: _sequenceBandFontSizePt),
    ),
  );

  /// One shot row: its key-information block, then its frames (or the "no panel" note) at a
  /// common height and their own derived aspect ratios.
  pw.Widget _shotRow({
    required OcptScriptPagePainter painter,
    required OcptStoryboardLabels labels,
    required OcptShot shot,
    required List<OcptStoryboardPanel> panels,
    required Map<String, pw.MemoryImage?> imagesByPanelId,
  }) {
    final ratio = ocptAspectRatioOf(
      shot.recordingFormat,
    ).clamp(_minimumAspectRatio, _maximumAspectRatio);
    final frameWidthPt = _frameHeightPt * ratio;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _keyInfoBlock(painter: painter, labels: labels, shot: shot),
        pw.SizedBox(width: _rowGapPt),
        pw.Expanded(
          child: panels.isEmpty
              ? _placeholderFrame(
                  painter: painter,
                  text: labels.noPanelNote,
                  widthPt: frameWidthPt,
                  heightPt: _frameHeightPt,
                )
              : pw.Wrap(
                  spacing: _rowGapPt,
                  runSpacing: _rowGapPt,
                  children: [
                    for (final panel in panels)
                      _panelFrame(
                        painter: painter,
                        labels: labels,
                        panel: panel,
                        image: imagesByPanelId[panel.id],
                        widthPt: frameWidthPt,
                        heightPt: _frameHeightPt,
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  /// The key-information block leading a shot row: its code and status, then its shot size,
  /// framing, camera move, lens, recording format and attached cast.
  pw.Widget _keyInfoBlock({
    required OcptScriptPagePainter painter,
    required OcptStoryboardLabels labels,
    required OcptShot shot,
  }) => pw.Container(
    width: _keyInfoWidthPt,
    height: _frameHeightPt,
    padding: const pw.EdgeInsets.all(4),
    decoration: pw.BoxDecoration(border: pw.Border.all(color: _ruleColor, width: 0.5)),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(shot.code, style: pw.TextStyle(font: painter.fonts.bold, fontSize: _codeFontSizePt)),
        pw.Text(
          labels.labelOfStatus(shot.status),
          style: pw.TextStyle(font: painter.fonts.italic, fontSize: _bodyFontSizePt, color: _mutedColor),
        ),
        pw.SizedBox(height: 4),
        _infoLine(painter, labels.shotSizeLabel, shot.shotSize),
        _infoLine(painter, labels.framingLabel, shot.framing),
        _infoLine(painter, labels.cameraMoveLabel, shot.cameraMove),
        _infoLine(painter, labels.lensLabel, shot.lens),
        _infoLine(painter, labels.recordingFormatLabel, shot.recordingFormat),
        _infoLine(painter, labels.castLabel, shot.characters.join(", ")),
      ],
    ),
  );

  /// One `label: value` line of the key-information block, omitted entirely when [value] is
  /// blank — a block naming every field it holds nothing for would read as noisier than the read
  /// it is meant to shorten.
  pw.Widget _infoLine(OcptScriptPagePainter painter, String label, String value) {
    if (value.trim().isEmpty) {
      return pw.SizedBox.shrink();
    }
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 1),
      child: pw.Text(
        "$label: $value",
        style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt),
        maxLines: 2,
      ),
    );
  }

  /// A dashed-bordered placeholder frame — a shot with no panel, or a panel whose image could not
  /// be read.
  pw.Widget _placeholderFrame({
    required OcptScriptPagePainter painter,
    required String text,
    required double widthPt,
    required double heightPt,
  }) => pw.Container(
    width: widthPt,
    height: heightPt,
    alignment: pw.Alignment.center,
    decoration: pw.BoxDecoration(border: pw.Border.all(color: _ruleColor, width: 0.75)),
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(
      text,
      textAlign: pw.TextAlign.center,
      style: pw.TextStyle(font: painter.fonts.italic, fontSize: _bodyFontSizePt, color: _mutedColor),
    ),
  );

  /// One panel's own frame: its image (or the placeholder, when [image] is null) with its
  /// annotations drawn over it, its comment underneath.
  pw.Widget _panelFrame({
    required OcptScriptPagePainter painter,
    required OcptStoryboardLabels labels,
    required OcptStoryboardPanel panel,
    required pw.MemoryImage? image,
    required double widthPt,
    required double heightPt,
  }) {
    final frame = image == null
        ? _placeholderFrame(
            painter: painter,
            text: labels.fileNotFoundNote,
            widthPt: widthPt,
            heightPt: heightPt,
          )
        : pw.SizedBox(
            width: widthPt,
            height: heightPt,
            child: pw.Stack(
              children: [
                pw.Positioned.fill(child: pw.Image(image, fit: pw.BoxFit.cover)),
                pw.Positioned.fill(
                  child: pw.CustomPaint(
                    size: PdfPoint(widthPt, heightPt),
                    painter: (canvas, size) => _paintAnnotationMarks(canvas, size, panel.annotations),
                  ),
                ),
                ..._annotationCaptionOverlays(panel.annotations, widthPt, heightPt, painter),
              ],
            ),
          );

    return pw.SizedBox(
      width: widthPt,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          frame,
          if (panel.comment.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text(
                panel.comment,
                style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt),
                maxLines: 3,
              ),
            ),
        ],
      ),
    );
  }

  /// Draws every arrow's shaft and head, and every label's own anchor dot, over a frame of [size],
  /// from the very same shared pure rule `OcptStoryboardAnnotationOverlayPainter` reads,
  /// `ocptStoryboardAnnotationPointOf` (`lib/utils/ocpt_storyboard_annotation_geometry.dart`) —
  /// see this class's own doc comment. A label's own text is a separate [pw.Text] overlay
  /// ([_annotationCaptionOverlays]): `pdf`'s low-level `PdfGraphics.drawString` takes a `PdfFont`
  /// the widget-level `pw.Font` this app's `OcptCourierPrimeFonts` hands out cannot be converted
  /// to outside of a build context, the same reason `OcptFloorPlanPdfService` keeps every caption
  /// it prints out of its own `CustomPaint` calls.
  void _paintAnnotationMarks(PdfGraphics canvas, PdfPoint size, List<OcptStoryboardAnnotation> annotations) {
    for (final annotation in annotations) {
      // The shared rule measures y from the frame's own top; PdfGraphics measures it from the
      // frame's own bottom — the one flip this drawing needs, applied here and nowhere else.
      final tailPoint = ocptStoryboardAnnotationPointOf(
        xNorm: annotation.x1,
        yNorm: annotation.y1,
        widthPx: size.x,
        heightPx: size.y,
      );
      final headPoint = ocptStoryboardAnnotationPointOf(
        xNorm: annotation.x2,
        yNorm: annotation.y2,
        widthPx: size.x,
        heightPx: size.y,
      );
      final tail = Offset(tailPoint.x, size.y - tailPoint.y);
      final head = Offset(headPoint.x, size.y - headPoint.y);

      switch (annotation.kind) {
        case OcptStoryboardAnnotationKind.movementArrow:
          _paintArrow(canvas, tail, head, _movementArrowColor, dashed: false);
        case OcptStoryboardAnnotationKind.cameraMoveArrow:
          _paintArrow(canvas, tail, head, _cameraMoveArrowColor, dashed: true);
        case OcptStoryboardAnnotationKind.label:
          canvas
            ..setColor(_labelAnnotationColor)
            ..drawEllipse(tail.dx, tail.dy, 2.5, 2.5)
            ..fillPath();
      }
    }
  }

  /// One [pw.Positioned] [pw.Text] per non-empty label annotation, at the very same normalised
  /// point [_paintAnnotationMarks] draws its anchor dot at — a `pw.Positioned` measures its own
  /// `left`/`top` from the frame's own top-left corner, exactly the stored convention's own origin,
  /// so no flip is needed here (unlike every `PdfGraphics` call, which is not a widget and measures
  /// its own Y from the frame's bottom).
  List<pw.Widget> _annotationCaptionOverlays(
    List<OcptStoryboardAnnotation> annotations,
    double widthPt,
    double heightPt,
    OcptScriptPagePainter painter,
  ) => [
    for (final annotation in annotations)
      if (annotation.kind == OcptStoryboardAnnotationKind.label && annotation.text.isNotEmpty)
        _labelCaption(annotation, widthPt, heightPt, painter),
  ];

  /// One label annotation's own caption, positioned at its own normalised anchor.
  pw.Widget _labelCaption(
    OcptStoryboardAnnotation annotation,
    double widthPt,
    double heightPt,
    OcptScriptPagePainter painter,
  ) {
    final anchor = ocptStoryboardAnnotationPointOf(
      xNorm: annotation.x1,
      yNorm: annotation.y1,
      widthPx: widthPt,
      heightPx: heightPt,
    );
    return pw.Positioned(
      left: anchor.x + 6,
      top: anchor.y - 5,
      child: pw.Text(
        annotation.text,
        style: pw.TextStyle(font: painter.fonts.bold, fontSize: 8, color: _labelAnnotationColor),
      ),
    );
  }

  /// One arrow annotation: a shaft from [tail] to [head], solid or [dashed], and a small filled
  /// arrowhead at [head].
  void _paintArrow(PdfGraphics canvas, Offset tail, Offset head, PdfColor color, {required bool dashed}) {
    canvas
      ..setColor(color)
      ..setLineWidth(1.5);
    if (dashed) {
      canvas.setLineDashPattern([3, 2]);
    }
    canvas
      ..drawLine(tail.dx, tail.dy, head.dx, head.dy)
      ..strokePath();
    if (dashed) {
      canvas.setLineDashPattern();
    }

    if ((head - tail).distance == 0) {
      return;
    }
    final angle = math.atan2(head.dy - tail.dy, head.dx - tail.dx);
    final left = Offset(
      head.dx - _annotationHeadLengthPt * math.cos(angle - _annotationHeadAnglePt),
      head.dy - _annotationHeadLengthPt * math.sin(angle - _annotationHeadAnglePt),
    );
    final right = Offset(
      head.dx - _annotationHeadLengthPt * math.cos(angle + _annotationHeadAnglePt),
      head.dy - _annotationHeadLengthPt * math.sin(angle + _annotationHeadAnglePt),
    );
    canvas
      ..setColor(color)
      ..moveTo(head.dx, head.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..fillPath();
  }
}

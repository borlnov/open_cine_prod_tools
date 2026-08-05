// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_sheets_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_target.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_scene_bars.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The font size, in points, of a sheet's own scene title.
const double _titleFontSizePt = 16;

/// The font size, in points, of the scene heading printed under that title.
const double _headingFontSizePt = 11;

/// The font size, in points, of every body line of a sheet: a meta cell's value, a table cell, a
/// note.
const double _bodyFontSizePt = 9;

/// The font size, in points, of the small muted lines: the running head, a section title, a meta
/// cell's own label.
const double _smallFontSizePt = 7;

/// The padding, in points, inside one cell of a sheet's table.
const double _cellPaddingPt = 4;

/// The side, in points, of the colour swatch a group band prints its category's colour as.
const double _swatchSizePt = 8;

/// The colour of the rules a sheet's tables and its meta cells are drawn with.
const PdfColor _ruleColor = PdfColor.fromInt(0xFFB0B0B0);

/// The background colour of a table's header row and of a meta cell.
const PdfColor _bandColor = PdfColor.fromInt(0xFFEDEDED);

/// The grey the running head and every muted label is printed in.
const PdfColor _mutedColor = PdfColor.fromInt(0xFF6E6E6E);

/// What a sheet prints in place of a value the project has not filled in yet.
///
/// The em dash the app's own tables already show for the same reason: a blank cell reads as a
/// rendering fault on a printed page, where nobody can click it to find out.
const String _emptyValue = "—";

/// The columns of a scene's targets table: the target's name, its status and its owner.
const Map<int, pw.TableColumnWidth> _targetColumnWidths = {
  0: pw.FlexColumnWidth(3),
  1: pw.FlexColumnWidth(1.5),
  2: pw.FlexColumnWidth(2),
};

/// Renders a project's breakdown sheets: one sheet per scene, carrying that scene's number and
/// heading, how far its breakdown has got, its length, its own breakdown notes, everything tagged
/// in it grouped by category, and what it still has to find.
///
/// This is pure rendering logic with no dialog or file-system access of its own: it's owned by
/// `OcptExportManager` and exposed as a public final field, reached through the manager rather than
/// through `globalGetIt()` (RFL18), exactly like its six siblings.
///
/// **Per scene rather than per element**, on purpose: this is the document that goes to the
/// department heads, who each read the day's scenes and prepare what those scenes call for. The
/// per-element question — where does this lamp come back? — is what the mode's own recap view
/// answers on screen, and what the resources mode's workbook carries out of the app.
///
/// It prints no screenplay at all, so — unlike `OcptPdfExportService` and
/// `OcptScenarioCoveragePdfService` — it draws nothing through [OcptScriptPagePainter]'s page
/// builders. It still takes one: the painter owns the page geometry every export of this app
/// measures a sheet with, and the Courier Prime variants all three of them print in.
class OcptBreakdownSheetsPdfService {
  /// Creates an [OcptBreakdownSheetsPdfService].
  ///
  /// Pass the manager's own [fontsLoader] so every export of the app session shares one font cache;
  /// a service built without one gets a loader of its own.
  OcptBreakdownSheetsPdfService({OcptCourierPrimeFontsLoader? fontsLoader})
    : fontsLoader = fontsLoader ?? OcptCourierPrimeFontsLoader();

  /// The loader the embedded Courier Prime font set is read through.
  final OcptCourierPrimeFontsLoader fontsLoader;

  /// The `.pdf` file name to suggest when exporting the breakdown sheets of [projectName].
  ///
  /// [suffix] is the localized word telling this document apart from the other PDFs the app writes
  /// (`My Movie - breakdown.pdf`); a blank one falls back to the project name alone rather than
  /// producing a file name ending on a dangling separator, exactly as
  /// `OcptScenarioCoveragePdfService.coverageFileName` does.
  String sheetsFileName({required String projectName, required String suffix}) =>
      suffix.trim().isEmpty ? "$projectName.pdf" : "$projectName - ${suffix.trim()}.pdf";

  /// Renders the breakdown sheets of [snapshot], returning the PDF's bytes.
  ///
  /// [document] is the screenplay [snapshot]'s scenes were indexed against: it is read for one
  /// thing only, each scene's length in page eighths, which is a fact about the typeset screenplay
  /// rather than about the breakdown. A scene whose position no longer names a scene of [document]
  /// (an index rebuilt since, or a snapshot from a version captured against another text) simply
  /// prints no length rather than a wrong one. [pageSetup] supplies the page geometry, and with it
  /// the metrics those eighths are measured against.
  ///
  /// [onlyDoneScenes] keeps the sheets of the scenes marked [OcptBreakdownSceneStatus.done] alone;
  /// [includeNotes] and [includeToFindList] toggle a sheet's two optional sections. A run that
  /// selects no scene at all still produces one sheet, saying so: an empty PDF is not a file
  /// anybody can open.
  Future<Uint8List> generate({
    required FountainDocument document,
    required OcptBreakdownSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBreakdownSheetsLabels labels,
    required String projectName,
    required bool onlyDoneScenes,
    required bool includeNotes,
    required bool includeToFindList,
  }) async {
    final metrics = pageSetup.toMetrics();
    final painter = OcptScriptPagePainter(metrics: metrics, fonts: await fontsLoader.load());
    final targetById = ocptBreakdownTargetsById(snapshot.targets);
    final elementById = {for (final element in snapshot.elements) element.id: element};
    final personById = {for (final person in snapshot.people) person.id: person};

    final scenes = [
      for (final scene in snapshot.scenes)
        if (!onlyDoneScenes || scene.status == OcptBreakdownSceneStatus.done) scene,
    ];

    final pdfDocument = pw.Document();

    if (scenes.isEmpty) {
      pdfDocument.addPage(
        _sheetPage(
          painter: painter,
          labels: labels,
          projectName: projectName,
          children: [_noteWidget(painter: painter, text: labels.emptyDocumentNote)],
        ),
      );

      return pdfDocument.save();
    }

    for (final scene in scenes) {
      pdfDocument.addPage(
        _sheetPage(
          painter: painter,
          labels: labels,
          projectName: projectName,
          children: _sceneWidgets(
            scene: scene,
            document: document,
            metrics: metrics,
            painter: painter,
            labels: labels,
            targetById: targetById,
            elementById: elementById,
            personById: personById,
            includeNotes: includeNotes,
            includeToFindList: includeToFindList,
          ),
        ),
      );
    }

    return pdfDocument.save();
  }

  /// One scene's whole sheet, in the order it is read: the scene's title and heading, its meta
  /// band, its own breakdown notes, everything tagged in it grouped by category, and what it still
  /// has to find.
  List<pw.Widget> _sceneWidgets({
    required OcptBreakdownScene scene,
    required FountainDocument document,
    required FountainLayoutMetrics metrics,
    required OcptScriptPagePainter painter,
    required OcptBreakdownSheetsLabels labels,
    required OcptBreakdownTargetsById targetById,
    required Map<String, OcptElement> elementById,
    required Map<String, OcptPerson> personById,
    required bool includeNotes,
    required bool includeToFindList,
  }) {
    final targets = ocptBreakdownSceneTargetsOf(scene, targetById);
    final buckets = ocptBreakdownSceneBarBucketsOf(scene, targetById);
    final toFindTargets = [
      for (final target in targets)
        if (target.status == OcptElementStatus.toFind) target,
    ]..sort((a, b) => a.name.compareTo(b.name));

    return [
      pw.Text(
        labels.titleOfScene(scene.id),
        style: pw.TextStyle(font: painter.fonts.bold, fontSize: _titleFontSizePt),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        scene.heading,
        style: pw.TextStyle(font: painter.fonts.regular, fontSize: _headingFontSizePt),
      ),
      pw.SizedBox(height: 10),

      _metaBand(
        painter: painter,
        cells: [
          (labels.statusLabel, labels.sceneStatusLabelOf(scene.status)),
          (labels.lengthLabel, _sceneLengthOf(scene: scene, document: document, metrics: metrics)),
        ],
      ),
      pw.SizedBox(height: 12),

      if (includeNotes && scene.notes.trim().isNotEmpty) ...[
        _sectionTitle(painter: painter, title: labels.notesLabel),
        pw.SizedBox(height: 4),
        _noteWidget(painter: painter, text: scene.notes.trim()),
        pw.SizedBox(height: 12),
      ],

      _sectionTitle(painter: painter, title: labels.targetsSectionTitle),
      pw.SizedBox(height: 4),
      if (buckets.isEmpty)
        _noteWidget(painter: painter, text: labels.emptySceneNote)
      else ...[
        _targetsHeaderTable(painter: painter, labels: labels),
        for (final bucket in buckets) ...[
          _groupBand(painter: painter, labels: labels, bucket: bucket),
          _targetsTable(
            painter: painter,
            labels: labels,
            bucket: bucket,
            targets: targets,
            elementById: elementById,
            personById: personById,
          ),
          pw.SizedBox(height: 8),
        ],
      ],

      if (includeToFindList && toFindTargets.isNotEmpty) ...[
        pw.SizedBox(height: 4),
        _sectionTitle(painter: painter, title: labels.toFindSectionTitle),
        pw.SizedBox(height: 4),
        for (final target in toFindTargets)
          pw.Bullet(
            text: target.name,
            style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt),
          ),
      ],
    ];
  }

  /// One sheet's [pw.MultiPage], carrying the running head naming the project and the document,
  /// then [children].
  ///
  /// A flowing page rather than one of [OcptScriptPagePainter]'s absolutely positioned ones: a
  /// scene holding thirty tagged elements must be free to run onto a second sheet rather than
  /// print off the bottom of the first. Its side margins are the screenplay's *right* margin on
  /// both sides, exactly as the coverage export's own appendices are: the wide left margin a
  /// screenplay needs is there to be punched and annotated, and a breakdown sheet has no such use
  /// for it.
  pw.Page _sheetPage({
    required OcptScriptPagePainter painter,
    required OcptBreakdownSheetsLabels labels,
    required String projectName,
    required List<pw.Widget> children,
  }) => pw.MultiPage(
    pageFormat: PdfPageFormat(
      painter.pageWidthPt,
      painter.pageHeightPt,
      marginLeft: painter.marginRightPt,
      marginTop: painter.marginTopPt,
      marginRight: painter.marginRightPt,
      marginBottom: painter.marginRightPt,
    ),
    build: (context) => [
      pw.Text(
        "$projectName — ${labels.documentTitle}",
        style: pw.TextStyle(
          font: painter.fonts.regular,
          fontSize: _smallFontSizePt,
          color: _mutedColor,
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Divider(color: _ruleColor, thickness: 0.5, height: 6),
      pw.SizedBox(height: 6),
      ...children,
    ],
  );

  /// The scene's length, in the eighths notation assistant directors write on a breakdown sheet:
  /// `5/8` under a page, `2` on two whole pages, `1 4/8` in between.
  ///
  /// A numeral rather than a translated string, which is why [OcptBreakdownSheetsLabels] carries
  /// only its label. A scene whose [OcptBreakdownScene.position] names no scene of [document]
  /// prints [_emptyValue]: the length is a fact about the typeset screenplay, and the honest answer
  /// when the two no longer line up is that this document cannot tell.
  String _sceneLengthOf({
    required OcptBreakdownScene scene,
    required FountainDocument document,
    required FountainLayoutMetrics metrics,
  }) {
    if (scene.position < 0 || scene.position >= document.scenes.length) {
      return _emptyValue;
    }

    final pageEighths = FountainSceneStatistics.of(document, metrics, scene.position).pageEighths;
    final whole = pageEighths ~/ 8;
    final eighths = pageEighths % 8;

    if (eighths == 0) {
      return "$whole";
    }

    return whole == 0 ? "$eighths/8" : "$whole $eighths/8";
  }

  /// The band of boxed `(label, value)` [cells] under a sheet's heading, laid side by side.
  ///
  /// The cells size themselves rather than being stretched to a common height: a flowing page lays
  /// its children out with no height to stretch against, and asking for one there measures as
  /// infinite. They hold the same two lines anyway, so they come out level.
  pw.Widget _metaBand({
    required OcptScriptPagePainter painter,
    required List<(String, String)> cells,
  }) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final (index, (label, value)) in cells.indexed) ...[
        if (index > 0) pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Container(
            decoration: pw.BoxDecoration(
              color: _bandColor,
              border: pw.Border.all(color: _ruleColor, width: 0.5),
            ),
            padding: const pw.EdgeInsets.all(_cellPaddingPt),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  label.toUpperCase(),
                  style: pw.TextStyle(
                    font: painter.fonts.regular,
                    fontSize: _smallFontSizePt,
                    color: _mutedColor,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  value.isEmpty ? _emptyValue : value,
                  style: pw.TextStyle(font: painter.fonts.bold, fontSize: _bodyFontSizePt),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );

  /// One section's own small, muted heading.
  pw.Widget _sectionTitle({required OcptScriptPagePainter painter, required String title}) =>
      pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          font: painter.fonts.bold,
          fontSize: _smallFontSizePt,
          color: _mutedColor,
        ),
      );

  /// A block of free text — a scene's own breakdown notes, or the note standing in for a table
  /// there is nothing to fill.
  pw.Widget _noteWidget({required OcptScriptPagePainter painter, required String text}) => pw.Text(
    text,
    style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt),
  );

  /// The full-width band introducing one category's own table: its colour swatch, its label and how
  /// many targets it holds.
  ///
  /// A band between two tables rather than a row inside one, for the reason the coverage export's
  /// own sequence band gives: a table row is bound to its column's width, and a category title has
  /// no business being folded into the width of a colour swatch.
  pw.Widget _groupBand({
    required OcptScriptPagePainter painter,
    required OcptBreakdownSheetsLabels labels,
    required OcptBreakdownSceneBarBucket bucket,
  }) => pw.Container(
    constraints: const pw.BoxConstraints(minWidth: double.infinity),
    decoration: pw.BoxDecoration(
      color: _bandColor,
      border: pw.Border.all(color: _ruleColor, width: 0.5),
    ),
    padding: const pw.EdgeInsets.all(_cellPaddingPt),
    child: pw.Row(
      children: [
        pw.Container(
          width: _swatchSizePt,
          height: _swatchSizePt,
          color: PdfColor.fromInt(bucket.color),
        ),
        pw.SizedBox(width: _cellPaddingPt),
        pw.Expanded(
          child: pw.Text(
            labels.groupLabelOf(kind: bucket.kind, category: bucket.category).toUpperCase(),
            style: pw.TextStyle(font: painter.fonts.bold, fontSize: _bodyFontSizePt),
          ),
        ),
        pw.Text(
          "${bucket.count}",
          style: pw.TextStyle(
            font: painter.fonts.regular,
            fontSize: _bodyFontSizePt,
            color: _mutedColor,
          ),
        ),
      ],
    ),
  );

  /// The header row every group's table below is read against, printed once above the first band.
  ///
  /// A table of its own rather than a row inside each group's, exactly as the coverage export's own
  /// legend prints it: a group band splits the tables into one per category, and repeating the
  /// three headers over every one of them would say the same thing five times on a busy scene.
  /// Both share [_targetColumnWidths], which is what keeps their columns lined up.
  pw.Widget _targetsHeaderTable({
    required OcptScriptPagePainter painter,
    required OcptBreakdownSheetsLabels labels,
  }) => pw.Table(
    border: pw.TableBorder.all(color: _ruleColor, width: 0.5),
    columnWidths: _targetColumnWidths,
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _bandColor),
        children: [
          for (final header in [labels.nameHeader, labels.statusHeader, labels.ownerHeader])
            _textCell(painter: painter, text: header, isBold: true),
        ],
      ),
    ],
  );

  /// The table of the targets of [targets] falling under [bucket], alphabetised by name — the very
  /// order the mode's own scene inspector groups them in, so the printed sheet and the screen read
  /// the same way.
  ///
  /// A role or a set carries neither a status nor an owner ([OcptBreakdownTarget.status] is null
  /// for either, and an owner is an element's own field), so both its cells print [_emptyValue]
  /// rather than the table growing a shape of its own per target kind.
  pw.Widget _targetsTable({
    required OcptScriptPagePainter painter,
    required OcptBreakdownSheetsLabels labels,
    required OcptBreakdownSceneBarBucket bucket,
    required List<OcptBreakdownTarget> targets,
    required Map<String, OcptElement> elementById,
    required Map<String, OcptPerson> personById,
  }) {
    final bucketTargets =
        [
          for (final target in targets)
            if (target.kind == bucket.kind && target.category == bucket.category) target,
        ]..sort((a, b) => a.name.compareTo(b.name));

    return pw.Table(
      border: pw.TableBorder.all(color: _ruleColor, width: 0.5),
      columnWidths: _targetColumnWidths,
      children: [
        for (final target in bucketTargets)
          pw.TableRow(
            children: [
              _textCell(painter: painter, text: target.name),
              _textCell(
                painter: painter,
                text: target.status == null
                    ? _emptyValue
                    : labels.elementStatusLabelOf(target.status!),
              ),
              _textCell(
                painter: painter,
                text: _ownerNameOf(
                  target: target,
                  elementById: elementById,
                  personById: personById,
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// The name of [target]'s owner, or [_emptyValue] while it has none — a role or a set never has
  /// one, and an element's own `ownerPersonId` may be unset or may name somebody the address book
  /// no longer holds (an erased person, whose row the erasure tombstoned).
  String _ownerNameOf({
    required OcptBreakdownTarget target,
    required Map<String, OcptElement> elementById,
    required Map<String, OcptPerson> personById,
  }) {
    final ownerPersonId = elementById[target.id]?.ownerPersonId;
    final owner = ownerPersonId == null ? null : personById[ownerPersonId];

    return owner?.displayName ?? _emptyValue;
  }

  /// One table cell holding [text], in the tables' shared padding.
  pw.Widget _textCell({
    required OcptScriptPagePainter painter,
    required String text,
    bool isBold = false,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(_cellPaddingPt),
    child: pw.Text(
      text.isEmpty ? _emptyValue : text,
      style: pw.TextStyle(
        font: painter.fonts.variant(bold: isBold, italic: false),
        fontSize: _bodyFontSizePt,
      ),
    ),
  );
}

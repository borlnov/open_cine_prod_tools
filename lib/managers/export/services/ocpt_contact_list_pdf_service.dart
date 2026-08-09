// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:open_cine_prod_tools/constants/ocpt_crew_positions.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/models/ocpt_contact_list_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_snapshot.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The font size, in points, of the document's own big title, printed once at the top of the flow.
const double _titleFontSizePt = 16;

/// The font size, in points, of every body line: a table cell, a note.
const double _bodyFontSizePt = 9;

/// The font size, in points, of the small muted lines: the running head, a section title.
const double _smallFontSizePt = 7;

/// The padding, in points, inside one cell of the tables below.
const double _cellPaddingPt = 4;

/// The colour the tables' rules are drawn with.
const PdfColor _ruleColor = PdfColor.fromInt(0xFFB0B0B0);

/// The background colour of a table's header row and of a group band.
const PdfColor _bandColor = PdfColor.fromInt(0xFFEDEDED);

/// The grey the running head and every muted label is printed in.
const PdfColor _mutedColor = PdfColor.fromInt(0xFF6E6E6E);

/// The `NAME / POSITION / PHONE / EMAIL` columns both the crew and the cast tables share.
const Map<int, pw.TableColumnWidth> _columnWidths = {
  0: pw.FlexColumnWidth(1.8),
  1: pw.FlexColumnWidth(1.8),
  2: pw.FlexColumnWidth(1.3),
  3: pw.FlexColumnWidth(2),
};

/// One printed row of either table: a name, a position (or a cast row's role number and name), a
/// phone number and an e-mail address — never a postal address, which Benoit was asked about and
/// chose to leave off a document that circulates to a whole crew.
class _ContactRow {
  /// Class constructor
  const _ContactRow({required this.name, required this.position, required this.phone, required this.email});

  /// The person's own name, or the actor's while this is a cast row — empty for an uncast role,
  /// which `_textCell` then prints as an em dash.
  final String name;

  /// The crew position this row holds, or the role's own `<number> · <name>` for a cast row.
  final String position;

  /// The phone number, or empty for an uncast role.
  final String phone;

  /// The e-mail address, or empty for an uncast role.
  final String email;
}

/// One crew row, still carrying what it is grouped and sorted by before it is flattened into a
/// [_ContactRow]: [department] is null for a free-label position (or one naming a catalogue entry
/// retired since), which is what sends it to the trailing group rather than under one of
/// [OcptCrewDepartment]'s own bands; [positionIndex] is that position's own rank in
/// `ocptCrewPositions`, read within its department the way the schedule mode's positions matrix
/// already orders its own rows.
class _CrewRow {
  /// Class constructor
  const _CrewRow({required this.department, required this.positionIndex, required this.contact});

  /// The department this row's position belongs to, or null for the trailing group.
  final OcptCrewDepartment? department;

  /// This position's own rank in `ocptCrewPositions`, or -1 for the trailing group (sorted by its
  /// own position label instead, see `_crewGroupsOf`).
  final int positionIndex;

  /// The row itself.
  final _ContactRow contact;
}

/// One group of the crew table: its own band label, and the rows it holds.
typedef _ContactGroup = (String label, List<_ContactRow> rows);

/// Renders a project's contact list: the crew, grouped by department, then the cast, one row per
/// role — the whole-production directory a production circulates once at the start of a shoot,
/// distinct from a call sheet's own two directories, which are scoped to one day.
///
/// This is pure rendering logic with no dialog or file-system access of its own: it's owned by
/// `OcptExportManager` and exposed as a public final field, reached through the manager rather than
/// through `globalGetIt()` (RFL18), exactly like its siblings.
///
/// **Scope**: a crew row comes from a person's own declared `person_positions`, joined with the
/// `ocptCrewPositions` catalogue — a person holding two positions is printed **twice**, once under
/// each, since a position held by somebody is this document's own unit, not a person. A cast row
/// comes from every role the project holds, cast or not: an uncast role still prints, with an em
/// dash where the contact details would be — a part nobody has cast yet is exactly the line a
/// production looks at. **A person in the address book who holds no position and plays no role
/// appears nowhere on this document**: that is the honest scope of "the crew and the cast", and
/// widening it to every contact the project references (a location's own contact, an element's
/// owner) is a decision nobody has made.
///
/// It prints no screenplay at all, so — unlike `OcptPdfExportService` — it draws nothing through
/// [OcptScriptPagePainter]'s page builders. It still takes one: the painter owns the page geometry
/// every export of this app measures a sheet with, and the Courier Prime variants all of them print
/// in.
class OcptContactListPdfService {
  /// Creates an [OcptContactListPdfService].
  ///
  /// Pass the manager's own [fontsLoader] so every export of the app session shares one font cache;
  /// a service built without one gets a loader of its own.
  OcptContactListPdfService({OcptCourierPrimeFontsLoader? fontsLoader})
    : fontsLoader = fontsLoader ?? OcptCourierPrimeFontsLoader();

  /// The loader the embedded Courier Prime font set is read through.
  final OcptCourierPrimeFontsLoader fontsLoader;

  /// The `.pdf` file name to suggest when exporting the contact list of [projectName].
  ///
  /// [suffix] is the localized word telling this document apart from the other PDFs the app writes
  /// (`My Movie - contacts.pdf`); a blank one falls back to the project name alone rather than
  /// producing a file name ending on a dangling separator, exactly as
  /// `OcptBreakdownSheetsPdfService.sheetsFileName` does.
  String contactListFileName({required String projectName, required String suffix}) =>
      suffix.trim().isEmpty ? "$projectName.pdf" : "$projectName - ${suffix.trim()}.pdf";

  /// Renders the contact list of [snapshot], returning the PDF's bytes.
  ///
  /// [pageSetup] supplies the page geometry. [exportDate] is the moment the running head's own
  /// version line prints (`Version 2026-08-08 14:32`, through [ocptScheduleGeneratedAtStamp]),
  /// resolved once per document — it defaults to [DateTime.now] so a caller that never reissues this
  /// document doesn't have to pass one. A catalogue holding nobody with a position and no cast role
  /// at all prints one readable note page rather than an empty file.
  Future<Uint8List> generate({
    required OcptResourcesSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptContactListLabels labels,
    required String projectName,
    DateTime? exportDate,
  }) async {
    final metrics = pageSetup.toMetrics();
    final painter = OcptScriptPagePainter(metrics: metrics, fonts: await fontsLoader.load());
    final versionLine =
        "${labels.versionLabel} ${ocptScheduleGeneratedAtStamp(exportDate ?? DateTime.now())}";

    final crewGroups = _crewGroupsOf(snapshot, labels);
    final castRows = _castRowsOf(snapshot);

    final pdfDocument = pw.Document();

    if (crewGroups.isEmpty && castRows.isEmpty) {
      pdfDocument.addPage(
        _page(
          painter: painter,
          labels: labels,
          projectName: projectName,
          versionLine: versionLine,
          children: [_noteWidget(painter: painter, text: labels.emptyDocumentNote)],
        ),
      );

      return pdfDocument.save();
    }

    pdfDocument.addPage(
      _page(
        painter: painter,
        labels: labels,
        projectName: projectName,
        versionLine: versionLine,
        children: [
          pw.Text(
            labels.documentTitle,
            style: pw.TextStyle(font: painter.fonts.bold, fontSize: _titleFontSizePt),
          ),
          pw.SizedBox(height: 12),
          if (crewGroups.isNotEmpty) ...[
            _sectionTitle(painter: painter, title: labels.crewSectionTitle),
            pw.SizedBox(height: 4),
            _peopleTable(painter: painter, labels: labels, rows: _crewTableRows(painter, crewGroups)),
          ],
          if (crewGroups.isNotEmpty && castRows.isNotEmpty) pw.SizedBox(height: 14),
          if (castRows.isNotEmpty) ...[
            _sectionTitle(painter: painter, title: labels.castSectionTitle),
            pw.SizedBox(height: 4),
            _peopleTable(
              painter: painter,
              labels: labels,
              rows: [for (final contact in castRows) _contactRow(painter: painter, contact: contact)],
            ),
          ],
        ],
      ),
    );

    return pdfDocument.save();
  }

  /// Every crew row of [snapshot], one per `person_positions` assignment — a person holding two
  /// positions therefore contributes two rows, one under each — grouped by department in
  /// [OcptCrewDepartment.values] order (a department holding nothing is left out entirely) and,
  /// last, the trailing group for a free-label position or one naming a catalogue entry retired
  /// since.
  ///
  /// Within a department, rows are ordered by their position's own rank in `ocptCrewPositions` (the
  /// schedule mode's positions matrix orders its own rows the same way), then by name; the trailing
  /// group, holding no catalogue rank to sort by, is ordered by its own position text instead, then
  /// by name.
  List<_ContactGroup> _crewGroupsOf(OcptResourcesSnapshot snapshot, OcptContactListLabels labels) {
    final positionById = {for (final position in ocptCrewPositions) position.id: position};
    final rows = <_CrewRow>[];

    for (final person in snapshot.people) {
      for (final assignment in person.positions) {
        final catalogued = assignment.positionId.isEmpty ? null : positionById[assignment.positionId];
        final positionLabel = catalogued != null
            ? labels.crewPositionLabelOf(catalogued.id)
            : assignment.customLabel;

        rows.add(
          _CrewRow(
            department: catalogued?.department,
            positionIndex: catalogued == null ? -1 : ocptCrewPositions.indexOf(catalogued),
            contact: _ContactRow(
              name: person.displayName,
              position: positionLabel,
              phone: person.phone,
              email: person.email,
            ),
          ),
        );
      }
    }

    final groups = <_ContactGroup>[];

    for (final department in OcptCrewDepartment.values) {
      final departmentRows = [for (final row in rows) if (row.department == department) row]
        ..sort((a, b) {
          final byPosition = a.positionIndex.compareTo(b.positionIndex);
          return byPosition != 0
              ? byPosition
              : a.contact.name.toLowerCase().compareTo(b.contact.name.toLowerCase());
        });
      if (departmentRows.isNotEmpty) {
        groups.add((
          labels.crewDepartmentLabelOf(department),
          [for (final row in departmentRows) row.contact],
        ));
      }
    }

    final unassignedRows = [for (final row in rows) if (row.department == null) row]
      ..sort((a, b) {
        final byPosition = a.contact.position.toLowerCase().compareTo(b.contact.position.toLowerCase());
        return byPosition != 0
            ? byPosition
            : a.contact.name.toLowerCase().compareTo(b.contact.name.toLowerCase());
      });
    if (unassignedRows.isNotEmpty) {
      groups.add((labels.unassignedDepartmentLabel, [for (final row in unassignedRows) row.contact]));
    }

    return groups;
  }

  /// Every cast row of [snapshot], one per role in its own display order (role-number order): the
  /// actor's own name, phone and e-mail, or all three blank for an uncast role, which [_contactRow]
  /// then prints as an em dash.
  List<_ContactRow> _castRowsOf(OcptResourcesSnapshot snapshot) {
    final personById = {for (final person in snapshot.people) person.id: person};

    return [
      for (final role in snapshot.roles)
        _ContactRow(
          name: personById[role.personId]?.displayName ?? "",
          position: "${role.number} · ${role.name}",
          phone: personById[role.personId]?.phone ?? "",
          email: personById[role.personId]?.email ?? "",
        ),
    ];
  }

  /// [groups] flattened into the rows a single flowing `pw.Table` draws: a full-width band row
  /// naming the department (never repeated across a page break — the elements grid's own category
  /// band states why: several bands would stack into a heading that lies), then that group's own
  /// contact rows.
  List<pw.TableRow> _crewTableRows(OcptScriptPagePainter painter, List<_ContactGroup> groups) => [
    for (final group in groups) ...[
      _bandRow(painter: painter, text: group.$1),
      for (final contact in group.$2) _contactRow(painter: painter, contact: contact),
    ],
  ];

  /// One table shared by the crew and the cast sections: a header row (`NAME / POSITION / PHONE /
  /// EMAIL`) marked `repeat: true` — a page torn off this document still says which column is
  /// which — then [rows].
  pw.Widget _peopleTable({
    required OcptScriptPagePainter painter,
    required OcptContactListLabels labels,
    required List<pw.TableRow> rows,
  }) => pw.Table(
    border: pw.TableBorder.all(color: _ruleColor, width: 0.5),
    columnWidths: _columnWidths,
    children: [
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: _bandColor),
        children: [
          for (final header in [
            labels.nameHeader,
            labels.positionHeader,
            labels.phoneHeader,
            labels.emailHeader,
          ])
            _textCell(painter: painter, text: header, isBold: true),
        ],
      ),
      ...rows,
    ],
  );

  /// One full-width band row naming a crew group, [text] alone in the name column, the other three
  /// left blank.
  pw.TableRow _bandRow({required OcptScriptPagePainter painter, required String text}) => pw.TableRow(
    decoration: const pw.BoxDecoration(color: _bandColor),
    children: [
      _textCell(painter: painter, text: text.toUpperCase(), isBold: true),
      _textCell(painter: painter, text: ""),
      _textCell(painter: painter, text: ""),
      _textCell(painter: painter, text: ""),
    ],
  );

  /// One ordinary row of either table.
  pw.TableRow _contactRow({required OcptScriptPagePainter painter, required _ContactRow contact}) =>
      pw.TableRow(
        children: [
          _textCell(painter: painter, text: contact.name),
          _textCell(painter: painter, text: contact.position),
          _textCell(painter: painter, text: contact.phone),
          _textCell(painter: painter, text: contact.email),
        ],
      );

  /// The document's own [pw.MultiPage], carrying [children] under a running head naming the
  /// project, the document and [versionLine] — drawn through `header:` rather than as a body child,
  /// so it repeats on every page this flows onto, exactly as `OcptShootingPlanPdfService`'s own
  /// pages state the same rule for the same reason: a page torn off a contact list has to say what
  /// it is.
  ///
  /// Its side margins are the screenplay's own right margin on both sides, exactly as
  /// `OcptBreakdownSheetsPdfService`'s sheets are: the wide left margin a screenplay needs is there
  /// to be punched and annotated, and a contact list has no such use for it.
  pw.MultiPage _page({
    required OcptScriptPagePainter painter,
    required OcptContactListLabels labels,
    required String projectName,
    required String versionLine,
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
    header: (context) => _runningHead(
      painter: painter,
      projectName: projectName,
      documentTitle: labels.documentTitle,
      versionLine: versionLine,
    ),
    build: (context) => children,
  );

  /// The running head every page of the document carries: the project and the document's own name
  /// on the left, [versionLine] on the right, over a rule.
  pw.Widget _runningHead({
    required OcptScriptPagePainter painter,
    required String projectName,
    required String documentTitle,
    required String versionLine,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            "$projectName — $documentTitle",
            style: pw.TextStyle(font: painter.fonts.regular, fontSize: _smallFontSizePt, color: _mutedColor),
          ),
          pw.Text(
            versionLine,
            style: pw.TextStyle(font: painter.fonts.regular, fontSize: _smallFontSizePt, color: _mutedColor),
          ),
        ],
      ),
      pw.SizedBox(height: 2),
      pw.Divider(color: _ruleColor, thickness: 0.5, height: 6),
      pw.SizedBox(height: 6),
    ],
  );

  /// One section's own small, muted heading.
  pw.Widget _sectionTitle({required OcptScriptPagePainter painter, required String title}) => pw.Text(
    title.toUpperCase(),
    style: pw.TextStyle(font: painter.fonts.bold, fontSize: _smallFontSizePt, color: _mutedColor),
  );

  /// A block of free text — the note standing in for the whole document on an empty catalogue.
  pw.Widget _noteWidget({required OcptScriptPagePainter painter, required String text}) =>
      pw.Text(text, style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt));

  /// One table cell holding [text], substituting [ocptScheduleEmptyValue] when it is blank — a
  /// person's own missing phone or e-mail, or the three blank fields an uncast role's row carries.
  pw.Widget _textCell({required OcptScriptPagePainter painter, required String text, bool isBold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(_cellPaddingPt),
        child: pw.Text(
          text.isEmpty ? ocptScheduleEmptyValue : text,
          style: pw.TextStyle(font: painter.fonts.variant(bold: isBold, italic: false), fontSize: _bodyFontSizePt),
        ),
      );
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_people_rows.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_rows.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_style.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_table_sections.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_convocation.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_sun_times.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The sections at the top of a call sheet: the recipients, the title block, the day heading, the
/// day's own events, the location, the sun and the department contacts.
///
/// Stateless widget builders over a page painter, shared by the general and the named sheet.
abstract final class OcptCallSheetHeaderSections {
  // ---------------------------------------------------------------------------------------------
  // Header sections
  // ---------------------------------------------------------------------------------------------

  /// Build the general sheet's own recipients line — the day's own convoked people, by first name.
  static pw.Widget recipientsSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required List<OcptDayConvocation> convocations,
    required OcptSchedulePlanSnapshot plan,
  }) {
    final names = [
      for (final convocation in convocations)
        if (convocation.personId != null)
          plan.personById[convocation.personId]?.firstName.trim() ?? "",
    ].where((name) => name.isNotEmpty).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        OcptCallSheetTableSections.sectionTitle(
          painter: painter,
          title: labels.recipientsSectionTitle,
        ),
        pw.SizedBox(height: 2),
        OcptCallSheetTableSections.noteWidget(
          painter: painter,
          text: names.isEmpty ? ocptScheduleEmptyValue : names.join(", "),
        ),
      ],
    );
  }

  /// Build a named sheet's own header: who it is for, and the position(s) or the role they are
  /// convoked
  /// under.
  static pw.Widget namedRecipientSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required String displayName,
    required String positionsOrRole,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      OcptCallSheetTableSections.sectionTitle(painter: painter, title: labels.namedRecipientLabel),
      pw.SizedBox(height: 2),
      pw.Text(
        displayName.isEmpty ? ocptScheduleEmptyValue : displayName,
        style: pw.TextStyle(font: painter.fonts.bold, fontSize: ocptCallSheetBodyFontSizePt),
      ),
      if (positionsOrRole.trim().isNotEmpty) ...[
        pw.SizedBox(height: 2),
        OcptCallSheetTableSections.noteWidget(
          painter: painter,
          text: "${labels.positionsHeader} : $positionsOrRole",
        ),
      ],
    ],
  );

  /// Build the project's own title, then the `Un film de <director>` line when there is one, then
  /// [versionLine] — the moment this sheet was produced.
  ///
  /// The version line sits in the title block rather than in the running head, unlike the shooting
  /// plan's own: a call sheet is one sheet about one day, handed over whole, and the block naming
  /// the film is where somebody comparing two of them looks first. It is printed on the general and
  /// the named sheet alike, both being reissued as a day is re-planned.
  static pw.Widget titleBlock({
    required OcptScriptPagePainter painter,
    required String projectName,
    required OcptCallSheetLabels labels,
    required String versionLine,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        projectName,
        style: pw.TextStyle(font: painter.fonts.bold, fontSize: ocptCallSheetTitleFontSizePt),
      ),
      if (labels.directorLine.trim().isNotEmpty) ...[
        pw.SizedBox(height: 2),
        pw.Text(
          labels.directorLine,
          style: pw.TextStyle(font: painter.fonts.regular, fontSize: ocptCallSheetBodyFontSizePt),
        ),
      ],
      pw.SizedBox(height: 2),
      pw.Text(
        versionLine,
        style: pw.TextStyle(
          font: painter.fonts.regular,
          fontSize: ocptCallSheetSmallFontSizePt,
          color: ocptCallSheetMutedColor,
        ),
      ),
    ],
  );

  /// Build the day's own number and its full title (`JOUR : 2` / `FEUILLE DE SERVICE DU …`).
  static pw.Widget dayHeadingSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required OcptShootingDay day,
  }) {
    final title = labels.titleOfDay(day.id);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          "${labels.dayNumberLabel} : ${day.dayNumber}",
          style: pw.TextStyle(font: painter.fonts.bold, fontSize: ocptCallSheetBodyFontSizePt),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          title.isEmpty ? "${labels.dayTagPrefix}${day.dayNumber}" : title,
          style: pw.TextStyle(font: painter.fonts.bold, fontSize: ocptCallSheetTitleFontSizePt),
        ),
      ],
    );
  }

  /// Build a named sheet's own single band line: arrival, band, departure — three figures the
  /// general
  /// sheet only ever prints per person inside its cast table or its two closing lists.
  ///
  /// The middle line is headed by [OcptCallSheetLabels.bandLabelOf] rather than by `PAT` outright:
  /// this recipient's band may cover no filming at all — a candidate seen for twenty minutes, an
  /// actor at a day of rehearsals — and *prêt à tourner* presupposes a take.
  static pw.Widget ownBandSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required OcptDayConvocation convocation,
  }) {
    final lines = [
      "${labels.arrivalHeader} : ${ocptFormatDayMinute(convocation.arrivalMinute)}",
      "${labels.bandLabelOf(isPatBand: convocation.isPatBand)} : ${ocptCallSheetPatCellOf(convocation)}",
      "${labels.departureLabel} : ${ocptFormatDayMinute(convocation.departureMinute)}",
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          pw.Text(
            line,
            style: pw.TextStyle(font: painter.fonts.bold, fontSize: ocptCallSheetBodyFontSizePt),
          ),
      ],
    );
  }

  /// Build a named sheet's own "to bring" table: one `<code> · <name>` / `SEQ` row per [rows]
  /// entry, the
  /// join [OcptSchedulePlanSnapshot.elementsToBringOnDay] makes between this recipient's own
  /// [OcptElement.broughtByPersonId] and the scenes the day actually plays.
  /// `generateNamedCallSheet` never calls this on an empty [rows] — see its own doc comment.
  static pw.Widget toBringSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required List<OcptCallSheetToBringRow> rows,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      OcptCallSheetTableSections.sectionTitle(painter: painter, title: labels.toBringSectionTitle),
      pw.SizedBox(height: 4),
      pw.Table(
        border: pw.TableBorder.all(color: ocptCallSheetRuleColor, width: 0.5),
        columnWidths: ocptCallSheetToBringColumnWidths,
        children: [
          pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(color: ocptCallSheetBandColor),
            children: [
              for (final header in [labels.nameHeader, labels.seqHeader])
                OcptCallSheetTableSections.textCell(painter: painter, text: header, isBold: true),
            ],
          ),
          for (final row in rows)
            pw.TableRow(
              children: [
                OcptCallSheetTableSections.textCell(
                  painter: painter,
                  text: "${row.element.code} · ${row.element.name}",
                ),
                OcptCallSheetTableSections.textCell(
                  painter: painter,
                  text: row.sceneNumbers.isEmpty
                      ? ocptScheduleEmptyValue
                      : row.sceneNumbers.join(", "),
                ),
              ],
            ),
        ],
      ),
    ],
  );

  /// Build the crew note, verbatim — never printed at all when the day carries none (both
  /// generators skip
  /// this widget rather than calling it on a blank note).
  static pw.Widget crewNoteSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required String note,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      OcptCallSheetTableSections.sectionTitle(painter: painter, title: labels.crewNoteSectionTitle),
      pw.SizedBox(height: 2),
      OcptCallSheetTableSections.noteWidget(painter: painter, text: note.trim()),
    ],
  );

  /// Build the day's own events, one timed line each — what the day does not control, at an
  /// absolute
  /// hour, taking part in no chain and therefore never interleaved into the main table's own
  /// milestone rows. Both generators skip this widget rather than calling it on an empty list, for
  /// a different reason than [crewNoteSection]'s own: the cast table prints an em dash on a role
  /// nobody convoked because it is a **standing** section of the reference document, while an
  /// events section only belongs on a sheet the day actually has something it does not control on.
  static pw.Widget eventsSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required List<OcptShootingDayEvent> events,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      OcptCallSheetTableSections.sectionTitle(painter: painter, title: labels.eventsSectionTitle),
      pw.SizedBox(height: 2),
      for (final event in events) ...[
        pw.Text(
          "${ocptFormatDayMinute(event.minute)} — "
          "${event.label.trim().isEmpty ? ocptScheduleEmptyValue : event.label.trim()}",
          style: pw.TextStyle(font: painter.fonts.bold, fontSize: ocptCallSheetBodyFontSizePt),
        ),
        if (event.notes.trim().isNotEmpty) ...[
          pw.SizedBox(height: 1),
          pw.Text(
            event.notes.trim(),
            style: pw.TextStyle(
              font: painter.fonts.regular,
              fontSize: ocptCallSheetSmallFontSizePt,
              color: ocptCallSheetMutedColor,
            ),
          ),
        ],
        pw.SizedBox(height: 4),
      ],
    ],
  );

  /// Build the location(s) [locations] names: name, address, then a Google Maps link built from its
  /// own
  /// coordinates when it has any — never a network call, and nothing printed when it has none.
  static pw.Widget locationSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required List<OcptLocation> locations,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      OcptCallSheetTableSections.sectionTitle(painter: painter, title: labels.locationSectionTitle),
      pw.SizedBox(height: 2),
      if (locations.isEmpty)
        OcptCallSheetTableSections.noteWidget(painter: painter, text: ocptScheduleEmptyValue)
      else
        for (final location in locations) ...[
          OcptCallSheetTableSections.noteWidget(
            painter: painter,
            text: ocptScheduleLocationAddressLine(location),
          ),
          if (ocptCallSheetMapsUrlOf(location) case final url?) ...[
            pw.SizedBox(height: 1),
            pw.UrlLink(
              destination: url,
              child: pw.Text(
                "${labels.mapsLinkLabel} : $url",
                style: pw.TextStyle(
                  font: painter.fonts.regular,
                  fontSize: ocptCallSheetBodyFontSizePt,
                  color: PdfColors.blue,
                ),
              ),
            ),
          ],
          pw.SizedBox(height: 6),
        ],
    ],
  );

  /// Build the day's own sunrise, sunset and the two civil twilights, each independently printed as
  /// [ocptScheduleEmptyValue] while [sunTimes] has no figure for it (ADR 0016).
  static pw.Widget sunSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required OcptSunTimes? sunTimes,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      OcptCallSheetTableSections.sectionTitle(painter: painter, title: labels.sunSectionTitle),
      pw.SizedBox(height: 2),
      pw.Wrap(
        spacing: 16,
        runSpacing: 2,
        children: [
          sunFigure(
            painter: painter,
            label: labels.civilDawnLabel,
            minute: sunTimes?.civilDawnMinute,
          ),
          sunFigure(painter: painter, label: labels.sunriseLabel, minute: sunTimes?.sunriseMinute),
          sunFigure(painter: painter, label: labels.sunsetLabel, minute: sunTimes?.sunsetMinute),
          sunFigure(
            painter: painter,
            label: labels.civilDuskLabel,
            minute: sunTimes?.civilDuskMinute,
          ),
        ],
      ),
    ],
  );

  /// Build one figure of [sunSection].
  static pw.Widget sunFigure({
    required OcptScriptPagePainter painter,
    required String label,
    required int? minute,
  }) => pw.Text(
    "$label ${minute == null ? ocptScheduleEmptyValue : ocptFormatDayMinute(minute)}",
    style: pw.TextStyle(font: painter.fonts.regular, fontSize: ocptCallSheetBodyFontSizePt),
  );

  /// Build the key contacts (production, direction and unit management) or the by-department
  /// contacts
  /// table (casting and extras, image, electric and grip, sound, art department, costume, hair and
  /// make-up, special effects) — the same widget for both, over whichever [departments] the caller
  /// asks for, since both are "`<position> : <first name>`, grouped by department" laid out in
  /// rows of at most four columns.
  ///
  /// **Wrapped at four columns per row, not one row however wide**: the by-department block alone
  /// can now name up to eight departments, and a single row that wide would squeeze each one's own
  /// contacts down to a sliver. Every row [contactsRowsOf] builds holds exactly four
  /// `pw.Expanded` columns, present departments first and empty ones behind them, so a row of one
  /// department reads no wider than a row of four — the reference sheet's own contacts table never
  /// lets a lone name stretch across the page.
  static pw.Widget contactsBlock({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required List<OcptCallSheetCrewContact> crewContacts,
    required Set<OcptCrewDepartment> departments,
  }) {
    final byDepartment = <OcptCrewDepartment, List<OcptCallSheetCrewContact>>{};
    for (final contact in crewContacts) {
      final department = contact.department;
      if (department == null || !departments.contains(department)) {
        continue;
      }
      (byDepartment[department] ??= <OcptCallSheetCrewContact>[]).add(contact);
    }

    final present = [
      for (final department in departments)
        if ((byDepartment[department] ?? const <OcptCallSheetCrewContact>[]).isNotEmpty) department,
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        OcptCallSheetTableSections.sectionTitle(
          painter: painter,
          title: labels.contactsSectionTitle,
        ),
        pw.SizedBox(height: 2),
        if (present.isEmpty)
          OcptCallSheetTableSections.noteWidget(painter: painter, text: ocptScheduleEmptyValue)
        else
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final (index, row) in contactsRowsOf(present).indexed) ...[
                if (index > 0) pw.SizedBox(height: 6),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    for (final department in row)
                      pw.Expanded(
                        child: departmentContactsColumn(
                          painter: painter,
                          labels: labels,
                          department: department,
                          contacts: byDepartment[department]!,
                        ),
                      ),
                    for (var i = row.length; i < ocptCallSheetContactsColumnsPerRow; i++)
                      pw.Expanded(child: pw.SizedBox()),
                  ],
                ),
              ],
            ],
          ),
      ],
    );
  }

  /// Get [present] split into rows of at most [ocptCallSheetContactsColumnsPerRow] departments
  /// each, in
  /// [present]'s own order — what [contactsBlock] lays out one `pw.Row` per row of.
  static List<List<OcptCrewDepartment>> contactsRowsOf(List<OcptCrewDepartment> present) => [
    for (var i = 0; i < present.length; i += ocptCallSheetContactsColumnsPerRow)
      present.sublist(i, math.min(i + ocptCallSheetContactsColumnsPerRow, present.length)),
  ];

  /// Build one [department]'s own column of [contactsBlock]: its upper-case heading, then one
  /// `<position> : <first name>` line per [contacts] entry, with the phone number on a muted
  /// second line when they carry one.
  static pw.Widget departmentContactsColumn({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required OcptCrewDepartment department,
    required List<OcptCallSheetCrewContact> contacts,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        labels.crewDepartmentLabelOf(department).toUpperCase(),
        style: pw.TextStyle(
          font: painter.fonts.bold,
          fontSize: ocptCallSheetSmallFontSizePt,
          color: ocptCallSheetMutedColor,
        ),
      ),
      pw.SizedBox(height: 2),
      for (final contact in contacts)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4, right: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              OcptCallSheetTableSections.noteWidget(
                painter: painter,
                text: "${contact.positionLabel} : ${contact.person.firstName}",
              ),
              if (contact.person.phone.trim().isNotEmpty)
                pw.Text(
                  contact.person.phone,
                  style: pw.TextStyle(
                    font: painter.fonts.regular,
                    fontSize: ocptCallSheetSmallFontSizePt,
                    color: ocptCallSheetMutedColor,
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_audition_row.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_cast_row.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_header_sections.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_people_list_entry.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_people_rows.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_rows.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_style.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_ordered_schedule_entry.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_guest_row.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_convocation.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_scene_effect.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_day_timelines.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shot_code.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:pdf/widgets.dart' as pw;

/// The sections that carry a call sheet's tables: the time bands, the main table, the cast table,
/// the two closing lists and the guest table, with the small cells they share.
///
/// Stateless widget builders over a page painter, shared by the general and the named sheet.
abstract final class OcptCallSheetTableSections {
  /// Build the day's own time bands — one line per slot, then the day's own PAT band (the widest
  /// span
  /// over every convocation that has one), then each `meal` block's own band.
  static pw.Widget timeBandsSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required List<OcptShootingSlot> slots,
    required OcptShootingDayTimelines? timelines,
    required List<OcptDayConvocation> convocations,
    required List<OcptOrderedScheduleEntry> orderedEntries,
  }) {
    final lines = <String>[];

    if (timelines != null) {
      for (final slot in slots) {
        final timeline = timelines.bySlotId[slot.id];
        if (timeline == null) {
          continue;
        }
        final label = slot.label.trim().isEmpty
            ? labels.hoursLinePrefix
            : "${labels.hoursLinePrefix} ${slot.label.trim()}";
        lines.add(
          ocptCallSheetTimeBandLine(
            label: label,
            startMinute: timeline.startMinute,
            endMinute: timeline.endMinute,
          ),
        );
      }
    }

    // Read over the **filming** bands alone whenever the day has any, and over the presence ones
    // only when it has none: a mixed day whose candidates turn up at 09:00 and whose unit shoots
    // from 13:00 must not print a `PAT` line opening at 09:00, which would claim the camera was
    // ready four hours before it was.
    final hasPatBand = convocations.any((convocation) => convocation.isPatBand);
    int? bandStart;
    int? bandEnd;
    for (final convocation in convocations) {
      if (convocation.isPatBand != hasPatBand) {
        continue;
      }
      final start = convocation.patStartMinute;
      final end = convocation.patEndMinute;
      if (start != null && (bandStart == null || start < bandStart)) {
        bandStart = start;
      }
      if (end != null && (bandEnd == null || end > bandEnd)) {
        bandEnd = end;
      }
    }
    if (bandStart != null && bandEnd != null) {
      lines.add(
        ocptCallSheetTimeBandLine(
          label: "${labels.hoursLinePrefix} ${labels.bandLabelOf(isPatBand: hasPatBand)}",
          startMinute: bandStart,
          endMinute: bandEnd,
        ),
      );
    }

    for (final ordered in orderedEntries) {
      if (ordered.block.kind != OcptShootingBlockKind.meal) {
        continue;
      }
      lines.add(
        ocptCallSheetTimeBandLine(
          // All three resolvers are empty on purpose: only a `meal` block reaches this line, and a
          // meal break names neither a sequence nor a candidacy — its caption is its own label or
          // the kind's.
          label: ocptCallSheetCaptionOf(
            block: ordered.block,
            labels: labels,
            headingBySceneId: const {},
            roleById: const {},
            roleCandidateById: const {},
          ),
          startMinute: ordered.entry.startMinute,
          endMinute: ordered.entry.endMinute,
        ),
      );
    }

    if (lines.isEmpty) {
      return pw.SizedBox();
    }

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

  // ---------------------------------------------------------------------------------------------
  // Main table
  // ---------------------------------------------------------------------------------------------

  /// Build the day's main table, interleaved with full-width milestone rows and, under a row that
  /// carries
  /// one, a full-width crew-note band — or [OcptCallSheetLabels.emptyDayNote] when [rows] is empty
  /// (no slot, or no block on any of them).
  ///
  /// **A shot run's own crew note prints directly under its row**, and getting that requires
  /// closing the `pw.Table` chunk the row belongs to the moment the row is seen: a `pw.TableRow`
  /// cannot span the page width the way [milestoneRowWidget] itself can, so the only way to put a
  /// full-width note right under a run of otherwise ordinary rows is to end the table there and
  /// draw the note as a widget of its own — `flushShotRows` is called the instant a pending row
  /// carries a crew note, even mid-run, splitting what would otherwise have been one continuous
  /// table into two around the note. A milestone's own crew note has no such problem, since
  /// [milestoneRowWidget] is already a full-width band and prints it inline.
  static pw.Widget mainTableSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required List<OcptCallSheetDayRow> rows,
    required List<OcptRole> roles,
  }) {
    if (rows.isEmpty) {
      return noteWidget(painter: painter, text: labels.emptyDayNote);
    }

    final children = <pw.Widget>[];
    var pendingShotRows = <OcptCallSheetDayRow>[];

    void flushShotRows() {
      if (pendingShotRows.isEmpty) {
        return;
      }
      children.add(
        mainTable(painter: painter, labels: labels, rows: pendingShotRows, roles: roles),
      );
      pendingShotRows = <OcptCallSheetDayRow>[];
    }

    for (final row in rows) {
      if (row.isMilestone) {
        flushShotRows();
        children.add(milestoneRowWidget(painter: painter, labels: labels, row: row));
      } else {
        pendingShotRows.add(row);
        if (row.crewNotes.isNotEmpty) {
          flushShotRows();
          children.add(crewNoteBandWidget(painter: painter, crewNotes: row.crewNotes));
        }
      }
    }
    flushShotRows();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) pw.SizedBox(height: 4),
          child,
        ],
      ],
    );
  }

  /// Build a full-width band naming a shot run's own crew note(s) — printed the moment
  /// [mainTableSection]'s own composition closes a table chunk on a row that carries one, since the
  /// `pw.Table` row itself cannot span the page width a note deserves. Drawn like
  /// [milestoneRowWidget]'s own container but **without** its [ocptCallSheetBandColor] fill, so a
  /// note reads as a note rather than as another milestone.
  static pw.Widget crewNoteBandWidget({
    required OcptScriptPagePainter painter,
    required List<String> crewNotes,
  }) => pw.Container(
    constraints: const pw.BoxConstraints(minWidth: double.infinity),
    decoration: pw.BoxDecoration(border: pw.Border.all(color: ocptCallSheetRuleColor, width: 0.5)),
    padding: const pw.EdgeInsets.all(ocptCallSheetCellPaddingPt),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final (index, note) in crewNotes.indexed) ...[
          if (index > 0) pw.SizedBox(height: 2),
          pw.Text(
            note,
            style: pw.TextStyle(font: painter.fonts.regular, fontSize: ocptCallSheetBodyFontSizePt),
          ),
        ],
      ],
    ),
  );

  /// Build one run of consecutive [OcptCallSheetDayRow.shotRun] rows, as a
  /// `SEQ / PLANS / EFFET / DÉCORS / RÔLES`
  /// / RÔLES` table — see [ocptCallSheetMainColumnWidths] for why the reference's own `RÉSUMÉ`
  /// column is not among them.
  static pw.Widget mainTable({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required List<OcptCallSheetDayRow> rows,
    required List<OcptRole> roles,
  }) => pw.Table(
    border: pw.TableBorder.all(color: ocptCallSheetRuleColor, width: 0.5),
    columnWidths: ocptCallSheetMainColumnWidths,
    children: [
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: ocptCallSheetBandColor),
        children: [
          for (final header in [
            labels.seqHeader,
            labels.plansHeader,
            labels.effectHeader,
            labels.setsHeader,
            labels.rolesHeader,
          ])
            textCell(painter: painter, text: header, isBold: true),
        ],
      ),
      for (final row in rows)
        pw.TableRow(
          children: [
            textCell(
              painter: painter,
              text: row.shots.isEmpty
                  ? ocptScheduleEmptyValue
                  : ocptShotSceneNumberOf(row.shots.first),
            ),
            textCell(painter: painter, text: row.shots.map(ocptShotRankOf).join(",")),
            textCell(
              painter: painter,
              text: ocptSceneEffectOf(row.heading).printedEffect ?? ocptScheduleEmptyValue,
            ),
            textCell(painter: painter, text: row.shootingSets ?? ocptScheduleEmptyValue),
            textCell(painter: painter, text: ocptCallSheetRolesLabelOf(row, roles)),
          ],
        ),
    ],
  );

  /// Build a full-width band naming a non-shot block and its own time band — under it, the roles
  /// that
  /// band expects, on a line of their own behind the `RÔLES` label the main table already heads its
  /// own column with ([ocptScheduleBlockRoleNumbersLine]), then the block's own crew note, if it
  /// has one. A band expecting nobody and carrying no note prints the one time-band line alone. The
  /// note prints inline, unlike a shot run's own ([crewNoteBandWidget]): this band is already
  /// full-width, so it has nothing to close and reopen the way a `pw.Table` row does.
  static pw.Widget milestoneRowWidget({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required OcptCallSheetDayRow row,
  }) {
    final rolesLine = ocptScheduleBlockRoleNumbersLine(
      roleNumbers: row.milestoneRoleNumbers,
      rolesLabel: labels.rolesHeader,
    );

    return pw.Container(
      constraints: const pw.BoxConstraints(minWidth: double.infinity),
      decoration: pw.BoxDecoration(
        color: ocptCallSheetBandColor,
        border: pw.Border.all(color: ocptCallSheetRuleColor, width: 0.5),
      ),
      padding: const pw.EdgeInsets.all(ocptCallSheetCellPaddingPt),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            ocptCallSheetTimeBandLine(
              label: row.milestoneCaption ?? "",
              startMinute: row.startMinute,
              endMinute: row.endMinute,
            ),
            style: pw.TextStyle(font: painter.fonts.bold, fontSize: ocptCallSheetBodyFontSizePt),
          ),
          if (rolesLine != null) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              rolesLine,
              style: pw.TextStyle(
                font: painter.fonts.regular,
                fontSize: ocptCallSheetBodyFontSizePt,
              ),
            ),
          ],
          for (final note in row.crewNotes) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              note,
              style: pw.TextStyle(
                font: painter.fonts.regular,
                fontSize: ocptCallSheetBodyFontSizePt,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------------------------
  // Cast table, crew list, cast-and-extras list — day-wide, on both sheets
  // ---------------------------------------------------------------------------------------------

  /// Build the day's own cast table: `RÔLE / COMÉDIEN / SEQ / ARRIVÉE / PAT`.
  static pw.Widget castTableSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required List<OcptCallSheetCastRow> rows,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      sectionTitle(painter: painter, title: labels.castSectionTitle),
      pw.SizedBox(height: 4),
      if (rows.isEmpty)
        noteWidget(painter: painter, text: ocptScheduleEmptyValue)
      else
        pw.Table(
          border: pw.TableBorder.all(color: ocptCallSheetRuleColor, width: 0.5),
          columnWidths: ocptCallSheetCastColumnWidths,
          children: [
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: ocptCallSheetBandColor),
              children: [
                for (final header in [
                  labels.roleHeader,
                  labels.actorHeader,
                  labels.seqHeader,
                  labels.arrivalHeader,
                  // One header over many bands: `PAT` the moment any row's own band covers filming,
                  // `PRÉSENCE` on a day that films nothing at all — a day of rehearsals heads a
                  // column of hours nobody is due ready to shoot for.
                  labels.bandLabelOf(
                    isPatBand: rows.any((row) => row.convocation?.isPatBand ?? false),
                  ),
                ])
                  textCell(painter: painter, text: header, isBold: true),
              ],
            ),
            for (final row in rows)
              pw.TableRow(
                children: [
                  textCell(painter: painter, text: "${row.role.number} · ${row.role.name}"),
                  textCell(
                    painter: painter,
                    text: (row.actor?.displayName ?? "").trim().isEmpty
                        ? ocptScheduleEmptyValue
                        : row.actor!.displayName,
                  ),
                  textCell(
                    painter: painter,
                    text: row.sceneNumbers.isEmpty
                        ? ocptScheduleEmptyValue
                        : row.sceneNumbers.join(", "),
                  ),
                  textCell(
                    painter: painter,
                    text: row.convocation == null
                        ? ocptScheduleEmptyValue
                        : ocptFormatDayMinute(row.convocation!.arrivalMinute),
                  ),
                  textCell(painter: painter, text: ocptCallSheetPatCellOf(row.convocation)),
                ],
              ),
          ],
        ),
    ],
  );

  /// Build the crew list, the cast-and-extras list or the day's own candidates list — the same
  /// `NOM / <second column> / TEL. / MAIL / HORAIRES` shape for all three, since all three answer
  /// the one question a directory exists for: who is on this day, under what, and how do I reach
  /// them.
  ///
  /// [secondColumnHeader] is the only thing that differs between them, and it is a heading rather
  /// than a shape: the two lists that read a *position* head it
  /// [OcptCallSheetLabels.positionsHeader] (their default), while the candidates list heads it
  /// [OcptCallSheetLabels.roleHeader], somebody seen for a part holding no position at all.
  /// [OcptCallSheetPeopleListEntry.positionOrRole] has carried both readings since the
  /// cast-and-extras list joined the crew list.
  static pw.Widget peopleListSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required String title,
    required List<OcptCallSheetPeopleListEntry> entries,
    String? secondColumnHeader,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      sectionTitle(painter: painter, title: title),
      pw.SizedBox(height: 4),
      if (entries.isEmpty)
        noteWidget(painter: painter, text: ocptScheduleEmptyValue)
      else
        pw.Table(
          border: pw.TableBorder.all(color: ocptCallSheetRuleColor, width: 0.5),
          columnWidths: ocptCallSheetPeopleColumnWidths,
          children: [
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: ocptCallSheetBandColor),
              children: [
                for (final header in [
                  labels.nameHeader,
                  secondColumnHeader ?? labels.positionsHeader,
                  labels.phoneHeader,
                  labels.emailHeader,
                  labels.hoursLinePrefix,
                ])
                  textCell(painter: painter, text: header, isBold: true),
              ],
            ),
            for (final entry in entries)
              pw.TableRow(
                children: [
                  textCell(painter: painter, text: entry.name),
                  textCell(painter: painter, text: entry.positionOrRole),
                  textCell(painter: painter, text: entry.phone),
                  textCell(painter: painter, text: entry.email),
                  textCell(painter: painter, text: entry.scheduleLabel),
                ],
              ),
          ],
        ),
    ],
  );

  /// Build the day's own audition table (`HORAIRES / RÔLE / CANDIDAT`): one row per candidacy an
  /// audition
  /// block names, in the running order the timetable resolved, saying at what hour which part is
  /// being seen and by whom.
  ///
  /// Printed **beside** the main table rather than instead of it, and only on a day whose own
  /// blocks hold an audition: a production that auditions in the morning and shoots in the
  /// afternoon gets one piece of paper carrying both tables, in that order, and a day that
  /// auditions nobody has no heading for it at all — the rule the events, guest and crew-note
  /// sections already follow.
  ///
  /// Both generators call this on their **own** [rows], the general sheet's read off the whole day
  /// and a named sheet's off its recipient's own slots alone: this is a reading of the timetable,
  /// and the timetable is the one thing a named sheet narrows. The day's own candidates list
  /// ([ocptCallSheetCandidateListEntries]) is day-wide on both, being a directory.
  static pw.Widget auditionTableSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required List<OcptCallSheetAuditionRow> rows,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      sectionTitle(painter: painter, title: labels.auditionsSectionTitle),
      pw.SizedBox(height: 4),
      pw.Table(
        border: pw.TableBorder.all(color: ocptCallSheetRuleColor, width: 0.5),
        columnWidths: ocptCallSheetAuditionColumnWidths,
        children: [
          pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(color: ocptCallSheetBandColor),
            children: [
              for (final header in [
                labels.hoursLinePrefix,
                labels.roleHeader,
                labels.candidateHeader,
              ])
                textCell(painter: painter, text: header, isBold: true),
            ],
          ),
          for (final row in rows)
            pw.TableRow(
              children: [
                textCell(
                  painter: painter,
                  text:
                      "${ocptFormatDayMinute(row.startMinute)} – "
                      "${ocptFormatDayMinute(row.endMinute)}",
                ),
                textCell(painter: painter, text: row.roleLabel ?? ocptScheduleEmptyValue),
                textCell(painter: painter, text: row.candidateName ?? ocptScheduleEmptyValue),
              ],
            ),
        ],
      ),
    ],
  );

  /// Build the day's own trailing guest table (`NOM / MOTIF / HORAIRES`) — a guest never carries a
  /// PAT
  /// band (ADR 0018), so unlike [peopleListSection] this table has no `PAT` column to leave blank
  /// for one at all. Printed after the cast-and-extras list on both sheets, the shape the
  /// `Convocations` dock panel's own trailing guest group already gives guests, and for the same
  /// reason: they are on the day and are owed an hour, but they are not the call an assistant
  /// director reads down.
  static pw.Widget guestsSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required List<OcptScheduleGuestRow> rows,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      sectionTitle(painter: painter, title: labels.guestsSectionTitle),
      pw.SizedBox(height: 4),
      pw.Table(
        border: pw.TableBorder.all(color: ocptCallSheetRuleColor, width: 0.5),
        columnWidths: ocptCallSheetGuestColumnWidths,
        children: [
          pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(color: ocptCallSheetBandColor),
            children: [
              for (final header in [
                labels.nameHeader,
                labels.guestReasonHeader,
                labels.hoursLinePrefix,
              ])
                textCell(painter: painter, text: header, isBold: true),
            ],
          ),
          for (final row in rows)
            pw.TableRow(
              children: [
                textCell(painter: painter, text: row.name),
                guestReasonCell(painter: painter, row: row),
                textCell(painter: painter, text: row.hours),
              ],
            ),
        ],
      ),
    ],
  );

  /// Build one [guestsSection] row's own `MOTIF` cell: the guest's own reason(s), then their own
  /// note(s)
  /// on a muted second line when they carry any — the same shape
  /// [OcptCallSheetHeaderSections.contactsBlock]'s own contact entries print a phone number under a
  /// position in.
  static pw.Widget guestReasonCell({
    required OcptScriptPagePainter painter,
    required OcptScheduleGuestRow row,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(ocptCallSheetCellPaddingPt),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          row.reason.isEmpty ? ocptScheduleEmptyValue : row.reason,
          style: pw.TextStyle(font: painter.fonts.regular, fontSize: ocptCallSheetBodyFontSizePt),
        ),
        if (row.notes.isNotEmpty) ...[
          pw.SizedBox(height: 1),
          pw.Text(
            row.notes,
            style: pw.TextStyle(
              font: painter.fonts.regular,
              fontSize: ocptCallSheetSmallFontSizePt,
              color: ocptCallSheetMutedColor,
            ),
          ),
        ],
      ],
    ),
  );

  // ---------------------------------------------------------------------------------------------
  // Small shared drawing helpers
  // ---------------------------------------------------------------------------------------------

  /// Build one section's own small, muted heading.
  static pw.Widget sectionTitle({required OcptScriptPagePainter painter, required String title}) =>
      pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          font: painter.fonts.bold,
          fontSize: ocptCallSheetSmallFontSizePt,
          color: ocptCallSheetMutedColor,
        ),
      );

  /// Build a block of free text.
  static pw.Widget noteWidget({required OcptScriptPagePainter painter, required String text}) =>
      pw.Text(
        text,
        style: pw.TextStyle(font: painter.fonts.regular, fontSize: ocptCallSheetBodyFontSizePt),
      );

  /// Build one table cell holding [text].
  static pw.Widget textCell({
    required OcptScriptPagePainter painter,
    required String text,
    bool isBold = false,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(ocptCallSheetCellPaddingPt),
    child: pw.Text(
      text.isEmpty ? ocptScheduleEmptyValue : text,
      style: pw.TextStyle(
        font: painter.fonts.variant(bold: isBold, italic: false),
        fontSize: ocptCallSheetBodyFontSizePt,
      ),
    ),
  );
}

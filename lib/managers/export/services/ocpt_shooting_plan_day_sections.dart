// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_ordered_schedule_entry.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_guest_row.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_page_parts.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_style.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_day_timelines.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:pdf/widgets.dart' as pw;

/// A day's own agenda page of the shooting plan: its location, hours and sets lines, the events,
/// the guests, the timetable and the shot table.
///
/// Stateless page and widget builders over a page painter.
abstract final class OcptShootingPlanDaySections {
  // ---------------------------------------------------------------------------------------------
  // Detailed day agenda
  // ---------------------------------------------------------------------------------------------

  /// Build one day's own detailed agenda: its title, its location(s), its per-slot hours, its own
  /// events
  /// next to them, the sets used, then the interleaved timetable — the milestones as prose and the
  /// shot runs as tables, a block's own [OcptShootingDayBlock.crewNote] printed under its row —
  /// and, trailing it, the day's own guest table.
  static pw.MultiPage dayAgendaPage({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required String projectName,
    required String versionLine,
    required OcptSchedulePlanSnapshot plan,
    required String dayId,
    required Map<String, String> headingBySceneId,
  }) {
    final day = plan.schedule.daysById[dayId]!;
    final slots = plan.schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
    final timelines = plan.timelinesOfDay(dayId);
    final orderedEntries = ocptOrderedScheduleEntriesOfDay(plan: plan, dayId: dayId);
    final locations = ocptScheduleLocationsOfSlots(plan, slots);
    final events = plan.schedule.eventsByDayId[dayId] ?? const <OcptShootingDayEvent>[];
    final guestRows = ocptScheduleGuestRowsOfDay(
      plan: plan,
      dayId: dayId,
      unnamedPersonLabel: labels.unnamedPersonLabel,
    );
    final title = labels.titleOfDay(dayId);

    return pw.MultiPage(
      pageFormat: OcptShootingPlanPageParts.portraitPageFormat(painter),
      header: (context) => OcptShootingPlanPageParts.runningHead(
        painter: painter,
        projectName: projectName,
        documentTitle: labels.documentTitle,
        versionLine: versionLine,
      ),
      build: (context) => [
        pw.SizedBox(height: 6),
        pw.Text(
          title.isEmpty ? "${labels.dayTagPrefix}${day.dayNumber}" : title,
          style: pw.TextStyle(font: painter.fonts.bold, fontSize: ocptShootingPlanTitleFontSizePt),
        ),
        pw.SizedBox(height: 10),
        daySectionTitle(painter: painter, text: labels.dayLocationLabel),
        pw.SizedBox(height: 2),
        ...locationLines(painter: painter, locations: locations),
        pw.SizedBox(height: 10),
        daySectionTitle(painter: painter, text: labels.dayHoursLabel),
        pw.SizedBox(height: 2),
        ...hoursLines(painter: painter, labels: labels, slots: slots, timelines: timelines),
        if (events.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          eventsSection(painter: painter, labels: labels, events: events),
        ],
        pw.SizedBox(height: 10),
        daySectionTitle(painter: painter, text: labels.daySetsLabel),
        pw.SizedBox(height: 2),
        ...setsLines(painter: painter, plan: plan, slots: slots, locations: locations),
        pw.SizedBox(height: 10),
        daySectionTitle(painter: painter, text: labels.dayTimetableLabel),
        pw.SizedBox(height: 4),
        ...dayTimetableWidgets(
          painter: painter,
          labels: labels,
          orderedEntries: orderedEntries,
          plan: plan,
          headingBySceneId: headingBySceneId,
        ),
        if (guestRows.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          guestsSection(painter: painter, labels: labels, rows: guestRows),
        ],
      ],
    );
  }

  /// Build a section's own small, muted heading.
  static pw.Widget daySectionTitle({
    required OcptScriptPagePainter painter,
    required String text,
  }) => pw.Text(
    text.toUpperCase(),
    style: pw.TextStyle(
      font: painter.fonts.bold,
      fontSize: ocptShootingPlanSmallFontSizePt,
      color: ocptShootingPlanMutedColor,
    ),
  );

  /// Build [locations]' own name and address, one line each, or a single [ocptScheduleEmptyValue]
  /// line
  /// when there is none.
  static List<pw.Widget> locationLines({
    required OcptScriptPagePainter painter,
    required List<OcptLocation> locations,
  }) {
    if (locations.isEmpty) {
      return [OcptShootingPlanPageParts.noteWidget(painter: painter, text: ocptScheduleEmptyValue)];
    }
    return [
      for (final location in locations)
        OcptShootingPlanPageParts.noteWidget(
          painter: painter,
          text: ocptScheduleLocationAddressLine(location),
        ),
    ];
  }

  /// Build one line per live slot: its own label, the call time (its resolved start) and the
  /// estimated
  /// end (its resolved end, or [ocptScheduleEmptyValue] while it carries no block yet).
  static List<pw.Widget> hoursLines({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required List<OcptShootingSlot> slots,
    required OcptShootingDayTimelines? timelines,
  }) {
    if (timelines == null || slots.isEmpty) {
      return [OcptShootingPlanPageParts.noteWidget(painter: painter, text: ocptScheduleEmptyValue)];
    }

    final lines = <String>[];
    for (final slot in slots) {
      final timeline = timelines.bySlotId[slot.id];
      if (timeline == null) {
        continue;
      }
      final label = slot.label.trim().isEmpty ? ocptScheduleEmptyValue : slot.label.trim();
      final start = ocptFormatDayMinute(timeline.startMinute);
      final end = timeline.endMinute == null
          ? ocptScheduleEmptyValue
          : ocptFormatDayMinute(timeline.endMinute!);
      lines.add("$label : ${labels.callTimeLabel} $start … ${labels.estimatedEndLabel} $end");
    }

    if (lines.isEmpty) {
      return [OcptShootingPlanPageParts.noteWidget(painter: painter, text: ocptScheduleEmptyValue)];
    }
    return [
      for (final line in lines) OcptShootingPlanPageParts.noteWidget(painter: painter, text: line),
    ];
  }

  /// Build one line per [locations] entry: its own name, then the sets used there that day,
  /// comma-joined
  /// — or [ocptScheduleEmptyValue] when no slot at that location named one.
  static List<pw.Widget> setsLines({
    required OcptScriptPagePainter painter,
    required OcptSchedulePlanSnapshot plan,
    required List<OcptShootingSlot> slots,
    required List<OcptLocation> locations,
  }) {
    if (locations.isEmpty) {
      return [OcptShootingPlanPageParts.noteWidget(painter: painter, text: ocptScheduleEmptyValue)];
    }

    final setNamesByLocationId = <String, Set<String>>{};
    for (final slot in slots) {
      final locationId = slot.locationId;
      final setId = slot.setId;
      if (locationId == null || setId == null) {
        continue;
      }
      final setName = plan.setById[setId]?.name.trim();
      if (setName == null || setName.isEmpty) {
        continue;
      }
      (setNamesByLocationId[locationId] ??= <String>{}).add(setName);
    }

    return [
      for (final location in locations)
        OcptShootingPlanPageParts.noteWidget(
          painter: painter,
          text:
              "${location.name.trim().isEmpty ? ocptScheduleEmptyValue : location.name.trim()} : "
              "${joinedOrEmpty(setNamesByLocationId[location.id])}",
        ),
    ];
  }

  /// Get [names], sorted and comma-joined, or [ocptScheduleEmptyValue] while it is null or empty.
  static String joinedOrEmpty(Set<String>? names) {
    if (names == null || names.isEmpty) {
      return ocptScheduleEmptyValue;
    }
    final sorted = names.toList()..sort();
    return sorted.join(", ");
  }

  /// Build the day's own events section: [OcptShootingPlanLabels.eventsSectionTitle] then one bold
  /// `HH:mm — <label>` line per event, its own free-form note beneath in a muted second line when
  /// it carries one.
  ///
  /// Mirrors `OcptCallSheetPdfService._eventsSection`, placed here beside the day's own hours
  /// section for the same reason it sits beside that document's own time bands: an event is a fact
  /// about the day rather than about any one slot's chain, so it takes part in no chain and is
  /// never interleaved into the timetable [dayTimetableWidgets] builds. Never called on a day with
  /// no event at all — see [dayAgendaPage]'s own composition for why an empty section is skipped
  /// entirely rather than drawn over an em dash.
  static pw.Widget eventsSection({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required List<OcptShootingDayEvent> events,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      daySectionTitle(painter: painter, text: labels.eventsSectionTitle),
      pw.SizedBox(height: 2),
      for (final event in events) ...[
        pw.Text(
          "${ocptFormatDayMinute(event.minute)} — "
          "${event.label.trim().isEmpty ? ocptScheduleEmptyValue : event.label.trim()}",
          style: pw.TextStyle(font: painter.fonts.bold, fontSize: ocptShootingPlanBodyFontSizePt),
        ),
        if (event.notes.trim().isNotEmpty) ...[
          pw.SizedBox(height: 1),
          pw.Text(
            event.notes.trim(),
            style: pw.TextStyle(
              font: painter.fonts.regular,
              fontSize: ocptShootingPlanSmallFontSizePt,
              color: ocptShootingPlanMutedColor,
            ),
          ),
        ],
        pw.SizedBox(height: 4),
      ],
    ],
  );

  /// Build the day's own trailing guest table (`NOM / MOTIF / HORAIRES`) — the shape
  /// `OcptCallSheetPdfService._guestsSection` already gives a day's guests, and for the same
  /// reason: a guest is owed an arrival and a departure and never a PAT band (ADR 0018), so there
  /// is no fourth column here to leave blank for one. Never called on a day with no guest at all —
  /// see [dayAgendaPage]'s own composition.
  static pw.Widget guestsSection({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required List<OcptScheduleGuestRow> rows,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      daySectionTitle(painter: painter, text: labels.guestsSectionTitle),
      pw.SizedBox(height: 4),
      pw.Table(
        border: pw.TableBorder.all(color: ocptShootingPlanRuleColor, width: 0.5),
        columnWidths: ocptShootingPlanGuestColumnWidths,
        children: [
          pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(color: ocptShootingPlanBandColor),
            children: [
              for (final header in [
                labels.nameHeader,
                labels.guestReasonHeader,
                labels.hoursLinePrefix,
              ])
                OcptShootingPlanPageParts.textCell(painter: painter, text: header, isBold: true),
            ],
          ),
          for (final row in rows)
            pw.TableRow(
              children: [
                OcptShootingPlanPageParts.textCell(painter: painter, text: row.name),
                guestReasonCell(painter: painter, row: row),
                OcptShootingPlanPageParts.textCell(painter: painter, text: row.hours),
              ],
            ),
        ],
      ),
    ],
  );

  /// Build one [guestsSection] row's own `MOTIF` cell: the guest's own reason(s), then their own
  /// note(s)
  /// on a muted second line when they carry any — mirrors
  /// `OcptCallSheetPdfService._guestReasonCell`.
  static pw.Widget guestReasonCell({
    required OcptScriptPagePainter painter,
    required OcptScheduleGuestRow row,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(ocptShootingPlanCellPaddingPt),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          row.reason.isEmpty ? ocptScheduleEmptyValue : row.reason,
          style: pw.TextStyle(
            font: painter.fonts.regular,
            fontSize: ocptShootingPlanBodyFontSizePt,
          ),
        ),
        if (row.notes.isNotEmpty) ...[
          pw.SizedBox(height: 1),
          pw.Text(
            row.notes,
            style: pw.TextStyle(
              font: painter.fonts.regular,
              fontSize: ocptShootingPlanSmallFontSizePt,
              color: ocptShootingPlanMutedColor,
            ),
          ),
        ],
      ],
    ),
  );

  /// Build a full-width band naming a shot run's own crew note — printed the moment a run is
  /// interrupted
  /// by a block that carries one, since a `pw.Table` row cannot itself span the page width a note
  /// deserves. Mirrors `OcptCallSheetPdfService._crewNoteBandWidget`, minus its own list of several
  /// notes: here it is always exactly the one block's own, [dayTimetableWidgets] calling this the
  /// instant it sees one rather than accumulating several across a run.
  static pw.Widget crewNoteBandWidget({
    required OcptScriptPagePainter painter,
    required String crewNote,
  }) => pw.Container(
    constraints: const pw.BoxConstraints(minWidth: double.infinity),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: ocptShootingPlanRuleColor, width: 0.5),
    ),
    padding: const pw.EdgeInsets.all(ocptShootingPlanCellPaddingPt),
    child: pw.Text(
      crewNote,
      style: pw.TextStyle(font: painter.fonts.regular, fontSize: ocptShootingPlanBodyFontSizePt),
    ),
  );

  /// Build the day's own interleaved timetable: a run of consecutive [OcptShootingBlockKind.shot]
  /// blocks
  /// becomes one shot table, every other block becomes its own prose milestone line — or
  /// [OcptShootingPlanLabels.emptyDayScheduleNote] when [orderedEntries] is empty (no slot, or no
  /// block on any of them).
  ///
  /// **A block's own [OcptShootingDayBlock.crewNote] prints under its own row**: `notes` is the
  /// private one that never prints, `crewNote` is the one that does. A shot run's own note closes
  /// the pending table chunk the moment it is seen — mirroring
  /// `OcptCallSheetTableSections.mainTableSection`'s own `flushShotRows` — since a `pw.Table` row
  /// cannot itself span the page width the note deserves; a milestone's own note has no such
  /// problem, [milestoneProseLine] already being a full-width line that prints it inline.
  static List<pw.Widget> dayTimetableWidgets({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required List<OcptOrderedScheduleEntry> orderedEntries,
    required OcptSchedulePlanSnapshot plan,
    required Map<String, String> headingBySceneId,
  }) {
    final widgets = <pw.Widget>[];
    var pendingShots = <(OcptShot, OcptOrderedScheduleEntry)>[];

    void flush() {
      if (pendingShots.isEmpty) {
        return;
      }
      widgets.add(shotTable(painter: painter, labels: labels, rows: pendingShots, plan: plan));
      pendingShots = <(OcptShot, OcptOrderedScheduleEntry)>[];
    }

    for (final ordered in orderedEntries) {
      final block = ordered.block;
      if (block.kind == OcptShootingBlockKind.shot) {
        final shot = block.shotId == null ? null : plan.shotById(block.shotId!);
        if (shot == null) {
          continue;
        }
        pendingShots.add((shot, ordered));
        final crewNote = block.crewNote.trim();
        if (crewNote.isNotEmpty) {
          flush();
          widgets.add(crewNoteBandWidget(painter: painter, crewNote: crewNote));
        }
        continue;
      }

      flush();
      final caption = ocptScheduleBlockCaptionOf(
        block: block,
        headingBySceneId: headingBySceneId,
        roleById: plan.roleById,
        roleCandidateById: plan.roleCandidateById,
        blockKindLabelOf: labels.blockKindLabelOf,
      );
      widgets.add(
        milestoneProseLine(
          painter: painter,
          labels: labels,
          caption: caption,
          rolesLine: ocptScheduleBlockRoleNumbersLine(
            roleNumbers: ocptScheduleBlockRoleNumbersOf(
              block: block,
              slot: ordered.slot,
              roleById: plan.roleById,
            ),
            rolesLabel: labels.rolesLabel,
          ),
          startMinute: ordered.entry.startMinute,
          endMinute: ordered.entry.endMinute,
          crewNote: block.crewNote.trim(),
        ),
      );
    }
    flush();

    if (widgets.isEmpty) {
      return [
        OcptShootingPlanPageParts.noteWidget(painter: painter, text: labels.emptyDayScheduleNote),
      ];
    }
    return [
      for (final (index, widget) in widgets.indexed) ...[
        if (index > 0) pw.SizedBox(height: 4),
        widget,
      ],
    ];
  }

  /// Build a non-shot block's own prose line (`De 16h45 à 17h15 : …`), or
  /// `<from> <start> : <caption>`
  /// when [endMinute] is null — a milestone whose block resolves to zero duration, or a slot with
  /// nothing placed on it yet — then [rolesLine] beneath it when the band expects anybody
  /// ([ocptScheduleBlockRoleNumbersLine], null for every band that doesn't), then [crewNote] on its
  /// own line when the block carries one — printed inline, unlike a shot run's own
  /// ([crewNoteBandWidget]): this line is already full-width, so it has nothing to close and
  /// reopen the way a `pw.Table` row does.
  static pw.Widget milestoneProseLine({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required String caption,
    required String? rolesLine,
    required int startMinute,
    required int? endMinute,
    required String crewNote,
  }) {
    final start = ocptFormatDayMinute(startMinute);
    final text = endMinute == null
        ? "${labels.milestoneFromLabel} $start : $caption"
        : "${labels.milestoneFromLabel} $start ${labels.milestoneToLabel} "
              "${ocptFormatDayMinute(endMinute)} : "
              "$caption";

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            text,
            style: pw.TextStyle(
              font: painter.fonts.italic,
              fontSize: ocptShootingPlanBodyFontSizePt,
            ),
          ),
          if (rolesLine != null)
            pw.Text(
              rolesLine,
              style: pw.TextStyle(
                font: painter.fonts.italic,
                fontSize: ocptShootingPlanBodyFontSizePt,
              ),
            ),
          if (crewNote.isNotEmpty)
            pw.Text(
              crewNote,
              style: pw.TextStyle(
                font: painter.fonts.regular,
                fontSize: ocptShootingPlanBodyFontSizePt,
              ),
            ),
        ],
      ),
    );
  }

  /// Build one run of consecutive shot blocks, as an
  /// `Hours / Plan / Valeur de plan / Move. / Cadre / Commentaire / Perso.`
  /// Commentaire / Perso.` table — the hours column reading each row's own resolved start over its
  /// resolved end, off the very [OcptOrderedScheduleEntry] the row was placed from, never a stored
  /// anchor and never taken modulo anything (a night run crossing midnight prints past `23:59`
  /// through [ocptFormatDayMinute] exactly as every other hour in this document does).
  static pw.Widget shotTable({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required List<(OcptShot, OcptOrderedScheduleEntry)> rows,
    required OcptSchedulePlanSnapshot plan,
  }) => pw.Table(
    border: pw.TableBorder.all(color: ocptShootingPlanRuleColor, width: 0.5),
    columnWidths: ocptShootingPlanShotColumnWidths,
    children: [
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: ocptShootingPlanBandColor),
        children: [
          for (final header in [
            labels.hoursHeader,
            labels.planHeader,
            labels.shotSizeHeader,
            labels.moveHeader,
            labels.framingHeader,
            labels.commentHeader,
            labels.persoLabel,
          ])
            OcptShootingPlanPageParts.textCell(painter: painter, text: header, isBold: true),
        ],
      ),
      for (final (shot, ordered) in rows)
        pw.TableRow(
          children: [
            OcptShootingPlanPageParts.textCell(
              painter: painter,
              text:
                  "${ocptFormatDayMinute(ordered.entry.startMinute)} – "
                  "${ocptFormatDayMinute(ordered.entry.endMinute)}",
            ),
            OcptShootingPlanPageParts.textCell(painter: painter, text: shot.code),
            OcptShootingPlanPageParts.textCell(painter: painter, text: shot.shotSize),
            OcptShootingPlanPageParts.textCell(painter: painter, text: shot.cameraMove),
            OcptShootingPlanPageParts.textCell(painter: painter, text: shot.framing),
            OcptShootingPlanPageParts.textCell(painter: painter, text: shot.notes),
            OcptShootingPlanPageParts.textCell(
              painter: painter,
              text: roleNamesOf(shot, plan.roles),
            ),
          ],
        ),
    ],
  );

  /// Get the role names of every one of [shot]'s own [OcptShot.characters] matched against [roles]
  /// (through `normalizeCharacterName`, the same join every reader of a shot's characters uses), or
  /// [ocptScheduleEmptyValue] when none matched.
  static String roleNamesOf(OcptShot shot, List<OcptRole> roles) {
    final byNormalizedName = {for (final role in roles) normalizeCharacterName(role.name): role};
    final matched = <String>{};
    for (final name in shot.characters) {
      final role = byNormalizedName[name];
      if (role != null) {
        matched.add(role.name);
      }
    }
    if (matched.isEmpty) {
      return ocptScheduleEmptyValue;
    }
    final sorted = matched.toList()..sort();
    return sorted.join(", ");
  }
}

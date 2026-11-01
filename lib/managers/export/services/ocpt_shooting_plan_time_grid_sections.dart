// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_day_sections.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_grid_sections.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_page_parts.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_style.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_column_input.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_event_input.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_event_marker.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_event_placement.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_grid.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_agenda_tile.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:pdf/widgets.dart' as pw;

/// The ten-minute time grid pages of the shooting plan: the day laid out minute by minute, by
/// department column.
///
/// Stateless page and widget builders over a page painter.
abstract final class OcptShootingPlanTimeGridSections {
  // ---------------------------------------------------------------------------------------------
  // Ten-minute day grid
  // ---------------------------------------------------------------------------------------------

  /// [dayId]'s own [OcptShootingDayAgendaGrid], built from [plan]'s resolved timelines and events —
  /// the one place this service turns those into the grid's own pure input types.
  ///
  /// A shot block's own tile caption is its shot's own code (`shot.code`), never its full row of
  /// fields: the ten-minute grid's own columns are narrow, and the detailed agenda right before it
  /// already prints every other field of the very same shot. Every other block kind reads its
  /// caption the same way [OcptShootingPlanDaySections.dayTimetableWidgets] does, through
  /// [ocptScheduleBlockCaptionOf].
  static OcptShootingDayAgendaGrid tenMinuteGridOf({
    required OcptShootingPlanLabels labels,
    required OcptSchedulePlanSnapshot plan,
    required String dayId,
    required Map<String, String> headingBySceneId,
  }) {
    final slots = plan.schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
    final timelines = plan.timelinesOfDay(dayId);
    if (timelines == null) {
      return const OcptShootingDayAgendaGrid.empty();
    }

    final blocksBySlotId = <String, List<OcptShootingDayBlock>>{};
    for (final block in plan.schedule.blocksByDayId[dayId] ?? const <OcptShootingDayBlock>[]) {
      (blocksBySlotId[block.slotId] ??= <OcptShootingDayBlock>[]).add(block);
    }

    final columns = <OcptShootingDayAgendaColumnInput>[];
    for (final slot in slots) {
      final timeline = timelines.bySlotId[slot.id];
      if (timeline == null) {
        continue;
      }
      final captions = <String, String>{
        for (final block in blocksBySlotId[slot.id] ?? const <OcptShootingDayBlock>[])
          block.id: block.kind == OcptShootingBlockKind.shot
              ? (block.shotId == null ? null : plan.shotById(block.shotId!))?.code ??
                    ocptScheduleEmptyValue
              : ocptScheduleBlockCaptionOf(
                  block: block,
                  headingBySceneId: headingBySceneId,
                  roleById: plan.roleById,
                  roleCandidateById: plan.roleCandidateById,
                  blockKindLabelOf: labels.blockKindLabelOf,
                ),
      };
      columns.add(
        OcptShootingDayAgendaColumnInput(
          slotId: slot.id,
          label: slot.label,
          timeline: timeline,
          captionByBlockId: captions,
        ),
      );
    }

    final events = [
      for (final event in plan.schedule.eventsByDayId[dayId] ?? const <OcptShootingDayEvent>[])
        OcptShootingDayAgendaEventInput(id: event.id, minute: event.minute, label: event.label),
    ];

    return OcptShootingDayAgendaGrid.of(columns: columns, events: events);
  }

  /// One day's own ten-minute grid page: the running head, the day's own title with
  /// [OcptShootingPlanLabels.tenMinuteGridSectionTitle] appended, then the grid itself, or
  /// [OcptShootingPlanLabels.emptyDayScheduleNote] on a day with no live slot at all.
  ///
  /// **`pw.Table` cannot span a cell across rows**, so a tile whose own
  /// [OcptShootingDayAgendaTile.rowSpan] is more than 1 is drawn as one ordinary bordered cell per
  /// row, its own top and bottom border switched off on every row but its first and its last
  /// ([tenMinuteGridTileCell]) — which reads as a single merged rectangle without the package ever
  /// being asked to merge one. An [OcptShootingDayAgendaEventPlacement.inGrid] event breaks the
  /// table at its own row into two chunks with its own full-width band between them
  /// ([tenMinuteGridEventWidget]), mirroring [OcptShootingPlanDaySections.dayTimetableWidgets]'s
  /// own milestone break: `pw.Table` cannot span a *column* any more than a row, so there is no
  /// other way to print one line the whole width of the page. A tile whose own band happens to
  /// cross that break is therefore drawn as two bordered rectangles rather than one — a visual seam
  /// this reading aid accepts rather than a claim the grid cannot make. A
  /// `.beforeGrid`/`.afterGrid` event is the same band, simply printed before the first table chunk
  /// or after the last one instead of breaking one open — the grid's own bounds no longer stretch
  /// to reach it (see `OcptShootingDayAgendaGrid`'s own doc comment for why a printed page decided
  /// that differently from the schedule mode's own on-screen week grid).
  ///
  /// Every row additionally opens on a **light grey rule the whole width of the page**, carried by
  /// the row's own decoration rather than by its cells: a reader following a time across three slot
  /// columns has nothing else to line their eye up on, the hour column and the tiles being drawn
  /// several centimetres apart. It is painted in [ocptShootingPlanGridRowRuleColor] over the tiles
  /// rather than under them — `pw.BoxDecoration` draws a border in its foreground phase — and that
  /// is why the colour is lighter than [ocptShootingPlanRuleColor]: it crosses a multi-row tile
  /// without ever reading as that tile having been cut into pieces.
  static pw.MultiPage tenMinuteGridPage({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required String projectName,
    required String versionLine,
    required OcptSchedulePlanSnapshot plan,
    required String dayId,
    required Map<String, String> headingBySceneId,
  }) {
    final day = plan.schedule.daysById[dayId]!;
    final title = labels.titleOfDay(dayId);
    final grid = tenMinuteGridOf(
      labels: labels,
      plan: plan,
      dayId: dayId,
      headingBySceneId: headingBySceneId,
    );

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
          "${title.isEmpty ? "${labels.dayTagPrefix}${day.dayNumber}" : title} — "
          "${labels.tenMinuteGridSectionTitle}",
          style: pw.TextStyle(font: painter.fonts.bold, fontSize: ocptShootingPlanTitleFontSizePt),
        ),
        pw.SizedBox(height: 10),
        ...tenMinuteGridWidgets(painter: painter, labels: labels, grid: grid),
      ],
    );
  }

  /// The grid's own body: an [OcptShootingDayAgendaEventPlacement.beforeGrid] event's own band
  /// first, then one [pw.Table] per run of rows uninterrupted by an `.inGrid` one — a header row
  /// (the slot labels) leading every one of them so a page reached after a break still says which
  /// column is which slot — then every `.afterGrid` event's own band last, or
  /// [OcptShootingPlanLabels.emptyDayScheduleNote] while [grid] is empty.
  static List<pw.Widget> tenMinuteGridWidgets({
    required OcptScriptPagePainter painter,
    required OcptShootingPlanLabels labels,
    required OcptShootingDayAgendaGrid grid,
  }) {
    if (grid.isEmpty) {
      return [
        OcptShootingPlanPageParts.noteWidget(painter: painter, text: labels.emptyDayScheduleNote),
      ];
    }

    final tileAtRowByColumn = <String, List<OcptShootingDayAgendaTile?>>{
      for (final column in grid.columns)
        column.slotId: List<OcptShootingDayAgendaTile?>.filled(grid.rowCount, null),
    };
    for (final tile in grid.tiles) {
      final rows = tileAtRowByColumn[tile.slotId];
      if (rows == null) {
        continue;
      }
      for (
        var row = tile.startRow;
        row < tile.startRow + tile.rowSpan && row < grid.rowCount;
        row++
      ) {
        rows[row] = tile;
      }
    }

    final leadingMarkers = <OcptShootingDayAgendaEventMarker>[];
    final trailingMarkers = <OcptShootingDayAgendaEventMarker>[];
    final eventsByRow = <int, List<OcptShootingDayAgendaEventMarker>>{};
    for (final marker in grid.events) {
      switch (marker.placement) {
        case OcptShootingDayAgendaEventPlacement.beforeGrid:
          leadingMarkers.add(marker);
        case OcptShootingDayAgendaEventPlacement.afterGrid:
          trailingMarkers.add(marker);
        case OcptShootingDayAgendaEventPlacement.inGrid:
          (eventsByRow[marker.row!] ??= <OcptShootingDayAgendaEventMarker>[]).add(marker);
      }
    }

    final columnWidths = <int, pw.TableColumnWidth>{0: const pw.FlexColumnWidth(0.8)};
    for (var index = 0; index < grid.columns.length; index++) {
      columnWidths[index + 1] = const pw.FlexColumnWidth();
    }

    final widgets = <pw.Widget>[
      for (final marker in leadingMarkers)
        tenMinuteGridEventWidget(painter: painter, marker: marker),
    ];
    var pendingRows = <pw.TableRow>[];

    void flush() {
      if (pendingRows.isEmpty) {
        return;
      }
      widgets.add(
        pw.Table(
          columnWidths: columnWidths,
          children: [
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: ocptShootingPlanBandColor),
              children: [
                OcptShootingPlanGridSections.gridCornerCell(painter: painter),
                for (final column in grid.columns)
                  OcptShootingPlanGridSections.gridHeaderCell(
                    painter: painter,
                    text: column.label.trim().isEmpty
                        ? ocptScheduleEmptyValue
                        : column.label.trim(),
                  ),
              ],
            ),
            ...pendingRows,
          ],
        ),
      );
      pendingRows = <pw.TableRow>[];
    }

    for (var row = 0; row < grid.rowCount; row++) {
      pendingRows.add(
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: ocptShootingPlanGridRowRuleColor, width: 0.3),
            ),
          ),
          children: [
            tenMinuteGridHourCell(
              painter: painter,
              minute: grid.startMinute + row * OcptShootingDayAgendaGrid.stepMinutes,
            ),
            for (final column in grid.columns)
              tenMinuteGridTileCell(
                painter: painter,
                tile: tileAtRowByColumn[column.slotId]![row],
                row: row,
              ),
          ],
        ),
      );

      final events = eventsByRow[row];
      if (events == null) {
        continue;
      }
      flush();
      for (final marker in events) {
        widgets.add(tenMinuteGridEventWidget(painter: painter, marker: marker));
      }
    }
    flush();

    for (final marker in trailingMarkers) {
      widgets.add(tenMinuteGridEventWidget(painter: painter, marker: marker));
    }

    return widgets;
  }

  /// The grid's own leading column cell: [minute] formatted through `ocptFormatDayMinute`, printed
  /// on every row — the same figure the tile cells inside that row's own band read their exact
  /// clock from, but rounded to this row's own ten-minute mark rather than a block's own exact one.
  static pw.Widget tenMinuteGridHourCell({
    required OcptScriptPagePainter painter,
    required int minute,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(ocptShootingPlanCellPaddingPt),
    child: pw.Text(
      ocptFormatDayMinute(minute),
      style: pw.TextStyle(
        font: painter.fonts.regular,
        fontSize: ocptShootingPlanSmallFontSizePt,
        color: ocptShootingPlanMutedColor,
      ),
    ),
  );

  /// One slot column's own cell for [row]: a blank, borderless space while [tile] is null (that
  /// slot has nothing placed on this row — a gap between two blocks, or a row before the slot's own
  /// call), otherwise a bordered rectangle carrying [tile]'s own caption and exact clock on its
  /// first row alone, its top and bottom border switched on only where [row] is that tile's own
  /// first or last row respectively — see [tenMinuteGridPage]'s own doc comment for why.
  static pw.Widget tenMinuteGridTileCell({
    required OcptScriptPagePainter painter,
    required OcptShootingDayAgendaTile? tile,
    required int row,
  }) {
    if (tile == null) {
      return pw.Padding(
        padding: const pw.EdgeInsets.all(ocptShootingPlanCellPaddingPt),
        child: pw.SizedBox(),
      );
    }

    final isFirstRow = row == tile.startRow;
    final isLastRow = row == tile.startRow + tile.rowSpan - 1;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: const pw.BorderSide(color: ocptShootingPlanRuleColor, width: 0.5),
          right: const pw.BorderSide(color: ocptShootingPlanRuleColor, width: 0.5),
          top: isFirstRow
              ? const pw.BorderSide(color: ocptShootingPlanRuleColor, width: 0.5)
              : pw.BorderSide.none,
          bottom: isLastRow
              ? const pw.BorderSide(color: ocptShootingPlanRuleColor, width: 0.5)
              : pw.BorderSide.none,
        ),
      ),
      padding: const pw.EdgeInsets.all(ocptShootingPlanCellPaddingPt),
      child: isFirstRow
          ? pw.Text(
              "${tile.caption} · "
              "${ocptFormatDayMinute(tile.startMinute)}–${ocptFormatDayMinute(tile.endMinute)}",
              style: pw.TextStyle(
                font: painter.fonts.regular,
                fontSize: ocptShootingPlanSmallFontSizePt,
              ),
            )
          : pw.SizedBox(),
    );
  }

  /// The grid's own full-width event marker, breaking the table it interrupts into two — mirrors
  /// [OcptShootingPlanDaySections.crewNoteBandWidget]'s own `minWidth: double.infinity` trick,
  /// `pw.Table` having no column a single widget could span instead.
  static pw.Widget tenMinuteGridEventWidget({
    required OcptScriptPagePainter painter,
    required OcptShootingDayAgendaEventMarker marker,
  }) => pw.Container(
    constraints: const pw.BoxConstraints(minWidth: double.infinity),
    margin: const pw.EdgeInsets.symmetric(vertical: 2),
    padding: const pw.EdgeInsets.all(ocptShootingPlanCellPaddingPt),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: ocptShootingPlanRuleColor, width: 0.5),
      color: ocptShootingPlanBandColor,
    ),
    child: pw.Text(
      "${ocptFormatDayMinute(marker.minute)} — "
      "${marker.label.trim().isEmpty ? ocptScheduleEmptyValue : marker.label.trim()}",
      style: pw.TextStyle(font: painter.fonts.bold, fontSize: ocptShootingPlanBodyFontSizePt),
    ),
  );
}

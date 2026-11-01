// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_grid_column.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_grid_row.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_grids.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_plan_labels.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The font size, in points, of a page's own big title (a day's own heading, a grid's own title).
const double ocptShootingPlanTitleFontSizePt = 16;

/// The font size, in points, of the title page's own document name.
const double ocptShootingPlanCoverTitleFontSizePt = 24;

/// The font size, in points, of every body line: a section's own note, a table cell.
const double ocptShootingPlanBodyFontSizePt = 9;

/// The font size, in points, of the small muted lines: the running head, a section title, a grid's
/// own column headers.
const double ocptShootingPlanSmallFontSizePt = 7;

/// The padding, in points, inside one cell of a table or a grid.
const double ocptShootingPlanCellPaddingPt = 4;

/// The colour of the rules a table's and a grid's own borders are drawn with.
const PdfColor ocptShootingPlanRuleColor = PdfColor.fromInt(0xFFB0B0B0);

/// The background colour of a table's header row and of a grid's own header band.
const PdfColor ocptShootingPlanBandColor = PdfColor.fromInt(0xFFEDEDED);

/// The colour of the ten-minute grid's own horizontal rule, one per row, lighter than
/// [ocptShootingPlanRuleColor] so it reads as a reading aid behind the tiles rather than as a
/// border of its own.
const PdfColor ocptShootingPlanGridRowRuleColor = PdfColor.fromInt(0xFFDCDCDC);

/// The grey the running head and every muted label is printed in.
const PdfColor ocptShootingPlanMutedColor = PdfColor.fromInt(0xFF6E6E6E);

/// How many columns one page of a summary grid holds before the rest carries on, chunked, onto the
/// next one — a slot column for three of the four grids, a day column for the elements one — a grid
/// silently printing only its first few days is worse than one that runs on.
const int ocptShootingPlanMaxGridColumnsPerPage = 6;

/// A shot table's `Hours / Plan / Valeur de plan / Move. / Cadre / Commentaire / Perso.` columns —
/// see [OcptShootingPlanLabels.framingHeader]'s own doc comment for why the reference document's
/// own `Description` column has no counterpart here, and [OcptShootingPlanLabels.hoursHeader]'s own
/// for why the reference document's `Hours` column, absent there, leads this one.
const Map<int, pw.TableColumnWidth> ocptShootingPlanShotColumnWidths = {
  0: pw.FlexColumnWidth(1.6),
  1: pw.FlexColumnWidth(),
  2: pw.FlexColumnWidth(1.6),
  3: pw.FlexColumnWidth(1.4),
  4: pw.FlexColumnWidth(1.8),
  5: pw.FlexColumnWidth(2.4),
  6: pw.FlexColumnWidth(1.6),
};

/// A day agenda's own trailing guest table's `NOM / MOTIF / HORAIRES` columns — the same shape
/// `OcptCallSheetPdfService`'s own `ocptShootingPlanGuestColumnWidths` already gives a day's
/// guests, wider on the reason column than the name and hours ones since a guest's own reason is
/// prose.
const Map<int, pw.TableColumnWidth> ocptShootingPlanGuestColumnWidths = {
  0: pw.FlexColumnWidth(1.6),
  1: pw.FlexColumnWidth(2.4),
  2: pw.FlexColumnWidth(1.2),
};

/// [columns] split into chunks of at most [chunkSize], in order — empty when [columns] itself is.
/// Generic over the column's own type so every summary grid paginates by the very same rule: a slot
/// column ([OcptShootingPlanGridColumn]) for the locations, sequences and crew-and-cast grids, a
/// day column ([OcptShootingDay]) for the elements one — [ocptShootingPlanMaxGridColumnsPerPage]
/// never meaning two different things depending on which grid asks. A chunk's own start offset into
/// [columns] (`chunkIndex * chunkSize`, contiguous by construction) is what every caller reads a
/// row's own cells at,
/// [OcptShootingPlanGridRow.cells]/[OcptShootingPlanElementsGridElementRow.cells] being resolved
/// against the **whole**, unchunked column list rather than against one page's own slice.
List<List<T>> ocptShootingPlanChunkColumns<T>(List<T> columns, int chunkSize) {
  if (columns.isEmpty) {
    return const [];
  }

  final chunks = <List<T>>[];
  for (var start = 0; start < columns.length; start += chunkSize) {
    final end = start + chunkSize < columns.length ? start + chunkSize : columns.length;
    chunks.add(columns.sublist(start, end));
  }
  return chunks;
}

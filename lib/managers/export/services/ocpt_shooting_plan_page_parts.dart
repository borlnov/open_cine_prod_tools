// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_grid_sections.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shooting_plan_style.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The small parts every page of the shooting plan shares: the running head, the note and text
/// cells, and the portrait and landscape page formats.
///
/// Stateless widget builders over a page painter.
abstract final class OcptShootingPlanPageParts {
  // ---------------------------------------------------------------------------------------------
  // Small shared drawing helpers
  // ---------------------------------------------------------------------------------------------

  /// Build the running head naming the project and the document on the left, [versionLine] on the
  /// right,
  /// over a thin rule — the same shape `OcptCallSheetPdfService._page` draws inline, factored out
  /// here since every page kind of this service (title, grid, day agenda, note) opens with it.
  ///
  /// The version line is repeated on **every** page rather than on the title page alone: a shooting
  /// plan is read page by page, a day agenda torn out of it or a landscape grid pinned on a wall,
  /// and a reader holding one sheet of it has nowhere else to find out which issue they are working
  /// from. Every call site hands this to its own `pw.MultiPage`'s **`header:`** callback rather
  /// than as the first entry of its `build:` list: `build:` only ever runs once, on the first
  /// physical page a flow lands on, while `header:` runs on every one it overflows onto — a busy
  /// day agenda or a wide grid chunked across several sheets would otherwise carry this on its
  /// first page alone and nothing on the rest, which is exactly the failure this doc comment's own
  /// promise rules out.
  static pw.Widget runningHead({
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
            style: pw.TextStyle(
              font: painter.fonts.regular,
              fontSize: ocptShootingPlanSmallFontSizePt,
              color: ocptShootingPlanMutedColor,
            ),
          ),
          pw.Text(
            versionLine,
            style: pw.TextStyle(
              font: painter.fonts.regular,
              fontSize: ocptShootingPlanSmallFontSizePt,
              color: ocptShootingPlanMutedColor,
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 2),
      pw.Divider(color: ocptShootingPlanRuleColor, thickness: 0.5, height: 6),
      pw.SizedBox(height: 6),
    ],
  );

  /// Build a block of free text.
  static pw.Widget noteWidget({required OcptScriptPagePainter painter, required String text}) =>
      pw.Text(
        text,
        style: pw.TextStyle(font: painter.fonts.regular, fontSize: ocptShootingPlanBodyFontSizePt),
      );

  /// Build one table cell holding [text], substituting [ocptScheduleEmptyValue] when it is blank —
  /// unlike
  /// [OcptShootingPlanGridSections.gridDataCell], a shot table cell always names a specific field
  /// of a specific shot, so a blank one *is* a missing value.
  static pw.Widget textCell({
    required OcptScriptPagePainter painter,
    required String text,
    bool isBold = false,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(ocptShootingPlanCellPaddingPt),
    child: pw.Text(
      text.isEmpty ? ocptScheduleEmptyValue : text,
      style: pw.TextStyle(
        font: painter.fonts.variant(bold: isBold, italic: false),
        fontSize: ocptShootingPlanBodyFontSizePt,
      ),
    ),
  );

  /// Get the portrait `pdf` page format every title page, note page and day agenda is drawn on —
  /// the
  /// same margin convention `OcptCallSheetPdfService._page` uses (`marginRightPt` standing in for
  /// the bottom margin too, [OcptScriptPagePainter] having none of its own).
  static PdfPageFormat portraitPageFormat(OcptScriptPagePainter painter) => PdfPageFormat(
    painter.pageWidthPt,
    painter.pageHeightPt,
    marginLeft: painter.marginRightPt,
    marginTop: painter.marginTopPt,
    marginRight: painter.marginRightPt,
    marginBottom: painter.marginRightPt,
  );

  /// Get the landscape `pdf` page format every summary grid page is drawn on — [painter]'s own
  /// width
  /// and height swapped, its margins otherwise read the same way [portraitPageFormat] does.
  static PdfPageFormat landscapePageFormat(OcptScriptPagePainter painter) => PdfPageFormat(
    painter.pageHeightPt,
    painter.pageWidthPt,
    marginLeft: painter.marginRightPt,
    marginTop: painter.marginTopPt,
    marginRight: painter.marginRightPt,
    marginBottom: painter.marginRightPt,
  );
}

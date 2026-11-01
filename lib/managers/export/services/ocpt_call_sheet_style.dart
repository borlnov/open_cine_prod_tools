// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The font size, in points, of a sheet's own big day title (`FEUILLE DE SERVICE DU …`).
const double ocptCallSheetTitleFontSizePt = 16;

/// The font size, in points, of every body line of a sheet: a band line, a table cell, a note.
const double ocptCallSheetBodyFontSizePt = 9;

/// The font size, in points, of the small muted lines: the running head, a section title, a
/// department heading.
const double ocptCallSheetSmallFontSizePt = 7;

/// The padding, in points, inside one cell of a sheet's table and inside a milestone band.
const double ocptCallSheetCellPaddingPt = 4;

/// The most department columns `OcptCallSheetHeaderSections.contactsBlock` ever lays out in one
/// `pw.Row`, wrapping onto a further row rather than squeezing a ninth column onto the first.
const int ocptCallSheetContactsColumnsPerRow = 4;

/// The colour of the rules a sheet's tables and bands are drawn with.
const PdfColor ocptCallSheetRuleColor = PdfColor.fromInt(0xFFB0B0B0);

/// The background colour of a table's header row and of a milestone band.
const PdfColor ocptCallSheetBandColor = PdfColor.fromInt(0xFFEDEDED);

/// The grey the running head and every muted label is printed in.
const PdfColor ocptCallSheetMutedColor = PdfColor.fromInt(0xFF6E6E6E);

/// The main table's `SEQ / PLANS / EFFET / DÉCORS / RÔLES` columns.
///
/// The reference call sheet carries a sixth, `RÉSUMÉ`, between `DÉCORS` and `RÔLES`, and this table
/// deliberately does not: no field of this app answers "what happens in this sequence" — the
/// screenplay says it in prose, `shots.notes` is the directing notes and means something else — so
/// the column could only ever have printed an em dash on every row of the production's central
/// document. A heading that promises something it never delivers is worse than one column fewer.
const Map<int, pw.TableColumnWidth> ocptCallSheetMainColumnWidths = {
  0: pw.FlexColumnWidth(),
  1: pw.FlexColumnWidth(1.4),
  2: pw.FlexColumnWidth(1.2),
  3: pw.FlexColumnWidth(1.8),
  4: pw.FlexColumnWidth(1.4),
};

/// The cast table's `RÔLE / COMÉDIEN / SEQ / ARRIVÉE / PAT` columns.
const Map<int, pw.TableColumnWidth> ocptCallSheetCastColumnWidths = {
  0: pw.FlexColumnWidth(1.6),
  1: pw.FlexColumnWidth(1.8),
  2: pw.FlexColumnWidth(),
  3: pw.FlexColumnWidth(),
  4: pw.FlexColumnWidth(1.2),
};

/// The crew list's and the cast-and-extras list's shared `NOM / POSTE(S) / TEL. / MAIL / HORAIRES`
/// columns.
const Map<int, pw.TableColumnWidth> ocptCallSheetPeopleColumnWidths = {
  0: pw.FlexColumnWidth(1.6),
  1: pw.FlexColumnWidth(1.8),
  2: pw.FlexColumnWidth(1.2),
  3: pw.FlexColumnWidth(1.8),
  4: pw.FlexColumnWidth(1.4),
};

/// The audition table's `HORAIRES / RÔLE / CANDIDAT` columns — three, the third one arriving with
/// the link that can fill it: an audition block names the **candidacies** it sees (ADR 0024), so it
/// knows both who is expected and at what hour, which is exactly what this table is read for. No
/// phone number among them: this is a reading of the timetable, and a contact belongs in the day's
/// own candidates directory beside everybody else's.
const Map<int, pw.TableColumnWidth> ocptCallSheetAuditionColumnWidths = {
  0: pw.FlexColumnWidth(1.2),
  1: pw.FlexColumnWidth(1.8),
  2: pw.FlexColumnWidth(1.8),
};

/// The trailing guest table's `NOM / MOTIF / HORAIRES` columns — wider on the reason column than
/// [ocptCallSheetPeopleColumnWidths]' own `POSTE(S)` since a guest's own reason is prose rather
/// than a job title, and with no phone/email pair to make room for.
const Map<int, pw.TableColumnWidth> ocptCallSheetGuestColumnWidths = {
  0: pw.FlexColumnWidth(1.6),
  1: pw.FlexColumnWidth(2.4),
  2: pw.FlexColumnWidth(1.2),
};

/// A named sheet's own "to bring" table's `NOM / SEQ` columns — the same two headers the main table
/// and the cast table already carry, wider on the name column since `<code> · <name>` runs longer
/// than a shot's own `SEQ` figure.
const Map<int, pw.TableColumnWidth> ocptCallSheetToBringColumnWidths = {
  0: pw.FlexColumnWidth(2.4),
  1: pw.FlexColumnWidth(1.2),
};

/// Every accented letter (upper- and lower-case) this app's own two UI languages can put in a
/// person's name, folded to the plain Latin letter a file name can safely hold.
///
/// A small, deliberately duplicated subset of `ocpt_resources_search.dart`'s own folding map: that
/// one always lower-cases its result (it exists for case-insensitive search), while a file name
/// should keep the name's own casing (`Élisa` → `Elisa`, not `elisa`) — the two could not share one
/// function without one of them losing what it needs.
const Map<String, String> ocptCallSheetFileNameDiacriticsFold = {
  "à": "a",
  "â": "a",
  "ä": "a",
  "á": "a",
  "ã": "a",
  "å": "a",
  "ç": "c",
  "é": "e",
  "è": "e",
  "ê": "e",
  "ë": "e",
  "í": "i",
  "ì": "i",
  "î": "i",
  "ï": "i",
  "ñ": "n",
  "ó": "o",
  "ò": "o",
  "ô": "o",
  "ö": "o",
  "õ": "o",
  "ú": "u",
  "ù": "u",
  "û": "u",
  "ü": "u",
  "ý": "y",
  "ÿ": "y",
  "œ": "oe",
  "æ": "ae",
};

/// The characters a file name may not hold on any platform this app targets, dropped in
/// [ocptCallSheetSafeFileNamePart]: both path separator conventions, control characters, and the
/// handful of characters Windows refuses in a file name.
final RegExp ocptCallSheetUnsafeFileNameChars = RegExp(r'[\\/:*?"<>|\x00-\x1F]');

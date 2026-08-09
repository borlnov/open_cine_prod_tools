// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/constants/ocpt_crew_positions.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:open_cine_prod_tools/types/ocpt_shooting_block_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_day_minute.dart';
import 'package:open_cine_prod_tools/utils/ocpt_scene_effect.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_convocations.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shooting_day_timeline.dart';
import 'package:open_cine_prod_tools/utils/ocpt_shot_code.dart';
import 'package:open_cine_prod_tools/utils/ocpt_sun_times.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The font size, in points, of a sheet's own big day title (`FEUILLE DE SERVICE DU …`).
const double _titleFontSizePt = 16;

/// The font size, in points, of every body line of a sheet: a band line, a table cell, a note.
const double _bodyFontSizePt = 9;

/// The font size, in points, of the small muted lines: the running head, a section title, a
/// department heading.
const double _smallFontSizePt = 7;

/// The padding, in points, inside one cell of a sheet's table and inside a milestone band.
const double _cellPaddingPt = 4;

/// The colour of the rules a sheet's tables and bands are drawn with.
const PdfColor _ruleColor = PdfColor.fromInt(0xFFB0B0B0);

/// The background colour of a table's header row and of a milestone band.
const PdfColor _bandColor = PdfColor.fromInt(0xFFEDEDED);

/// The grey the running head and every muted label is printed in.
const PdfColor _mutedColor = PdfColor.fromInt(0xFF6E6E6E);

/// The main table's `SEQ / PLANS / EFFET / DÉCORS / RÔLES` columns.
///
/// The reference call sheet carries a sixth, `RÉSUMÉ`, between `DÉCORS` and `RÔLES`, and this table
/// deliberately does not: no field of this app answers "what happens in this sequence" — the
/// screenplay says it in prose, `shots.notes` is the directing notes and means something else — so
/// the column could only ever have printed an em dash on every row of the production's central
/// document. A heading that promises something it never delivers is worse than one column fewer.
const Map<int, pw.TableColumnWidth> _mainColumnWidths = {
  0: pw.FlexColumnWidth(),
  1: pw.FlexColumnWidth(1.4),
  2: pw.FlexColumnWidth(1.2),
  3: pw.FlexColumnWidth(1.8),
  4: pw.FlexColumnWidth(1.4),
};

/// The cast table's `RÔLE / COMÉDIEN / SEQ / ARRIVÉE / PAT` columns.
const Map<int, pw.TableColumnWidth> _castColumnWidths = {
  0: pw.FlexColumnWidth(1.6),
  1: pw.FlexColumnWidth(1.8),
  2: pw.FlexColumnWidth(),
  3: pw.FlexColumnWidth(),
  4: pw.FlexColumnWidth(1.2),
};

/// The crew list's and the cast-and-extras list's shared `NOM / POSTE(S) / TEL. / MAIL / HORAIRES`
/// columns.
const Map<int, pw.TableColumnWidth> _peopleColumnWidths = {
  0: pw.FlexColumnWidth(1.6),
  1: pw.FlexColumnWidth(1.8),
  2: pw.FlexColumnWidth(1.2),
  3: pw.FlexColumnWidth(1.8),
  4: pw.FlexColumnWidth(1.4),
};

/// The trailing guest table's `NOM / MOTIF / HORAIRES` columns — wider on the reason column than
/// [_peopleColumnWidths]' own `POSTE(S)` since a guest's own reason is prose rather than a job
/// title, and with no phone/email pair to make room for.
const Map<int, pw.TableColumnWidth> _guestColumnWidths = {
  0: pw.FlexColumnWidth(1.6),
  1: pw.FlexColumnWidth(2.4),
  2: pw.FlexColumnWidth(1.2),
};

/// A named sheet's own "to bring" table's `NOM / SEQ` columns — the same two headers the main table
/// and the cast table already carry, wider on the name column since `<code> · <name>` runs longer
/// than a shot's own `SEQ` figure.
const Map<int, pw.TableColumnWidth> _toBringColumnWidths = {
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
const Map<String, String> _fileNameDiacriticsFold = {
  "à": "a", "â": "a", "ä": "a", "á": "a", "ã": "a", "å": "a",
  "ç": "c",
  "é": "e", "è": "e", "ê": "e", "ë": "e",
  "í": "i", "ì": "i", "î": "i", "ï": "i",
  "ñ": "n",
  "ó": "o", "ò": "o", "ô": "o", "ö": "o", "õ": "o",
  "ú": "u", "ù": "u", "û": "u", "ü": "u",
  "ý": "y", "ÿ": "y",
  "œ": "oe", "æ": "ae",
};

/// The characters a file name may not hold on any platform this app targets, dropped in
/// [_safeFileNamePart]: both path separator conventions, control characters, and the handful of
/// characters Windows refuses in a file name.
final RegExp _unsafeFileNameChars = RegExp(r'[\\/:*?"<>|\x00-\x1F]');

/// Renders a shooting day's call sheet — the general one, following the reference `.docx` section by
/// section, and the named one, one per convoked person or uncast role.
///
/// This is pure rendering logic with no dialog or file-system access of its own: it's owned by
/// `OcptExportManager` and exposed as a public final field, reached through the manager rather than
/// through `globalGetIt()` (RFL18), exactly like its siblings. It prints no screenplay, so — like
/// `OcptBreakdownSheetsPdfService` — it draws nothing through [OcptScriptPagePainter]'s absolutely
/// positioned page builders and flows its content in a [pw.MultiPage] instead; it still takes one
/// painter, for the page geometry every export of this app measures a sheet with and the Courier
/// Prime variants all four of them print in.
///
/// **One composition, two audiences**: every section a general and a named sheet share
/// (the title block, the day heading, the crew note, the day's own events, the location(s), the sun
/// block, the key contacts, the main table, the cast table, the two closing directories and the
/// trailing guest table) is built by one shared private widget builder, called from both
/// [generateGeneralCallSheet] and [generateNamedCallSheet] rather than duplicated between them. Only
/// **three** sections belong to one sheet alone, none of them with a counterpart to share: a named
/// sheet's own recipient line, its own arrival/PAT/departure band, and its own "to bring" section
/// ([_toBringSection]) — the elements [OcptSchedulePlanSnapshot.elementsToBringOnDay] joins onto
/// that one recipient. The general sheet has no reading for it at all, deliberately: what to bring
/// is a fact about **one** recipient, while the general sheet is the day's own paperwork, addressed
/// to nobody in particular — printing it there would mean printing every recipient's own list on
/// everybody else's sheet, or guessing which one the reader is.
///
/// **What a named sheet narrows is the timetable, and only the timetable.** Its main table holds the
/// blocks of its recipient's own slots, since that is what they are being told to turn up for; the
/// cast table and the two closing directories are day-wide on both sheets, because they answer "who
/// else is on this day and how do I reach them", which is a question about the day rather than about
/// the reader — and a crew that cannot phone each other on the morning of a shoot is a crew that
/// stops. The cast table is day-wide in a second sense too: it lists every role the day **calls
/// for**, including the ones a placed shot plays that nobody convoked, so a role number printed in
/// the main table's own `RÔLES` column can always be looked up on the same sheet
/// ([_castRowsOfDay]). The day's own events and its guests are day-wide for the same reason: an
/// event is a fact about the day rather than about a unit, and a guest is owed an hour whichever
/// slot happens to convoke the sheet's own recipient.
///
/// **A block's own [OcptShootingDayBlock.crewNote] prints under its own row**, unlike its private
/// `notes`, which never leaves the office — see [_mainTableSection] for how a `pw.Table` row, which
/// cannot itself span the page, still ends up with a full-width note directly beneath it.
///
/// **Every hour printed comes off [OcptSchedulePlanSnapshot.timelinesOfDay]'s resolved clocks and
/// [OcptSchedulePlanSnapshot.convocationsOfDay]'s computed figures** — never off a stored anchor,
/// never re-derived, never offset by anything. A minute may exceed 1440 for a night shoot's small
/// hours, and every figure is printed through `ocptFormatDayMinute`, the one place that ever wraps
/// one back onto a clock face.
///
/// **A sheet that runs long says on every page what it is**: the running head is drawn through
/// [pw.MultiPage]'s own `header:` ([_page]) and every table here marks its header row
/// `repeat: true`, so a second page carries the project's name and knows which column is `ARRIVÉE`
/// rather than handing somebody five anonymous columns. `OcptShootingPlanPdfService` states the
/// same two rules for the same reason — a printed page is read on its own, and the sheet it was
/// stapled to is regularly not in the reader's hand.
class OcptCallSheetPdfService {
  /// Creates an [OcptCallSheetPdfService].
  ///
  /// Pass the manager's own [fontsLoader] so every export of the app session shares one font cache;
  /// a service built without one gets a loader of its own.
  OcptCallSheetPdfService({OcptCourierPrimeFontsLoader? fontsLoader})
    : fontsLoader = fontsLoader ?? OcptCourierPrimeFontsLoader();

  /// The loader the embedded Courier Prime font set is read through.
  final OcptCourierPrimeFontsLoader fontsLoader;

  /// The `.pdf` file name of the general call sheet of day [dayNumber] (`FDS-J2.pdf`).
  String callSheetFileName({required OcptCallSheetLabels labels, required int dayNumber}) =>
      "${labels.fileNamePrefix}-${labels.dayTagPrefix}$dayNumber.pdf";

  /// The `.pdf` file name of the named call sheet of day [dayNumber] for [personName]
  /// (`FDS-J2-Elisa-Mabit.pdf`).
  ///
  /// [personName] is sanitized through [_safeFileNamePart] — diacritics folded, unsafe characters
  /// dropped, whitespace turned into dashes — and a name that sanitizes down to nothing (blank, or
  /// made entirely of characters a file name cannot hold) falls back to [OcptCallSheetLabels
  /// .unnamedPersonLabel], sanitized the same way, so the file still gets a stable, readable name
  /// rather than none at all.
  String namedCallSheetFileName({
    required OcptCallSheetLabels labels,
    required int dayNumber,
    required String personName,
  }) {
    final base = "${labels.fileNamePrefix}-${labels.dayTagPrefix}$dayNumber";
    final safeName = _safeFileNamePart(personName);
    final suffix = safeName.isEmpty ? _safeFileNamePart(labels.unnamedPersonLabel) : safeName;
    return suffix.isEmpty ? "$base.pdf" : "$base-$suffix.pdf";
  }

  /// Renders the general call sheet of [dayId]: the whole day's own paperwork, following the
  /// reference `.docx` section by section (§A of the reference note this service was built against).
  ///
  /// [exportDate] is the moment the title block's own version line prints, through
  /// [ocptScheduleGeneratedAtStamp] — the very stamp `OcptShootingPlanPdfService` prints, so two
  /// documents of one shoot cannot name their issue differently. It defaults to the moment this
  /// method runs and is exposed so a test can pin it rather than racing a minute rollover; a caller
  /// writing a folder full of sheets in one run resolves it **once** and hands the same moment to
  /// every one of them, a batch that stamped itself sheet by sheet reading as several issues.
  Future<Uint8List> generateGeneralCallSheet({
    required OcptSchedulePlanSnapshot plan,
    required String dayId,
    required OcptPageSetup pageSetup,
    required OcptCallSheetLabels labels,
    required String projectName,
    DateTime? exportDate,
  }) async {
    final painter = await _painterFor(pageSetup);
    final versionLine = "${labels.versionLabel} ${ocptScheduleGeneratedAtStamp(exportDate ?? DateTime.now())}";
    final day = plan.schedule.daysById[dayId];
    final pdfDocument = pw.Document();

    if (day == null) {
      pdfDocument.addPage(
        _page(
          painter: painter,
          labels: labels,
          projectName: projectName,
          children: [_noteWidget(painter: painter, text: labels.emptyDayNote)],
        ),
      );
      return pdfDocument.save();
    }

    final slots = plan.schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
    final timelines = plan.timelinesOfDay(dayId);
    final convocations = plan.convocationsOfDay(dayId);
    final headingBySceneId = ocptScheduleHeadingBySceneId(plan);
    final orderedEntries = ocptOrderedScheduleEntriesOfDay(plan: plan, dayId: dayId);
    final rows = _buildDayRows(
      plan: plan,
      orderedEntries: orderedEntries,
      headingBySceneId: headingBySceneId,
      labels: labels,
    );
    final castRows = _castRowsOfDay(plan: plan, dayId: dayId, orderedEntries: orderedEntries);
    final crewContacts = _crewContactsOfDay(plan: plan, dayId: dayId, labels: labels);
    final locations = ocptScheduleLocationsOfSlots(plan, slots);
    final events = plan.schedule.eventsByDayId[dayId] ?? const <OcptShootingDayEvent>[];
    final guestRows = ocptScheduleGuestRowsOfDay(
      plan: plan,
      dayId: dayId,
      unnamedPersonLabel: labels.unnamedPersonLabel,
    );

    pdfDocument.addPage(
      _page(
        painter: painter,
        labels: labels,
        projectName: projectName,
        children: [
          _recipientsSection(painter: painter, labels: labels, convocations: convocations, plan: plan),
          pw.SizedBox(height: 10),
          ..._sharedSections(
            painter: painter,
            labels: labels,
            projectName: projectName,
            versionLine: versionLine,
            day: day,
            slots: slots,
            timelines: timelines,
            convocations: convocations,
            orderedEntries: orderedEntries,
            rows: rows,
            crewContacts: crewContacts,
            contactDepartments: const {OcptCrewDepartment.production, OcptCrewDepartment.direction},
            locations: locations,
            events: events,
            plan: plan,
          ),
          pw.SizedBox(height: 10),
          _contactsBlock(
            painter: painter,
            labels: labels,
            crewContacts: crewContacts,
            departments: const {
              OcptCrewDepartment.image,
              OcptCrewDepartment.sound,
              OcptCrewDepartment.artDepartment,
              OcptCrewDepartment.hmc,
            },
          ),
          pw.SizedBox(height: 10),
          _mainTableSection(painter: painter, labels: labels, rows: rows, roles: plan.roles),
          pw.SizedBox(height: 10),
          _castTableSection(painter: painter, labels: labels, rows: castRows),
          pw.SizedBox(height: 10),
          _peopleListSection(
            painter: painter,
            labels: labels,
            title: labels.crewListSectionTitle,
            entries: _crewListEntries(crewContacts: crewContacts, convocations: convocations),
          ),
          pw.SizedBox(height: 10),
          _peopleListSection(
            painter: painter,
            labels: labels,
            title: labels.castAndExtrasListSectionTitle,
            entries: _castListEntries(castRows: castRows, labels: labels),
          ),
          if (guestRows.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _guestsSection(painter: painter, labels: labels, rows: guestRows),
          ],
        ],
      ),
    );

    return pdfDocument.save();
  }

  /// Renders the named call sheet of [convocation] on [dayId]: the same day header, their own
  /// arrival/PAT/departure band, their own "to bring" section, the crew note, the day's own events,
  /// the location(s) and blocks of their own slots alone, the sun block, the key contacts — then the
  /// day's own cast table, crew list, cast-and-extras list and trailing guest table, exactly as the
  /// general sheet prints them. Only the main table is narrowed to the recipient's slots; see the
  /// class doc comment for why the other day-wide sections are not.
  ///
  /// The "to bring" section is printed only for a recipient this app can name a person for
  /// ([OcptDayConvocation.personId]) — an uncast role has nobody to bring anything, so the section is
  /// absent altogether rather than a heading over an em dash — and only when
  /// [OcptSchedulePlanSnapshot.elementsToBringOnDay] actually joins something, exactly as
  /// [_crewNoteSection] and [_eventsSection] are already skipped rather than drawn empty (their own
  /// doc comments).
  ///
  /// [exportDate] carries the same contract it does on [generateGeneralCallSheet] — see there.
  Future<Uint8List> generateNamedCallSheet({
    required OcptSchedulePlanSnapshot plan,
    required String dayId,
    required OcptPageSetup pageSetup,
    required OcptCallSheetLabels labels,
    required String projectName,
    required OcptDayConvocation convocation,
    DateTime? exportDate,
  }) async {
    final painter = await _painterFor(pageSetup);
    final versionLine = "${labels.versionLabel} ${ocptScheduleGeneratedAtStamp(exportDate ?? DateTime.now())}";
    final day = plan.schedule.daysById[dayId];
    final pdfDocument = pw.Document();

    if (day == null) {
      pdfDocument.addPage(
        _page(
          painter: painter,
          labels: labels,
          projectName: projectName,
          children: [_noteWidget(painter: painter, text: labels.emptyDayNote)],
        ),
      );
      return pdfDocument.save();
    }

    final onlySlotIds = convocation.slotIds.toSet();
    final allSlots = plan.schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
    final ownSlots = [for (final slot in allSlots) if (onlySlotIds.contains(slot.id)) slot];
    final headingBySceneId = ocptScheduleHeadingBySceneId(plan);
    final orderedEntries = ocptOrderedScheduleEntriesOfDay(plan: plan, dayId: dayId, onlySlotIds: onlySlotIds);
    final rows = _buildDayRows(
      plan: plan,
      orderedEntries: orderedEntries,
      headingBySceneId: headingBySceneId,
      labels: labels,
    );
    // The day's own whole run, not the recipient's restricted one: the three closing tables are
    // facts about the **day**, and a cast row saying which sequences an actor shoots today would be
    // wrong the moment its reader is convoked on only one of the day's two units.
    final dayEntries = ocptOrderedScheduleEntriesOfDay(plan: plan, dayId: dayId);
    final convocations = plan.convocationsOfDay(dayId);
    final castRows = _castRowsOfDay(plan: plan, dayId: dayId, orderedEntries: dayEntries);
    final crewContacts = _crewContactsOfDay(plan: plan, dayId: dayId, labels: labels);
    final locations = ocptScheduleLocationsOfSlots(plan, ownSlots);
    final events = plan.schedule.eventsByDayId[dayId] ?? const <OcptShootingDayEvent>[];
    final guestRows = ocptScheduleGuestRowsOfDay(
      plan: plan,
      dayId: dayId,
      unnamedPersonLabel: labels.unnamedPersonLabel,
    );
    final displayName = _convocationDisplayNameOf(convocation, plan, labels);
    final positionsOrRole = _convocationPositionsLabel(
      convocation: convocation,
      ownSlots: ownSlots,
      plan: plan,
      labels: labels,
    );
    final recipientPersonId = convocation.personId;
    final toBringRows = recipientPersonId == null
        ? const <_ToBringRow>[]
        : _toBringRowsOfDay(plan: plan, dayId: dayId, personId: recipientPersonId, dayEntries: dayEntries);

    pdfDocument.addPage(
      _page(
        painter: painter,
        labels: labels,
        projectName: projectName,
        children: [
          _namedRecipientSection(
            painter: painter,
            labels: labels,
            displayName: displayName,
            positionsOrRole: positionsOrRole,
          ),
          pw.SizedBox(height: 10),
          _titleBlock(painter: painter, projectName: projectName, labels: labels, versionLine: versionLine),
          pw.SizedBox(height: 10),
          _dayHeadingSection(painter: painter, labels: labels, day: day),
          pw.SizedBox(height: 10),
          _ownBandSection(painter: painter, labels: labels, convocation: convocation),
          pw.SizedBox(height: 10),
          if (toBringRows.isNotEmpty) ...[
            _toBringSection(painter: painter, labels: labels, rows: toBringRows),
            pw.SizedBox(height: 10),
          ],
          if (events.isNotEmpty) ...[
            _eventsSection(painter: painter, labels: labels, events: events),
            pw.SizedBox(height: 10),
          ],
          if (day.crewNote.trim().isNotEmpty) ...[
            _crewNoteSection(painter: painter, labels: labels, note: day.crewNote),
            pw.SizedBox(height: 10),
          ],
          _locationSection(painter: painter, labels: labels, locations: locations),
          pw.SizedBox(height: 10),
          _sunSection(painter: painter, labels: labels, sunTimes: plan.sunTimesOfDay(dayId)),
          pw.SizedBox(height: 10),
          _contactsBlock(
            painter: painter,
            labels: labels,
            crewContacts: crewContacts,
            departments: const {OcptCrewDepartment.production, OcptCrewDepartment.direction},
          ),
          pw.SizedBox(height: 10),
          _mainTableSection(painter: painter, labels: labels, rows: rows, roles: plan.roles),
          pw.SizedBox(height: 10),
          _castTableSection(painter: painter, labels: labels, rows: castRows),
          pw.SizedBox(height: 10),
          _peopleListSection(
            painter: painter,
            labels: labels,
            title: labels.crewListSectionTitle,
            entries: _crewListEntries(crewContacts: crewContacts, convocations: convocations),
          ),
          pw.SizedBox(height: 10),
          _peopleListSection(
            painter: painter,
            labels: labels,
            title: labels.castAndExtrasListSectionTitle,
            entries: _castListEntries(castRows: castRows, labels: labels),
          ),
          if (guestRows.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _guestsSection(painter: painter, labels: labels, rows: guestRows),
          ],
        ],
      ),
    );

    return pdfDocument.save();
  }

  /// The sections [generateGeneralCallSheet] builds in this exact order, up to and including the sun
  /// block, over widget builders every one of which is shared with [generateNamedCallSheet] too (the
  /// title block, the day heading, the crew note, the day's own events, the location(s) and the sun
  /// block): only the *composition* differs between the two generators, called out inline at each
  /// call site, never the section builders themselves — that is what "one composition, two
  /// audiences" means in the class doc comment. The department contacts, the main table, the cast
  /// table, the two closing lists and the trailing guest table all print **after** what this method
  /// returns, since the reference call sheet's own contacts-by-department table sits between the sun
  /// block and the main table; they are added by [generateGeneralCallSheet] itself rather than
  /// folded in here, over the very same
  /// [_contactsBlock]/[_mainTableSection]/[_castTableSection]/[_peopleListSection]/[_guestsSection]
  /// builders [generateNamedCallSheet] also calls directly.
  /// [generateNamedCallSheet] does not call this method at all: its own recipient line and its own
  /// single band ([_ownBandSection], replacing the day-wide time bands this method prints) make its
  /// ordering different enough that composing it from this list would need more conditionals than
  /// just calling the same builders itself does.
  List<pw.Widget> _sharedSections({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required String projectName,
    required String versionLine,
    required OcptShootingDay day,
    required List<OcptShootingSlot> slots,
    required OcptShootingDayTimelines? timelines,
    required List<OcptDayConvocation> convocations,
    required List<OcptOrderedScheduleEntry> orderedEntries,
    required List<_DayRow> rows,
    required List<_CrewContact> crewContacts,
    required Set<OcptCrewDepartment> contactDepartments,
    required List<OcptLocation> locations,
    required List<OcptShootingDayEvent> events,
    required OcptSchedulePlanSnapshot plan,
  }) => [
    _titleBlock(painter: painter, projectName: projectName, labels: labels, versionLine: versionLine),
    pw.SizedBox(height: 10),
    _contactsBlock(painter: painter, labels: labels, crewContacts: crewContacts, departments: contactDepartments),
    pw.SizedBox(height: 10),
    _timeBandsSection(
      painter: painter,
      labels: labels,
      slots: slots,
      timelines: timelines,
      convocations: convocations,
      orderedEntries: orderedEntries,
    ),
    pw.SizedBox(height: 10),
    if (events.isNotEmpty) ...[
      _eventsSection(painter: painter, labels: labels, events: events),
      pw.SizedBox(height: 10),
    ],
    _dayHeadingSection(painter: painter, labels: labels, day: day),
    pw.SizedBox(height: 10),
    if (day.crewNote.trim().isNotEmpty) ...[
      _crewNoteSection(painter: painter, labels: labels, note: day.crewNote),
      pw.SizedBox(height: 10),
    ],
    _locationSection(painter: painter, labels: labels, locations: locations),
    pw.SizedBox(height: 10),
    _sunSection(painter: painter, labels: labels, sunTimes: plan.sunTimesOfDay(day.id)),
  ];

  /// The [OcptScriptPagePainter] every sheet is drawn through, sharing this session's font cache.
  Future<OcptScriptPagePainter> _painterFor(OcptPageSetup pageSetup) async =>
      OcptScriptPagePainter(metrics: pageSetup.toMetrics(), fonts: await fontsLoader.load());

  /// One sheet's own [pw.MultiPage], carrying the running head naming the project and the document,
  /// then [children] — the same shape `OcptBreakdownSheetsPdfService._sheetPage` uses, for the same
  /// reason: a busy day's own sheet is free to run onto a second page rather than print off the
  /// bottom of the first.
  ///
  /// The running head is handed to [pw.MultiPage]'s own `header:` rather than laid at the top of
  /// `build:`, and it matters exactly when a sheet does run long: a `build:` child is drawn **once**,
  /// where a `header:` is drawn on every physical page the flow lands on. A call sheet whose cast
  /// table and two directories push it onto a second page was handing that page over naming no
  /// project and no document at all — the same fix `OcptShootingPlanPdfService._runningHead` carries
  /// for the same reason, a sheet being read one page at a time whatever it was stapled to.
  pw.Page _page({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
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
    header: (context) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          "$projectName — ${labels.documentTitle}",
          style: pw.TextStyle(font: painter.fonts.regular, fontSize: _smallFontSizePt, color: _mutedColor),
        ),
        pw.SizedBox(height: 2),
        pw.Divider(color: _ruleColor, thickness: 0.5, height: 6),
      ],
    ),
    build: (context) => [pw.SizedBox(height: 6), ...children],
  );

  // ---------------------------------------------------------------------------------------------
  // Header sections
  // ---------------------------------------------------------------------------------------------

  /// The general sheet's own recipients line — the day's own convoked people, by first name.
  pw.Widget _recipientsSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required List<OcptDayConvocation> convocations,
    required OcptSchedulePlanSnapshot plan,
  }) {
    final names = [
      for (final convocation in convocations)
        if (convocation.personId != null) plan.personById[convocation.personId]?.firstName.trim() ?? "",
    ].where((name) => name.isNotEmpty).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(painter: painter, title: labels.recipientsSectionTitle),
        pw.SizedBox(height: 2),
        _noteWidget(painter: painter, text: names.isEmpty ? ocptScheduleEmptyValue : names.join(", ")),
      ],
    );
  }

  /// A named sheet's own header: who it is for, and the position(s) or the role they are convoked
  /// under.
  pw.Widget _namedRecipientSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required String displayName,
    required String positionsOrRole,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionTitle(painter: painter, title: labels.namedRecipientLabel),
      pw.SizedBox(height: 2),
      pw.Text(
        displayName.isEmpty ? ocptScheduleEmptyValue : displayName,
        style: pw.TextStyle(font: painter.fonts.bold, fontSize: _bodyFontSizePt),
      ),
      if (positionsOrRole.trim().isNotEmpty) ...[
        pw.SizedBox(height: 2),
        _noteWidget(painter: painter, text: "${labels.positionsHeader} : $positionsOrRole"),
      ],
    ],
  );

  /// The project's own title, then the `Un film de <director>` line when there is one, then
  /// [versionLine] — the moment this sheet was produced.
  ///
  /// The version line sits in the title block rather than in the running head, unlike the shooting
  /// plan's own: a call sheet is one sheet about one day, handed over whole, and the block naming
  /// the film is where somebody comparing two of them looks first. It is printed on the general and
  /// the named sheet alike, both being reissued as a day is re-planned.
  pw.Widget _titleBlock({
    required OcptScriptPagePainter painter,
    required String projectName,
    required OcptCallSheetLabels labels,
    required String versionLine,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(projectName, style: pw.TextStyle(font: painter.fonts.bold, fontSize: _titleFontSizePt)),
      if (labels.directorLine.trim().isNotEmpty) ...[
        pw.SizedBox(height: 2),
        pw.Text(labels.directorLine, style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt)),
      ],
      pw.SizedBox(height: 2),
      pw.Text(
        versionLine,
        style: pw.TextStyle(font: painter.fonts.regular, fontSize: _smallFontSizePt, color: _mutedColor),
      ),
    ],
  );

  /// The day's own number and its full title (`JOUR : 2` / `FEUILLE DE SERVICE DU …`).
  pw.Widget _dayHeadingSection({
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
          style: pw.TextStyle(font: painter.fonts.bold, fontSize: _bodyFontSizePt),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          title.isEmpty ? "${labels.dayTagPrefix}${day.dayNumber}" : title,
          style: pw.TextStyle(font: painter.fonts.bold, fontSize: _titleFontSizePt),
        ),
      ],
    );
  }

  /// A named sheet's own single band line: arrival, PAT band, departure — three figures the general
  /// sheet only ever prints per person inside its cast table or its two closing lists.
  pw.Widget _ownBandSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required OcptDayConvocation convocation,
  }) {
    final lines = [
      "${labels.arrivalHeader} : ${ocptFormatDayMinute(convocation.arrivalMinute)}",
      "${labels.patLabel} : ${_patCellOf(convocation)}",
      "${labels.departureLabel} : ${ocptFormatDayMinute(convocation.departureMinute)}",
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          pw.Text(line, style: pw.TextStyle(font: painter.fonts.bold, fontSize: _bodyFontSizePt)),
      ],
    );
  }

  /// A named sheet's own "to bring" table: one `<code> · <name>` / `SEQ` row per [rows] entry, the
  /// join [OcptSchedulePlanSnapshot.elementsToBringOnDay] makes between this recipient's own
  /// [OcptElement.broughtByPersonId] and the scenes the day actually plays. [generateNamedCallSheet]
  /// never calls this on an empty [rows] — see its own doc comment.
  pw.Widget _toBringSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required List<_ToBringRow> rows,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionTitle(painter: painter, title: labels.toBringSectionTitle),
      pw.SizedBox(height: 4),
      pw.Table(
        border: pw.TableBorder.all(color: _ruleColor, width: 0.5),
        columnWidths: _toBringColumnWidths,
        children: [
          pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(color: _bandColor),
            children: [
              for (final header in [labels.nameHeader, labels.seqHeader])
                _textCell(painter: painter, text: header, isBold: true),
            ],
          ),
          for (final row in rows)
            pw.TableRow(
              children: [
                _textCell(painter: painter, text: "${row.element.code} · ${row.element.name}"),
                _textCell(
                  painter: painter,
                  text: row.sceneNumbers.isEmpty ? ocptScheduleEmptyValue : row.sceneNumbers.join(", "),
                ),
              ],
            ),
        ],
      ),
    ],
  );

  /// The crew note, verbatim — never printed at all when the day carries none (both generators skip
  /// this widget rather than calling it on a blank note).
  pw.Widget _crewNoteSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required String note,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionTitle(painter: painter, title: labels.crewNoteSectionTitle),
      pw.SizedBox(height: 2),
      _noteWidget(painter: painter, text: note.trim()),
    ],
  );

  /// The day's own events, one timed line each — what the day does not control, at an absolute
  /// hour, taking part in no chain and therefore never interleaved into the main table's own
  /// milestone rows. Both generators skip this widget rather than calling it on an empty list, for
  /// a different reason than [_crewNoteSection]'s own: the cast table prints an em dash on a role
  /// nobody convoked because it is a **standing** section of the reference document, while an
  /// events section only belongs on a sheet the day actually has something it does not control on.
  pw.Widget _eventsSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required List<OcptShootingDayEvent> events,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionTitle(painter: painter, title: labels.eventsSectionTitle),
      pw.SizedBox(height: 2),
      for (final event in events) ...[
        pw.Text(
          "${ocptFormatDayMinute(event.minute)} — ${event.label.trim().isEmpty ? ocptScheduleEmptyValue : event.label.trim()}",
          style: pw.TextStyle(font: painter.fonts.bold, fontSize: _bodyFontSizePt),
        ),
        if (event.notes.trim().isNotEmpty) ...[
          pw.SizedBox(height: 1),
          pw.Text(
            event.notes.trim(),
            style: pw.TextStyle(font: painter.fonts.regular, fontSize: _smallFontSizePt, color: _mutedColor),
          ),
        ],
        pw.SizedBox(height: 4),
      ],
    ],
  );

  /// The location(s) [locations] names: name, address, then a Google Maps link built from its own
  /// coordinates when it has any — never a network call, and nothing printed when it has none.
  pw.Widget _locationSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required List<OcptLocation> locations,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionTitle(painter: painter, title: labels.locationSectionTitle),
      pw.SizedBox(height: 2),
      if (locations.isEmpty)
        _noteWidget(painter: painter, text: ocptScheduleEmptyValue)
      else
        for (final location in locations) ...[
          _noteWidget(painter: painter, text: ocptScheduleLocationAddressLine(location)),
          if (_mapsUrlOf(location) case final url?) ...[
            pw.SizedBox(height: 1),
            pw.UrlLink(
              destination: url,
              child: pw.Text(
                "${labels.mapsLinkLabel} : $url",
                style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt, color: PdfColors.blue),
              ),
            ),
          ],
          pw.SizedBox(height: 6),
        ],
    ],
  );

  /// The day's own sunrise, sunset and the two civil twilights, each independently printed as
  /// [ocptScheduleEmptyValue] while [sunTimes] has no figure for it (ADR 0016).
  pw.Widget _sunSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required OcptSunTimes? sunTimes,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionTitle(painter: painter, title: labels.sunSectionTitle),
      pw.SizedBox(height: 2),
      pw.Wrap(
        spacing: 16,
        runSpacing: 2,
        children: [
          _sunFigure(painter: painter, label: labels.civilDawnLabel, minute: sunTimes?.civilDawnMinute),
          _sunFigure(painter: painter, label: labels.sunriseLabel, minute: sunTimes?.sunriseMinute),
          _sunFigure(painter: painter, label: labels.sunsetLabel, minute: sunTimes?.sunsetMinute),
          _sunFigure(painter: painter, label: labels.civilDuskLabel, minute: sunTimes?.civilDuskMinute),
        ],
      ),
    ],
  );

  /// One figure of [_sunSection].
  pw.Widget _sunFigure({required OcptScriptPagePainter painter, required String label, required int? minute}) =>
      pw.Text(
        "$label ${minute == null ? ocptScheduleEmptyValue : ocptFormatDayMinute(minute)}",
        style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt),
      );

  /// The key contacts (production and direction) or the by-department contacts table (image, sound,
  /// art department, HMC) — the same widget for both, over whichever [departments] the caller asks
  /// for, since both are "`<position> : <first name>`, grouped by department" laid side by side.
  pw.Widget _contactsBlock({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required List<_CrewContact> crewContacts,
    required Set<OcptCrewDepartment> departments,
  }) {
    final byDepartment = <OcptCrewDepartment, List<_CrewContact>>{};
    for (final contact in crewContacts) {
      final department = contact.department;
      if (department == null || !departments.contains(department)) {
        continue;
      }
      (byDepartment[department] ??= <_CrewContact>[]).add(contact);
    }

    final present = [
      for (final department in departments)
        if ((byDepartment[department] ?? const <_CrewContact>[]).isNotEmpty) department,
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle(painter: painter, title: labels.contactsSectionTitle),
        pw.SizedBox(height: 2),
        if (present.isEmpty)
          _noteWidget(painter: painter, text: ocptScheduleEmptyValue)
        else
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final department in present)
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        labels.crewDepartmentLabelOf(department).toUpperCase(),
                        style: pw.TextStyle(font: painter.fonts.bold, fontSize: _smallFontSizePt, color: _mutedColor),
                      ),
                      pw.SizedBox(height: 2),
                      for (final contact in byDepartment[department]!)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(bottom: 4, right: 4),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _noteWidget(
                                painter: painter,
                                text: "${contact.positionLabel} : ${contact.person.firstName}",
                              ),
                              if (contact.person.phone.trim().isNotEmpty)
                                pw.Text(
                                  contact.person.phone,
                                  style: pw.TextStyle(
                                    font: painter.fonts.regular,
                                    fontSize: _smallFontSizePt,
                                    color: _mutedColor,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }

  /// The day's own time bands — one line per slot, then the day's own PAT band (the widest span
  /// over every convocation that has one), then each `meal` block's own band.
  pw.Widget _timeBandsSection({
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
        lines.add(_timeBandLine(label: label, startMinute: timeline.startMinute, endMinute: timeline.endMinute));
      }
    }

    int? patStart;
    int? patEnd;
    for (final convocation in convocations) {
      final start = convocation.patStartMinute;
      final end = convocation.patEndMinute;
      if (start != null && (patStart == null || start < patStart)) {
        patStart = start;
      }
      if (end != null && (patEnd == null || end > patEnd)) {
        patEnd = end;
      }
    }
    if (patStart != null && patEnd != null) {
      lines.add(
        _timeBandLine(label: "${labels.hoursLinePrefix} ${labels.patLabel}", startMinute: patStart, endMinute: patEnd),
      );
    }

    for (final ordered in orderedEntries) {
      if (ordered.block.kind != OcptShootingBlockKind.meal) {
        continue;
      }
      lines.add(
        _timeBandLine(
          label: _captionOf(block: ordered.block, labels: labels, headingBySceneId: const {}),
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
          pw.Text(line, style: pw.TextStyle(font: painter.fonts.bold, fontSize: _bodyFontSizePt)),
      ],
    );
  }

  // ---------------------------------------------------------------------------------------------
  // Main table
  // ---------------------------------------------------------------------------------------------

  /// The day's main table, interleaved with full-width milestone rows and, under a row that carries
  /// one, a full-width crew-note band — or [OcptCallSheetLabels.emptyDayNote] when [rows] is empty
  /// (no slot, or no block on any of them).
  ///
  /// **A shot run's own crew note prints directly under its row**, and getting that requires closing
  /// the `pw.Table` chunk the row belongs to the moment the row is seen: a `pw.TableRow` cannot span
  /// the page width the way [_milestoneRowWidget] itself can, so the only way to put a full-width
  /// note right under a run of otherwise ordinary rows is to end the table there and draw the note as
  /// a widget of its own — `flushShotRows` is called the instant a pending row carries a crew note,
  /// even mid-run, splitting what would otherwise have been one continuous table into two around the
  /// note. A milestone's own crew note has no such problem, since [_milestoneRowWidget] is already a
  /// full-width band and prints it inline.
  pw.Widget _mainTableSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required List<_DayRow> rows,
    required List<OcptRole> roles,
  }) {
    if (rows.isEmpty) {
      return _noteWidget(painter: painter, text: labels.emptyDayNote);
    }

    final children = <pw.Widget>[];
    var pendingShotRows = <_DayRow>[];

    void flushShotRows() {
      if (pendingShotRows.isEmpty) {
        return;
      }
      children.add(_mainTable(painter: painter, labels: labels, rows: pendingShotRows, roles: roles));
      pendingShotRows = <_DayRow>[];
    }

    for (final row in rows) {
      if (row.isMilestone) {
        flushShotRows();
        children.add(_milestoneRowWidget(painter: painter, labels: labels, row: row));
      } else {
        pendingShotRows.add(row);
        if (row.crewNotes.isNotEmpty) {
          flushShotRows();
          children.add(_crewNoteBandWidget(painter: painter, crewNotes: row.crewNotes));
        }
      }
    }
    flushShotRows();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final (index, child) in children.indexed) ...[if (index > 0) pw.SizedBox(height: 4), child],
      ],
    );
  }

  /// A full-width band naming a shot run's own crew note(s) — printed the moment
  /// [_mainTableSection]'s own composition closes a table chunk on a row that carries one, since the
  /// `pw.Table` row itself cannot span the page width a note deserves. Drawn like
  /// [_milestoneRowWidget]'s own container but **without** its [_bandColor] fill, so a note reads as
  /// a note rather than as another milestone.
  pw.Widget _crewNoteBandWidget({required OcptScriptPagePainter painter, required List<String> crewNotes}) =>
      pw.Container(
        constraints: const pw.BoxConstraints(minWidth: double.infinity),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _ruleColor, width: 0.5)),
        padding: const pw.EdgeInsets.all(_cellPaddingPt),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final (index, note) in crewNotes.indexed) ...[
              if (index > 0) pw.SizedBox(height: 2),
              pw.Text(note, style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt)),
            ],
          ],
        ),
      );

  /// One run of consecutive [_DayRow.shotRun] rows, as a `SEQ / PLANS / EFFET / DÉCORS / RÔLES`
  /// table — see [_mainColumnWidths] for why the reference's own `RÉSUMÉ` column is not among them.
  pw.Widget _mainTable({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required List<_DayRow> rows,
    required List<OcptRole> roles,
  }) => pw.Table(
    border: pw.TableBorder.all(color: _ruleColor, width: 0.5),
    columnWidths: _mainColumnWidths,
    children: [
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(color: _bandColor),
        children: [
          for (final header in [
            labels.seqHeader,
            labels.plansHeader,
            labels.effetHeader,
            labels.decorsHeader,
            labels.rolesHeader,
          ])
            _textCell(painter: painter, text: header, isBold: true),
        ],
      ),
      for (final row in rows)
        pw.TableRow(
          children: [
            _textCell(painter: painter, text: row.shots.isEmpty ? ocptScheduleEmptyValue : ocptShotSceneNumberOf(row.shots.first)),
            _textCell(painter: painter, text: row.shots.map(ocptShotRankOf).join(",")),
            _textCell(
              painter: painter,
              text: ocptSceneEffectOf(row.heading).printedEffect ?? ocptScheduleEmptyValue,
            ),
            _textCell(painter: painter, text: row.decors ?? ocptScheduleEmptyValue),
            _textCell(painter: painter, text: _rolesLabelOf(row, roles)),
          ],
        ),
    ],
  );

  /// A full-width band naming a non-shot block and its own time band — under it, the roles that band
  /// expects, on a line of their own behind the `RÔLES` label the main table already heads its own
  /// column with ([ocptScheduleBlockRoleNumbersLine]), then the block's own crew note, if it has one.
  /// A band expecting nobody and carrying no note prints the one time-band line alone. The note
  /// prints inline, unlike a shot run's own ([_crewNoteBandWidget]): this band is already full-width,
  /// so it has nothing to close and reopen the way a `pw.Table` row does.
  pw.Widget _milestoneRowWidget({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required _DayRow row,
  }) {
    final rolesLine = ocptScheduleBlockRoleNumbersLine(
      roleNumbers: row.milestoneRoleNumbers,
      rolesLabel: labels.rolesHeader,
    );

    return pw.Container(
      constraints: const pw.BoxConstraints(minWidth: double.infinity),
      decoration: pw.BoxDecoration(color: _bandColor, border: pw.Border.all(color: _ruleColor, width: 0.5)),
      padding: const pw.EdgeInsets.all(_cellPaddingPt),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _timeBandLine(label: row.milestoneCaption ?? "", startMinute: row.startMinute, endMinute: row.endMinute),
            style: pw.TextStyle(font: painter.fonts.bold, fontSize: _bodyFontSizePt),
          ),
          if (rolesLine != null) ...[
            pw.SizedBox(height: 2),
            pw.Text(rolesLine, style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt)),
          ],
          for (final note in row.crewNotes) ...[
            pw.SizedBox(height: 2),
            pw.Text(note, style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt)),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------------------------
  // Cast table, crew list, cast-and-extras list — day-wide, on both sheets
  // ---------------------------------------------------------------------------------------------

  /// The day's own cast table: `RÔLE / COMÉDIEN / SEQ / ARRIVÉE / PAT`.
  pw.Widget _castTableSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required List<_CastRow> rows,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionTitle(painter: painter, title: labels.castSectionTitle),
      pw.SizedBox(height: 4),
      if (rows.isEmpty)
        _noteWidget(painter: painter, text: ocptScheduleEmptyValue)
      else
        pw.Table(
          border: pw.TableBorder.all(color: _ruleColor, width: 0.5),
          columnWidths: _castColumnWidths,
          children: [
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: _bandColor),
              children: [
                for (final header in [
                  labels.roleHeader,
                  labels.actorHeader,
                  labels.seqHeader,
                  labels.arrivalHeader,
                  labels.patLabel,
                ])
                  _textCell(painter: painter, text: header, isBold: true),
              ],
            ),
            for (final row in rows)
              pw.TableRow(
                children: [
                  _textCell(painter: painter, text: "${row.role.number} · ${row.role.name}"),
                  _textCell(
                    painter: painter,
                    text: (row.actor?.displayName ?? "").trim().isEmpty ? ocptScheduleEmptyValue : row.actor!.displayName,
                  ),
                  _textCell(painter: painter, text: row.sceneNumbers.isEmpty ? ocptScheduleEmptyValue : row.sceneNumbers.join(", ")),
                  _textCell(
                    painter: painter,
                    text: row.convocation == null ? ocptScheduleEmptyValue : ocptFormatDayMinute(row.convocation!.arrivalMinute),
                  ),
                  _textCell(painter: painter, text: _patCellOf(row.convocation)),
                ],
              ),
          ],
        ),
    ],
  );

  /// The crew list or the cast-and-extras list — the same `NOM / POSTE(S) / TEL. / MAIL / HORAIRES`
  /// shape for both.
  pw.Widget _peopleListSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required String title,
    required List<_PeopleListEntry> entries,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionTitle(painter: painter, title: title),
      pw.SizedBox(height: 4),
      if (entries.isEmpty)
        _noteWidget(painter: painter, text: ocptScheduleEmptyValue)
      else
        pw.Table(
          border: pw.TableBorder.all(color: _ruleColor, width: 0.5),
          columnWidths: _peopleColumnWidths,
          children: [
            pw.TableRow(
              repeat: true,
              decoration: const pw.BoxDecoration(color: _bandColor),
              children: [
                for (final header in [
                  labels.nameHeader,
                  labels.positionsHeader,
                  labels.phoneHeader,
                  labels.emailHeader,
                  labels.hoursLinePrefix,
                ])
                  _textCell(painter: painter, text: header, isBold: true),
              ],
            ),
            for (final entry in entries)
              pw.TableRow(
                children: [
                  _textCell(painter: painter, text: entry.name),
                  _textCell(painter: painter, text: entry.positionOrRole),
                  _textCell(painter: painter, text: entry.phone),
                  _textCell(painter: painter, text: entry.email),
                  _textCell(painter: painter, text: entry.scheduleLabel),
                ],
              ),
          ],
        ),
    ],
  );

  /// The day's own trailing guest table (`NOM / MOTIF / HORAIRES`) — a guest never carries a PAT
  /// band (ADR 0018), so unlike [_peopleListSection] this table has no `PAT` column to leave blank
  /// for one at all. Printed after the cast-and-extras list on both sheets, the shape the
  /// `Convocations` dock panel's own trailing guest group already gives guests, and for the same
  /// reason: they are on the day and are owed an hour, but they are not the call an assistant
  /// director reads down.
  pw.Widget _guestsSection({
    required OcptScriptPagePainter painter,
    required OcptCallSheetLabels labels,
    required List<OcptScheduleGuestRow> rows,
  }) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionTitle(painter: painter, title: labels.guestsSectionTitle),
      pw.SizedBox(height: 4),
      pw.Table(
        border: pw.TableBorder.all(color: _ruleColor, width: 0.5),
        columnWidths: _guestColumnWidths,
        children: [
          pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(color: _bandColor),
            children: [
              for (final header in [labels.nameHeader, labels.guestReasonHeader, labels.hoursLinePrefix])
                _textCell(painter: painter, text: header, isBold: true),
            ],
          ),
          for (final row in rows)
            pw.TableRow(
              children: [
                _textCell(painter: painter, text: row.name),
                _guestReasonCell(painter: painter, row: row),
                _textCell(painter: painter, text: row.hours),
              ],
            ),
        ],
      ),
    ],
  );

  /// One [_guestsSection] row's own `MOTIF` cell: the guest's own reason(s), then their own note(s)
  /// on a muted second line when they carry any — the same shape [_contactsBlock]'s own contact
  /// entries print a phone number under a position in.
  pw.Widget _guestReasonCell({
    required OcptScriptPagePainter painter,
    required OcptScheduleGuestRow row,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(_cellPaddingPt),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          row.reason.isEmpty ? ocptScheduleEmptyValue : row.reason,
          style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt),
        ),
        if (row.notes.isNotEmpty) ...[
          pw.SizedBox(height: 1),
          pw.Text(
            row.notes,
            style: pw.TextStyle(font: painter.fonts.regular, fontSize: _smallFontSizePt, color: _mutedColor),
          ),
        ],
      ],
    ),
  );

  // ---------------------------------------------------------------------------------------------
  // Small shared drawing helpers
  // ---------------------------------------------------------------------------------------------

  /// One section's own small, muted heading.
  pw.Widget _sectionTitle({required OcptScriptPagePainter painter, required String title}) => pw.Text(
    title.toUpperCase(),
    style: pw.TextStyle(font: painter.fonts.bold, fontSize: _smallFontSizePt, color: _mutedColor),
  );

  /// A block of free text.
  pw.Widget _noteWidget({required OcptScriptPagePainter painter, required String text}) =>
      pw.Text(text, style: pw.TextStyle(font: painter.fonts.regular, fontSize: _bodyFontSizePt));

  /// One table cell holding [text].
  pw.Widget _textCell({required OcptScriptPagePainter painter, required String text, bool isBold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(_cellPaddingPt),
        child: pw.Text(
          text.isEmpty ? ocptScheduleEmptyValue : text,
          style: pw.TextStyle(font: painter.fonts.variant(bold: isBold, italic: false), fontSize: _bodyFontSizePt),
        ),
      );
}

// ===================================================================================================
// Pure data-preparation types and functions — no `pw.Widget` in sight, so a future test can exercise
// them directly if it ever needs to.
// ===================================================================================================

/// One printed row of the main table: either a run of one or more consecutive [shots] on the same
/// slot and the same scene, collapsed the way the reference call sheets do, or a single
/// [milestoneCaption] naming a full-width band.
class _DayRow {
  _DayRow._({
    required this.slotId,
    required this.sceneId,
    required this.heading,
    required this.decors,
    required this.shots,
    required this.milestoneCaption,
    required this.milestoneRoleNumbers,
    required this.startMinute,
    required this.endMinute,
    required this.crewNotes,
  });

  /// Builds a row starting a new run of shot blocks, seeded with [crewNote]'s own printable crew
  /// note, if it has one.
  factory _DayRow.shotRun({
    required String slotId,
    required String? sceneId,
    required String? heading,
    required String? decors,
    required OcptShot shot,
    required int startMinute,
    required int endMinute,
    required String crewNote,
  }) => _DayRow._(
    slotId: slotId,
    sceneId: sceneId,
    heading: heading,
    decors: decors,
    shots: [shot],
    milestoneCaption: null,
    milestoneRoleNumbers: const [],
    startMinute: startMinute,
    endMinute: endMinute,
    crewNotes: crewNote.trim().isEmpty ? [] : [crewNote.trim()],
  );

  /// Builds a full-width milestone row, carrying the numbers of the roles its own band expects
  /// ([ocptScheduleBlockRoleNumbersOf]) — empty for every kind but a hair-and-make-up band — and its
  /// own block's printable crew note, if it has one.
  factory _DayRow.milestone({
    required String caption,
    required List<int> roleNumbers,
    required int startMinute,
    required int? endMinute,
    required String crewNote,
  }) => _DayRow._(
    slotId: null,
    sceneId: null,
    heading: null,
    decors: null,
    shots: const [],
    milestoneCaption: caption,
    milestoneRoleNumbers: roleNumbers,
    startMinute: startMinute,
    endMinute: endMinute,
    crewNotes: crewNote.trim().isEmpty ? [] : [crewNote.trim()],
  );

  /// The slot this row's [shots] were placed on, or null for a milestone.
  final String? slotId;

  /// The scene this row's [shots] belong to, or null for a milestone or an orphaned shot.
  final String? sceneId;

  /// The heading of [sceneId], or null.
  final String? heading;

  /// The name of the set this row's slot is shot at, or null.
  final String? decors;

  /// The shots collapsed into this row — always exactly one until a following shot of the same
  /// scene, on the same slot, is appended to it.
  final List<OcptShot> shots;

  /// This row's own caption, non-null exactly for a milestone.
  final String? milestoneCaption;

  /// The numbers of the roles this milestone's own band expects, sorted — always empty but for a
  /// hair-and-make-up band, and empty there too while its slot convokes nobody.
  final List<int> milestoneRoleNumbers;

  /// Where this row starts, resolved.
  final int startMinute;

  /// Where this row ends, resolved — mutable so a following collapsed shot can extend it.
  int? endMinute;

  /// The trimmed, non-empty [OcptShootingDayBlock.crewNote]s of the blocks collapsed into this row,
  /// in the blocks' own order — always at most one entry for a milestone row (one block), and
  /// possibly several for a shot run once a following collapsed shot's own note is appended to it.
  /// **Never** the block's own private `notes`, which this document never prints at all.
  final List<String> crewNotes;

  /// Whether this is a milestone row rather than a run of shot blocks.
  bool get isMilestone => milestoneCaption != null;
}

/// One row of the day's own cast table.
class _CastRow {
  const _CastRow({required this.role, required this.actor, required this.sceneNumbers, required this.convocation});

  /// The role convoked.
  final OcptRole role;

  /// The actor cast in [role], or null while it is uncast.
  final OcptPerson? actor;

  /// The scene numbers this role's character is shot in today, sorted.
  final List<String> sceneNumbers;

  /// This role's (or its actor's) own computed convocation, or null while nobody linked it to a
  /// slot at all — which should not happen for a role a cast row already names, but is read
  /// defensively rather than assumed.
  final OcptDayConvocation? convocation;
}

/// One crew member's own contact: who they are, what they hold that day, and which department that
/// position belongs to (null for a free-text `OcptShootingSlotCrewMember.customLabel` the catalogue
/// has no department for).
class _CrewContact {
  const _CrewContact({required this.person, required this.positionLabel, required this.department});

  /// The person themselves.
  final OcptPerson person;

  /// The label of the position they hold that day — the catalogue's own label, or their own free
  /// text.
  final String positionLabel;

  /// The department [positionLabel] belongs to, or null for a free-text position.
  final OcptCrewDepartment? department;
}

/// One row of the crew list or the cast-and-extras list — the two lists print the same shape, so
/// they share this type.
class _PeopleListEntry {
  const _PeopleListEntry({
    required this.name,
    required this.positionOrRole,
    required this.phone,
    required this.email,
    required this.scheduleLabel,
  });

  /// The person's own display name, or [OcptCallSheetLabels.unnamedPersonLabel] for an uncast role.
  final String name;

  /// The position(s) they hold, comma-joined, or the role's own number and name.
  final String positionOrRole;

  /// Their own phone number, empty when there is none (an uncast role has nobody's phone to print).
  final String phone;

  /// Their own email address, empty for the same reason.
  final String email;

  /// Their own arrival – departure band, or [ocptScheduleEmptyValue] while they have no convocation at all.
  final String scheduleLabel;
}

/// One row of a named sheet's own "to bring" table: an element
/// [OcptSchedulePlanSnapshot.elementsToBringOnDay] joined onto that sheet's own recipient, and the
/// scene numbers of the day's own shots that play a scene it is linked to.
class _ToBringRow {
  const _ToBringRow({required this.element, required this.sceneNumbers});

  /// The element the recipient is due to bring.
  final OcptElement element;

  /// The scene numbers of the day's own shots that play a scene [element] is linked to, sorted —
  /// empty when [element] is linked to a scene the day plays through no numbered shot at all, which
  /// still prints ([ocptScheduleEmptyValue]) rather than being left out: the join already established
  /// the element belongs on this list, and a bare scene id would explain nothing on a printed page.
  final List<String> sceneNumbers;
}

/// Turns [orderedEntries] into the printed rows of the main table: a run of consecutive
/// [OcptShootingBlockKind.shot] blocks on the same slot and the same scene collapses into one
/// [_DayRow], every other kind prints its own [_DayRow.milestone].
List<_DayRow> _buildDayRows({
  required OcptSchedulePlanSnapshot plan,
  required List<OcptOrderedScheduleEntry> orderedEntries,
  required Map<String, String> headingBySceneId,
  required OcptCallSheetLabels labels,
}) {
  final rows = <_DayRow>[];

  for (final ordered in orderedEntries) {
    final block = ordered.block;
    final entry = ordered.entry;
    final slot = ordered.slot;

    if (block.kind == OcptShootingBlockKind.shot) {
      final shot = block.shotId == null ? null : plan.shotById(block.shotId!);
      if (shot == null) {
        continue;
      }

      final last = rows.isNotEmpty ? rows.last : null;
      if (last != null &&
          !last.isMilestone &&
          last.slotId == slot.id &&
          shot.sceneId != null &&
          last.sceneId == shot.sceneId) {
        last.shots.add(shot);
        last.endMinute = entry.endMinute;
        final note = block.crewNote.trim();
        if (note.isNotEmpty) {
          last.crewNotes.add(note);
        }
        continue;
      }

      rows.add(
        _DayRow.shotRun(
          slotId: slot.id,
          sceneId: shot.sceneId,
          heading: shot.sceneId == null ? null : headingBySceneId[shot.sceneId],
          decors: slot.setId == null ? null : plan.setById[slot.setId]?.name,
          shot: shot,
          startMinute: entry.startMinute,
          endMinute: entry.endMinute,
          crewNote: block.crewNote,
        ),
      );
      continue;
    }

    rows.add(
      _DayRow.milestone(
        caption: _captionOf(block: block, labels: labels, headingBySceneId: headingBySceneId),
        roleNumbers: ocptScheduleBlockRoleNumbersOf(
          block: block,
          slot: slot,
          roleById: plan.roleById,
        ),
        startMinute: entry.startMinute,
        endMinute: entry.endMinute,
        crewNote: block.crewNote,
      ),
    );
  }

  return rows;
}

/// The caption a non-shot [block] prints: its own free-text label when it has one, a
/// [OcptShootingBlockKind.hold]'s own sequence heading when it names one and carries no free-text
/// label, or [OcptCallSheetLabels.blockKindLabelOf] as the final fallback.
///
/// A thin alias over [ocptScheduleBlockCaptionOf] (`ocpt_schedule_pdf_shared.dart`), shared with
/// `OcptShootingPlanPdfService` — see that function's own doc comment for why. The roles a
/// hair-and-make-up band expects are **not** part of it: they are
/// [ocptScheduleBlockRoleNumbersOf]'s own answer, printed on the band's own second line.
String _captionOf({
  required OcptShootingDayBlock block,
  required OcptCallSheetLabels labels,
  required Map<String, String> headingBySceneId,
}) => ocptScheduleBlockCaptionOf(
  block: block,
  headingBySceneId: headingBySceneId,
  blockKindLabelOf: labels.blockKindLabelOf,
);

/// The day's own cast table rows: one per role the day **calls for** — every role convoked on one of
/// its live slots, and every role a shot placed on it plays — the scenes each of them shoots today
/// read off [orderedEntries]' own shot blocks.
///
/// **A role the day's shots name is listed even when nobody convoked it**, and that is the whole
/// point of the table: the main table's own `RÔLES` column prints role *numbers*, and a reader
/// looking `3` up has nowhere else on the sheet to find out who that is. Such a row carries no
/// convocation, so its `ARRIVÉE` and `PAT` cells read as em dashes — which is the truthful reading
/// of "this role plays today and nobody has called them", the very thing
/// `OcptScheduleRoleNotConvokedAlert` raises in the app. It is never guessed at from the shot's own
/// hours: a convocation is the slot you are linked to (ADR 0018), and a role linked to none has no
/// times at all.
///
/// Both generators pass the **whole day's** entries, a named sheet included: this table says who the
/// day calls for, and a `SEQ` cell counting only the sequences its reader happens to share a slot
/// with would understate every other actor's day.
List<_CastRow> _castRowsOfDay({
  required OcptSchedulePlanSnapshot plan,
  required String dayId,
  required List<OcptOrderedScheduleEntry> orderedEntries,
}) {
  final slots = plan.schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
  final convocations = plan.convocationsOfDay(dayId);
  final convocationByPersonId = {for (final c in convocations) if (c.personId != null) c.personId!: c};
  final convocationByRoleId = {for (final c in convocations) if (c.roleId != null) c.roleId!: c};
  final roleByNormalizedName = {
    for (final role in plan.roles) normalizeCharacterName(role.name): role,
  };

  final seenRoleIds = <String>{};
  final rows = <_CastRow>[];

  void addRow(OcptRole role) {
    if (!seenRoleIds.add(role.id)) {
      return;
    }

    final actor = role.personId == null ? null : plan.personById[role.personId];
    final convocation = actor != null ? convocationByPersonId[actor.id] : convocationByRoleId[role.id];

    final normalizedName = normalizeCharacterName(role.name);
    final sceneNumbers = <String>{};
    for (final ordered in orderedEntries) {
      if (ordered.block.kind != OcptShootingBlockKind.shot || ordered.block.shotId == null) {
        continue;
      }
      final shot = plan.shotById(ordered.block.shotId!);
      if (shot != null && shot.characters.contains(normalizedName)) {
        sceneNumbers.add(ocptShotSceneNumberOf(shot));
      }
    }

    rows.add(
      _CastRow(role: role, actor: actor, sceneNumbers: sceneNumbers.toList()..sort(), convocation: convocation),
    );
  }

  for (final slot in slots) {
    for (final member in slot.cast) {
      if (plan.roleById[member.roleId] case final role?) {
        addRow(role);
      }
    }
  }

  // The roles the day's own shots play, convoked or not — the same `shot.characters` join the main
  // table's own `RÔLES` column reads, so the two can never name a role the other cannot resolve. A
  // character name matching no role of the project resolves to nothing and is skipped, exactly as
  // that column skips it.
  for (final ordered in orderedEntries) {
    if (ordered.block.kind != OcptShootingBlockKind.shot || ordered.block.shotId == null) {
      continue;
    }
    final shot = plan.shotById(ordered.block.shotId!);
    if (shot == null) {
      continue;
    }
    for (final characterName in shot.characters) {
      if (roleByNormalizedName[characterName] case final role?) {
        addRow(role);
      }
    }
  }

  rows.sort((a, b) => a.role.number.compareTo(b.role.number));
  return rows;
}

/// A named sheet's own "to bring" rows: [OcptSchedulePlanSnapshot.elementsToBringOnDay] for
/// [personId] — already sorted by category then by name — paired with the scene numbers of
/// [dayEntries]' own shot blocks that play a scene each element is linked to, mirroring how
/// [_castRowsOfDay]'s own `sceneNumbers` is built off the very same [dayEntries]. Both this function
/// and [_castRowsOfDay] are handed the **day's** own entries rather than the recipient's restricted
/// `orderedEntries`, for the comment there's own reason: what an element is needed for today is a
/// fact about the day, not about which of its slots happens to convoke this reader.
List<_ToBringRow> _toBringRowsOfDay({
  required OcptSchedulePlanSnapshot plan,
  required String dayId,
  required String personId,
  required List<OcptOrderedScheduleEntry> dayEntries,
}) {
  final elements = plan.elementsToBringOnDay(dayId: dayId, personId: personId);
  if (elements.isEmpty) {
    return const [];
  }

  return [
    for (final element in elements)
      _ToBringRow(
        element: element,
        sceneNumbers: _sceneNumbersForElement(element: element, plan: plan, dayEntries: dayEntries),
      ),
  ];
}

/// The scene numbers of [dayEntries]' own shot blocks whose scene is one of [element]'s own
/// [OcptElement.sceneLinks], sorted — the join [_toBringRowsOfDay] prints on each of its rows.
List<String> _sceneNumbersForElement({
  required OcptElement element,
  required OcptSchedulePlanSnapshot plan,
  required List<OcptOrderedScheduleEntry> dayEntries,
}) {
  final sceneIds = {for (final link in element.sceneLinks) link.sceneId};
  final sceneNumbers = <String>{};

  for (final ordered in dayEntries) {
    if (ordered.block.kind != OcptShootingBlockKind.shot || ordered.block.shotId == null) {
      continue;
    }
    final shot = plan.shotById(ordered.block.shotId!);
    if (shot != null && shot.sceneId != null && sceneIds.contains(shot.sceneId)) {
      sceneNumbers.add(ocptShotSceneNumberOf(shot));
    }
  }

  return sceneNumbers.toList()..sort();
}

/// Every crew contact of [dayId], across every live slot, deduplicated by (person, position label)
/// — a person linked to two slots under the same position prints once, not twice.
List<_CrewContact> _crewContactsOfDay({
  required OcptSchedulePlanSnapshot plan,
  required String dayId,
  required OcptCallSheetLabels labels,
}) {
  final positionById = {for (final position in ocptCrewPositions) position.id: position};
  final slots = plan.schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
  final seen = <String>{};
  final contacts = <_CrewContact>[];

  for (final slot in slots) {
    for (final member in slot.crew) {
      final person = plan.personById[member.personId];
      if (person == null) {
        continue;
      }
      final position = member.positionId.isEmpty ? null : positionById[member.positionId];
      final positionLabel = position != null ? labels.crewPositionLabelOf(position.id) : member.customLabel;
      final key = "${person.id}|$positionLabel";
      if (!seen.add(key)) {
        continue;
      }
      contacts.add(_CrewContact(person: person, positionLabel: positionLabel, department: position?.department));
    }
  }

  return contacts;
}

/// The crew list's own rows: one per distinct person of [crewContacts], their own positions
/// comma-joined, their own arrival – departure band read off [convocations].
List<_PeopleListEntry> _crewListEntries({
  required List<_CrewContact> crewContacts,
  required List<OcptDayConvocation> convocations,
}) {
  final convocationByPersonId = {for (final c in convocations) if (c.personId != null) c.personId!: c};
  final positionsByPersonId = <String, List<String>>{};
  final personById = <String, OcptPerson>{};

  for (final contact in crewContacts) {
    personById[contact.person.id] = contact.person;
    (positionsByPersonId[contact.person.id] ??= <String>[]).add(contact.positionLabel);
  }

  final entries = [
    for (final person in personById.values)
      _PeopleListEntry(
        name: person.displayName,
        positionOrRole: (positionsByPersonId[person.id] ?? const <String>[]).join(", "),
        phone: person.phone,
        email: person.email,
        scheduleLabel: ocptScheduleArrivalDepartureLabel(convocationByPersonId[person.id]),
      ),
  ];

  entries.sort((a, b) => a.name.compareTo(b.name));
  return entries;
}

/// The cast-and-extras list's own rows: one per [castRows] entry, the actor's own name (or
/// [OcptCallSheetLabels.unnamedPersonLabel] for an uncast role) and the role's own number and name
/// as its position column.
///
/// It follows the cast table row for row, a role the day's shots play but nobody convoked included:
/// this list answers "how do I reach the people this day is about", and the one person an assistant
/// director needs to phone on the morning of a shoot is precisely the actor nobody called. Their
/// `HORAIRES` cell reads as an em dash, as their cast row's own times do.
List<_PeopleListEntry> _castListEntries({required List<_CastRow> castRows, required OcptCallSheetLabels labels}) {
  final entries = [
    for (final row in castRows)
      _PeopleListEntry(
        name: (row.actor?.displayName ?? "").trim().isEmpty ? labels.unnamedPersonLabel : row.actor!.displayName,
        positionOrRole: "${row.role.number} · ${row.role.name}",
        phone: row.actor?.phone ?? "",
        email: row.actor?.email ?? "",
        scheduleLabel: ocptScheduleArrivalDepartureLabel(row.convocation),
      ),
  ];

  entries.sort((a, b) => a.name.compareTo(b.name));
  return entries;
}

/// [convocation]'s own PAT band, or [ocptScheduleEmptyValue] while it has none — ADR 0018: a slot with no
/// shooting block gives no band at all, and this is never fabricated.
String _patCellOf(OcptDayConvocation? convocation) {
  if (convocation == null) {
    return ocptScheduleEmptyValue;
  }
  final start = convocation.patStartMinute;
  final end = convocation.patEndMinute;
  if (start == null || end == null) {
    return ocptScheduleEmptyValue;
  }
  return "${ocptFormatDayMinute(start)} – ${ocptFormatDayMinute(end)}";
}

/// The role numbers of every role whose character is in one of [row]'s own [_DayRow.shots], among
/// [roles] — matched the way the app already matches a shot's own characters to a role everywhere
/// else, through `normalizeCharacterName`.
String _rolesLabelOf(_DayRow row, List<OcptRole> roles) {
  final characterNames = <String>{for (final shot in row.shots) ...shot.characters};
  if (characterNames.isEmpty) {
    return ocptScheduleEmptyValue;
  }

  final byNormalizedName = {for (final role in roles) normalizeCharacterName(role.name): role};
  final matched = <OcptRole>{};
  for (final name in characterNames) {
    final role = byNormalizedName[name];
    if (role != null) {
      matched.add(role);
    }
  }

  if (matched.isEmpty) {
    return ocptScheduleEmptyValue;
  }

  final sorted = matched.toList()..sort((a, b) => a.number.compareTo(b.number));
  return sorted.map((role) => "${role.number}").join(", ");
}

/// One time-band line (`<label> : 16:45 – 22:45`), or `<label> : 16:45` when [endMinute] is null —
/// a milestone whose block resolves to zero duration, or a slot with nothing placed on it yet.
String _timeBandLine({required String label, required int startMinute, required int? endMinute}) {
  final start = ocptFormatDayMinute(startMinute);
  if (endMinute == null) {
    return "$label : $start";
  }
  return "$label : $start – ${ocptFormatDayMinute(endMinute)}";
}

/// The Google Maps URL built from [location]'s own coordinates, or null while it has none — the app
/// holds no map-link column of its own and makes no network call to build one (§A.8 of the reference
/// note this service was built against).
String? _mapsUrlOf(OcptLocation location) {
  final latitude = location.latitude;
  final longitude = location.longitude;
  if (latitude == null || longitude == null) {
    return null;
  }
  return "https://www.google.com/maps?q=$latitude,$longitude";
}

/// [convocation]'s own display name: the person's, the uncast role's, or
/// [OcptCallSheetLabels.unnamedPersonLabel] while neither names anybody printable.
String _convocationDisplayNameOf(
  OcptDayConvocation convocation,
  OcptSchedulePlanSnapshot plan,
  OcptCallSheetLabels labels,
) {
  final personId = convocation.personId;
  if (personId != null) {
    final name = plan.personById[personId]?.displayName.trim() ?? "";
    if (name.isNotEmpty) {
      return name;
    }
  }

  final roleId = convocation.roleId;
  if (roleId != null) {
    final name = plan.roleById[roleId]?.name.trim() ?? "";
    if (name.isNotEmpty) {
      return name;
    }
  }

  return labels.unnamedPersonLabel;
}

/// [convocation]'s own positions (a crew person's, comma-joined) or role label (an uncast or cast
/// role's own number and name), read off [ownSlots] alone.
String _convocationPositionsLabel({
  required OcptDayConvocation convocation,
  required List<OcptShootingSlot> ownSlots,
  required OcptSchedulePlanSnapshot plan,
  required OcptCallSheetLabels labels,
}) {
  final personId = convocation.personId;
  if (personId == null) {
    final roleId = convocation.roleId;
    final role = roleId == null ? null : plan.roleById[roleId];
    return role == null ? "" : "${labels.roleHeader} ${role.number} · ${role.name}";
  }

  final positionById = {for (final position in ocptCrewPositions) position.id: position};
  final seen = <String>{};
  final positions = <String>[];
  for (final slot in ownSlots) {
    for (final member in slot.crew) {
      if (member.personId != personId) {
        continue;
      }
      final position = member.positionId.isEmpty ? null : positionById[member.positionId];
      final label = position != null ? labels.crewPositionLabelOf(position.id) : member.customLabel;
      if (label.isNotEmpty && seen.add(label)) {
        positions.add(label);
      }
    }
  }

  return positions.join(", ");
}

/// Turns [value] into a safe fragment of a file name: diacritics folded (through
/// [_fileNameDiacriticsFold], case kept), unsafe characters ([_unsafeFileNameChars]) dropped, runs
/// of whitespace turned into a single dash, and any leading/trailing dash trimmed.
String _safeFileNamePart(String value) {
  final folded = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final lower = char.toLowerCase();
    final replacement = _fileNameDiacriticsFold[lower];
    if (replacement == null) {
      folded.write(char);
    } else {
      folded.write(char == lower ? replacement : replacement.toUpperCase());
    }
  }

  final withoutUnsafe = folded.toString().replaceAll(_unsafeFileNameChars, "");
  final dashed = withoutUnsafe.trim().replaceAll(RegExp(r"\s+"), "-");
  return dashed.replaceAll(RegExp(r"^-+|-+$"), "");
}

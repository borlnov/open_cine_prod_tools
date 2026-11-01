// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';
import 'package:open_cine_prod_tools/managers/abs_ocpt_service.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_header_sections.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_people_rows.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_rows.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_style.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_call_sheet_table_sections.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_courier_prime_fonts_loader.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_ordered_schedule_entry.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_script_page_painter.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_block.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_day_event.dart';
import 'package:open_cine_prod_tools/models/ocpt_shooting_slot.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_convocation.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_shooting_day_timelines.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Renders a shooting day's call sheet — the general one, following the reference `.docx` section
/// by section, and the named one, one per convoked person or uncast role.
///
/// This is pure rendering logic with no dialog or file-system access of its own: it's owned by
/// `OcptExportManager` and exposed as a public final field, reached through the manager rather than
/// through `globalGetIt()`, exactly like its siblings. It prints no screenplay, so — like
/// `OcptBreakdownSheetsPdfService` — it draws nothing through [OcptScriptPagePainter]'s absolutely
/// positioned page builders and flows its content in a [pw.MultiPage] instead; it still takes one
/// painter, for the page geometry every export of this app measures a sheet with and the Courier
/// Prime variants all four of them print in.
///
/// **One composition, whatever the day holds.** There is no such thing as a casting sheet or a
/// rehearsal sheet: a day is never given a kind, so this service reads the **blocks the day
/// actually holds** and lets the paper follow (ADR 0024). A day carrying an audition block adds an
/// audition table beside — never instead of — the main table its shots print, and a day convoking
/// candidates adds their own directory under the cast table; a day carrying neither prints neither,
/// no heading and no em dash, exactly as the events, guest and crew-note sections are already
/// skipped rather than drawn empty. A day that auditions in the morning and shoots in the afternoon
/// is one day, and gets one piece of paper carrying both tables in that order.
///
/// **One composition, two audiences**: every section a general and a named sheet share (the title
/// block, the day heading, the crew note, the day's own events, the location(s), the sun block, the
/// key contacts, the main table, the audition table, the cast table, the candidates list, the two
/// closing directories and the trailing guest table) is built by one shared private widget builder,
/// called from both [generateGeneralCallSheet] and [generateNamedCallSheet] rather than duplicated
/// between them. Only **three** sections belong to one sheet alone, none of them with a counterpart
/// to share: a named sheet's own recipient line, its own arrival/PAT/departure band, and its own
/// "to bring" section ([OcptCallSheetHeaderSections.toBringSection]) — the elements
/// [OcptSchedulePlanSnapshot.elementsToBringOnDay] joins onto that one recipient. The general sheet
/// has no reading for it at all, deliberately: what to bring is a fact about **one** recipient,
/// while the general sheet is the day's own paperwork, addressed to nobody in particular — printing
/// it there would mean printing every recipient's own list on everybody else's sheet, or guessing
/// which one the reader is.
///
/// **What a named sheet narrows is the timetable, and only the timetable** — twice over. Its main
/// table and its audition table hold the blocks of its recipient's own slots, and then only the
/// ones that recipient is actually **in**: an actor reads the shots calling a part they play, a
/// technician reads their unit end to end, a candidate reads their own auditions, and every
/// milestone stays for everybody ([ocptCallSheetEntriesOfRecipient]). A sheet is read down by one
/// person to know their own day, and one handed the whole running order makes them work out which
/// half is theirs. The audition table is a reading of that same timetable, not a directory — and
/// **a sheet addressed to a candidate narrows both one step further, to that candidacy alone**: its
/// audition table prints the auditions naming them and no other, and the candidates directory
/// prints their line alone (ADR 0024). It is the one place a block-level link narrows something a
/// slot-level one could not, and the reason is not tidiness: who else is being seen for a part, and
/// on what phone number, is the production's business and not another candidate's. The cast table,
/// the candidates list for every other recipient and the two closing directories are day-wide,
/// because they answer "who else is on this day and how do I reach them", which is a question about
/// the day rather than about the reader — and a crew that cannot phone each other on the morning of
/// a shoot is a crew that stops. The cast table is day-wide in a second sense too: it lists every
/// role the day **calls for**, including the ones a placed shot plays that nobody convoked, so a
/// role number printed in the main table's own `RÔLES` column can always be looked up on the same
/// sheet ([ocptCallSheetCastRowsOfDay]). The day's own events and its guests are day-wide for the
/// same reason: an event is a fact about the day rather than about a unit, and a guest is owed an
/// hour whichever slot happens to convoke the sheet's own recipient.
///
/// **A block's own [OcptShootingDayBlock.crewNote] prints under its own row**, unlike its private
/// `notes`, which never leaves the office — see [OcptCallSheetTableSections.mainTableSection] for
/// how a `pw.Table` row, which cannot itself span the page, still ends up with a full-width note
/// directly beneath it.
///
/// **Every hour printed comes off [OcptSchedulePlanSnapshot.timelinesOfDay]'s resolved clocks and
/// [OcptSchedulePlanSnapshot.convocationsOfDay]'s computed figures** — never off a stored anchor,
/// never re-derived, never offset by anything. A minute may exceed 1440 for a night shoot's small
/// hours, and every figure is printed through `ocptFormatDayMinute`, the one place that ever wraps
/// one back onto a clock face.
///
/// **A sheet that runs long says on every page what it is**: the running head is drawn through
/// [pw.MultiPage]'s own `header:` ([_page]) and every table here marks its header row `repeat:
/// true`, so a second page carries the project's name and knows which column is `ARRIVÉE` rather
/// than handing somebody five anonymous columns. `OcptShootingPlanPdfService` states the same two
/// rules for the same reason — a printed page is read on its own, and the sheet it was stapled to
/// is regularly not in the reader's hand.
class OcptCallSheetPdfService extends AbsOcptService {
  /// The loader the embedded Courier Prime font set is read through.
  final OcptCourierPrimeFontsLoader fontsLoader;

  /// Creates an [OcptCallSheetPdfService].
  ///
  /// Pass the manager's own [fontsLoader] so every export of the app session shares one font cache;
  /// a service built without one gets a loader of its own.
  OcptCallSheetPdfService({required super.logger, OcptCourierPrimeFontsLoader? fontsLoader})
    : fontsLoader = fontsLoader ?? OcptCourierPrimeFontsLoader();

  /// The `.pdf` file name of the general call sheet of day [dayNumber] (`FDS-J2.pdf`).
  String callSheetFileName({required OcptCallSheetLabels labels, required int dayNumber}) =>
      "${labels.fileNamePrefix}-${labels.dayTagPrefix}$dayNumber.pdf";

  /// The `.pdf` file name of the named call sheet of day [dayNumber] for [personName]
  /// (`FDS-J2-Elisa-Mabit.pdf`).
  ///
  /// [personName] is sanitized through [ocptCallSheetSafeFileNamePart] — diacritics folded, unsafe
  /// characters dropped, whitespace turned into dashes — and a name that sanitizes down to nothing
  /// (blank, or made entirely of characters a file name cannot hold) falls back to
  /// [OcptCallSheetLabels .unnamedPersonLabel], sanitized the same way, so the file still gets a
  /// stable, readable name rather than none at all.
  String namedCallSheetFileName({
    required OcptCallSheetLabels labels,
    required int dayNumber,
    required String personName,
  }) {
    final base = "${labels.fileNamePrefix}-${labels.dayTagPrefix}$dayNumber";
    final safeName = ocptCallSheetSafeFileNamePart(personName);
    final suffix = safeName.isEmpty
        ? ocptCallSheetSafeFileNamePart(labels.unnamedPersonLabel)
        : safeName;
    return suffix.isEmpty ? "$base.pdf" : "$base-$suffix.pdf";
  }

  /// Renders the general call sheet of [dayId]: the whole day's own paperwork, following the
  /// reference `.docx` section by section (§A of the reference note this service was built
  /// against).
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
    final versionLine =
        "${labels.versionLabel} ${ocptScheduleGeneratedAtStamp(exportDate ?? DateTime.now())}";
    final day = plan.schedule.daysById[dayId];
    final pdfDocument = pw.Document();

    if (day == null) {
      pdfDocument.addPage(
        _page(
          painter: painter,
          labels: labels,
          projectName: projectName,
          children: [
            OcptCallSheetTableSections.noteWidget(painter: painter, text: labels.emptyDayNote),
          ],
        ),
      );
      return pdfDocument.save();
    }

    final slots = plan.schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
    final timelines = plan.timelinesOfDay(dayId);
    final convocations = plan.convocationsOfDay(dayId);
    final headingBySceneId = ocptScheduleHeadingBySceneId(plan);
    final orderedEntries = ocptOrderedScheduleEntriesOfDay(plan: plan, dayId: dayId);
    final rows = ocptCallSheetBuildDayRows(
      plan: plan,
      orderedEntries: orderedEntries,
      headingBySceneId: headingBySceneId,
      labels: labels,
    );
    final castRows = ocptCallSheetCastRowsOfDay(
      plan: plan,
      dayId: dayId,
      orderedEntries: orderedEntries,
    );
    final crewContacts = ocptCallSheetCrewContactsOfDay(plan: plan, dayId: dayId, labels: labels);
    final locations = ocptScheduleLocationsOfSlots(plan, slots);
    final events = plan.schedule.eventsByDayId[dayId] ?? const <OcptShootingDayEvent>[];
    final guestRows = ocptScheduleGuestRowsOfDay(
      plan: plan,
      dayId: dayId,
      unnamedPersonLabel: labels.unnamedPersonLabel,
    );
    final auditionRows = ocptCallSheetAuditionRowsOfDay(plan: plan, orderedEntries: orderedEntries);
    final candidateEntries = ocptCallSheetCandidateListEntries(
      plan: plan,
      dayId: dayId,
      labels: labels,
    );

    pdfDocument.addPage(
      _page(
        painter: painter,
        labels: labels,
        projectName: projectName,
        children: [
          OcptCallSheetHeaderSections.recipientsSection(
            painter: painter,
            labels: labels,
            convocations: convocations,
            plan: plan,
          ),
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
            contactDepartments: const {
              OcptCrewDepartment.production,
              OcptCrewDepartment.direction,
              OcptCrewDepartment.unit,
            },
            locations: locations,
            events: events,
            plan: plan,
          ),
          pw.SizedBox(height: 10),
          OcptCallSheetHeaderSections.contactsBlock(
            painter: painter,
            labels: labels,
            crewContacts: crewContacts,
            departments: const {
              OcptCrewDepartment.castingAndExtras,
              OcptCrewDepartment.image,
              OcptCrewDepartment.electricAndGrip,
              OcptCrewDepartment.sound,
              OcptCrewDepartment.artDepartment,
              OcptCrewDepartment.costume,
              OcptCrewDepartment.hairAndMakeUp,
              OcptCrewDepartment.specialEffects,
            },
          ),
          pw.SizedBox(height: 10),
          OcptCallSheetTableSections.mainTableSection(
            painter: painter,
            labels: labels,
            rows: rows,
            roles: plan.roles,
          ),
          if (auditionRows.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            OcptCallSheetTableSections.auditionTableSection(
              painter: painter,
              labels: labels,
              rows: auditionRows,
            ),
          ],
          pw.SizedBox(height: 10),
          OcptCallSheetTableSections.castTableSection(
            painter: painter,
            labels: labels,
            rows: castRows,
          ),
          if (candidateEntries.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            OcptCallSheetTableSections.peopleListSection(
              painter: painter,
              labels: labels,
              title: labels.candidatesSectionTitle,
              entries: candidateEntries,
              secondColumnHeader: labels.roleHeader,
            ),
          ],
          pw.SizedBox(height: 10),
          OcptCallSheetTableSections.peopleListSection(
            painter: painter,
            labels: labels,
            title: labels.crewListSectionTitle,
            entries: ocptCallSheetCrewListEntries(
              crewContacts: crewContacts,
              convocations: convocations,
            ),
          ),
          pw.SizedBox(height: 10),
          OcptCallSheetTableSections.peopleListSection(
            painter: painter,
            labels: labels,
            title: labels.castAndExtrasListSectionTitle,
            entries: ocptCallSheetCastListEntries(castRows: castRows, labels: labels),
          ),
          if (guestRows.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            OcptCallSheetTableSections.guestsSection(
              painter: painter,
              labels: labels,
              rows: guestRows,
            ),
          ],
        ],
      ),
    );

    return pdfDocument.save();
  }

  /// Renders the named call sheet of [convocation] on [dayId]: the same day header, their own
  /// arrival/PAT/departure band, their own "to bring" section, the crew note, the day's own events,
  /// the location(s) and blocks of their own slots alone, the sun block, the key contacts — then
  /// the day's own cast table, crew list, cast-and-extras list and trailing guest table, exactly as
  /// the general sheet prints them. Only the main table is narrowed to the recipient's slots; see
  /// the class doc comment for why the other day-wide sections are not.
  ///
  /// The "to bring" section is printed only for a recipient this app can name a person for
  /// ([OcptDayConvocation.personId]) — an uncast role has nobody to bring anything, so the section
  /// is absent altogether rather than a heading over an em dash — and only when
  /// [OcptSchedulePlanSnapshot.elementsToBringOnDay] actually joins something, exactly as
  /// [OcptCallSheetHeaderSections.crewNoteSection] and [OcptCallSheetHeaderSections.eventsSection]
  /// are already skipped rather than drawn empty (their own doc comments).
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
    final versionLine =
        "${labels.versionLabel} ${ocptScheduleGeneratedAtStamp(exportDate ?? DateTime.now())}";
    final day = plan.schedule.daysById[dayId];
    final pdfDocument = pw.Document();

    if (day == null) {
      pdfDocument.addPage(
        _page(
          painter: painter,
          labels: labels,
          projectName: projectName,
          children: [
            OcptCallSheetTableSections.noteWidget(painter: painter, text: labels.emptyDayNote),
          ],
        ),
      );
      return pdfDocument.save();
    }

    final onlySlotIds = convocation.slotIds.toSet();
    final allSlots = plan.schedule.slotsByDayId[dayId] ?? const <OcptShootingSlot>[];
    final ownSlots = [
      for (final slot in allSlots)
        if (onlySlotIds.contains(slot.id)) slot,
    ];
    final headingBySceneId = ocptScheduleHeadingBySceneId(plan);
    // Narrowed twice: to the units this recipient is on, then to what they are actually in on them
    // ([ocptCallSheetEntriesOfRecipient]). A sheet is read down by one person to know their own day.
    final orderedEntries = ocptCallSheetEntriesOfRecipient(
      plan: plan,
      convocation: convocation,
      ownSlotEntries: ocptOrderedScheduleEntriesOfDay(
        plan: plan,
        dayId: dayId,
        onlySlotIds: onlySlotIds,
      ),
    );
    final rows = ocptCallSheetBuildDayRows(
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
    final castRows = ocptCallSheetCastRowsOfDay(
      plan: plan,
      dayId: dayId,
      orderedEntries: dayEntries,
    );
    final crewContacts = ocptCallSheetCrewContactsOfDay(plan: plan, dayId: dayId, labels: labels);
    final locations = ocptScheduleLocationsOfSlots(plan, ownSlots);
    final events = plan.schedule.eventsByDayId[dayId] ?? const <OcptShootingDayEvent>[];
    final guestRows = ocptScheduleGuestRowsOfDay(
      plan: plan,
      dayId: dayId,
      unnamedPersonLabel: labels.unnamedPersonLabel,
    );
    // The one directory a named sheet narrows, and only when the day sees its recipient for a part:
    // who else is being seen, and on what phone number, is the production's business and not
    // another candidate's. Null for every other recipient, which leaves both readings day-wide.
    final recipientRoleCandidateIds = convocation.isSeenForAPart
        ? convocation.roleCandidateIds
        : null;
    final auditionRows = ocptCallSheetAuditionRowsOfDay(
      plan: plan,
      orderedEntries: orderedEntries,
      onlyRoleCandidateIds: recipientRoleCandidateIds,
    );
    final candidateEntries = ocptCallSheetCandidateListEntries(
      plan: plan,
      dayId: dayId,
      labels: labels,
      onlyRoleCandidateIds: recipientRoleCandidateIds,
    );
    final displayName = ocptCallSheetConvocationDisplayNameOf(convocation, plan, labels);
    final positionsOrRole = ocptCallSheetConvocationPositionsLabel(
      convocation: convocation,
      ownSlots: ownSlots,
      plan: plan,
      labels: labels,
    );
    final recipientPersonId = convocation.personId;
    final toBringRows = recipientPersonId == null
        ? const <OcptCallSheetToBringRow>[]
        : ocptCallSheetToBringRowsOfDay(
            plan: plan,
            dayId: dayId,
            personId: recipientPersonId,
            dayEntries: dayEntries,
          );

    pdfDocument.addPage(
      _page(
        painter: painter,
        labels: labels,
        projectName: projectName,
        children: [
          OcptCallSheetHeaderSections.namedRecipientSection(
            painter: painter,
            labels: labels,
            displayName: displayName,
            positionsOrRole: positionsOrRole,
          ),
          pw.SizedBox(height: 10),
          OcptCallSheetHeaderSections.titleBlock(
            painter: painter,
            projectName: projectName,
            labels: labels,
            versionLine: versionLine,
          ),
          pw.SizedBox(height: 10),
          OcptCallSheetHeaderSections.dayHeadingSection(painter: painter, labels: labels, day: day),
          pw.SizedBox(height: 10),
          OcptCallSheetHeaderSections.ownBandSection(
            painter: painter,
            labels: labels,
            convocation: convocation,
          ),
          pw.SizedBox(height: 10),
          if (toBringRows.isNotEmpty) ...[
            OcptCallSheetHeaderSections.toBringSection(
              painter: painter,
              labels: labels,
              rows: toBringRows,
            ),
            pw.SizedBox(height: 10),
          ],
          if (events.isNotEmpty) ...[
            OcptCallSheetHeaderSections.eventsSection(
              painter: painter,
              labels: labels,
              events: events,
            ),
            pw.SizedBox(height: 10),
          ],
          if (day.crewNote.trim().isNotEmpty) ...[
            OcptCallSheetHeaderSections.crewNoteSection(
              painter: painter,
              labels: labels,
              note: day.crewNote,
            ),
            pw.SizedBox(height: 10),
          ],
          OcptCallSheetHeaderSections.locationSection(
            painter: painter,
            labels: labels,
            locations: locations,
          ),
          pw.SizedBox(height: 10),
          OcptCallSheetHeaderSections.sunSection(
            painter: painter,
            labels: labels,
            sunTimes: plan.sunTimesOfDay(dayId),
          ),
          pw.SizedBox(height: 10),
          OcptCallSheetHeaderSections.contactsBlock(
            painter: painter,
            labels: labels,
            crewContacts: crewContacts,
            departments: const {
              OcptCrewDepartment.production,
              OcptCrewDepartment.direction,
              OcptCrewDepartment.unit,
            },
          ),
          pw.SizedBox(height: 10),
          OcptCallSheetTableSections.mainTableSection(
            painter: painter,
            labels: labels,
            rows: rows,
            roles: plan.roles,
          ),
          if (auditionRows.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            OcptCallSheetTableSections.auditionTableSection(
              painter: painter,
              labels: labels,
              rows: auditionRows,
            ),
          ],
          pw.SizedBox(height: 10),
          OcptCallSheetTableSections.castTableSection(
            painter: painter,
            labels: labels,
            rows: castRows,
          ),
          if (candidateEntries.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            OcptCallSheetTableSections.peopleListSection(
              painter: painter,
              labels: labels,
              title: labels.candidatesSectionTitle,
              entries: candidateEntries,
              secondColumnHeader: labels.roleHeader,
            ),
          ],
          pw.SizedBox(height: 10),
          OcptCallSheetTableSections.peopleListSection(
            painter: painter,
            labels: labels,
            title: labels.crewListSectionTitle,
            entries: ocptCallSheetCrewListEntries(
              crewContacts: crewContacts,
              convocations: convocations,
            ),
          ),
          pw.SizedBox(height: 10),
          OcptCallSheetTableSections.peopleListSection(
            painter: painter,
            labels: labels,
            title: labels.castAndExtrasListSectionTitle,
            entries: ocptCallSheetCastListEntries(castRows: castRows, labels: labels),
          ),
          if (guestRows.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            OcptCallSheetTableSections.guestsSection(
              painter: painter,
              labels: labels,
              rows: guestRows,
            ),
          ],
        ],
      ),
    );

    return pdfDocument.save();
  }

  /// The sections [generateGeneralCallSheet] builds in this exact order, up to and including the
  /// sun block, over widget builders every one of which is shared with [generateNamedCallSheet] too
  /// (the title block, the day heading, the crew note, the day's own events, the location(s) and
  /// the sun block): only the *composition* differs between the two generators, called out inline
  /// at each call site, never the section builders themselves — that is what "one composition, two
  /// audiences" means in the class doc comment. The department contacts, the main table, the cast
  /// table, the two closing lists and the trailing guest table all print **after** what this method
  /// returns, since the reference call sheet's own contacts-by-department table sits between the
  /// sun block and the main table; they are added by [generateGeneralCallSheet] itself rather than
  /// folded in here, over the very same
  /// [OcptCallSheetHeaderSections.contactsBlock]/[OcptCallSheetTableSections.mainTableSection]/[OcptCallSheetTableSections.castTableSection]/[OcptCallSheetTableSections.peopleListSection]/[OcptCallSheetTableSections.guestsSection]
  /// builders [generateNamedCallSheet] also calls directly. [generateNamedCallSheet] does not call
  /// this method at all: its own recipient line and its own single band
  /// ([OcptCallSheetHeaderSections.ownBandSection], replacing the day-wide time bands this method
  /// prints) make its ordering different enough that composing it from this list would need more
  /// conditionals than just calling the same builders itself does.
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
    required List<OcptCallSheetDayRow> rows,
    required List<OcptCallSheetCrewContact> crewContacts,
    required Set<OcptCrewDepartment> contactDepartments,
    required List<OcptLocation> locations,
    required List<OcptShootingDayEvent> events,
    required OcptSchedulePlanSnapshot plan,
  }) => [
    OcptCallSheetHeaderSections.titleBlock(
      painter: painter,
      projectName: projectName,
      labels: labels,
      versionLine: versionLine,
    ),
    pw.SizedBox(height: 10),
    OcptCallSheetHeaderSections.contactsBlock(
      painter: painter,
      labels: labels,
      crewContacts: crewContacts,
      departments: contactDepartments,
    ),
    pw.SizedBox(height: 10),
    OcptCallSheetTableSections.timeBandsSection(
      painter: painter,
      labels: labels,
      slots: slots,
      timelines: timelines,
      convocations: convocations,
      orderedEntries: orderedEntries,
    ),
    pw.SizedBox(height: 10),
    if (events.isNotEmpty) ...[
      OcptCallSheetHeaderSections.eventsSection(painter: painter, labels: labels, events: events),
      pw.SizedBox(height: 10),
    ],
    OcptCallSheetHeaderSections.dayHeadingSection(painter: painter, labels: labels, day: day),
    pw.SizedBox(height: 10),
    if (day.crewNote.trim().isNotEmpty) ...[
      OcptCallSheetHeaderSections.crewNoteSection(
        painter: painter,
        labels: labels,
        note: day.crewNote,
      ),
      pw.SizedBox(height: 10),
    ],
    OcptCallSheetHeaderSections.locationSection(
      painter: painter,
      labels: labels,
      locations: locations,
    ),
    pw.SizedBox(height: 10),
    OcptCallSheetHeaderSections.sunSection(
      painter: painter,
      labels: labels,
      sunTimes: plan.sunTimesOfDay(day.id),
    ),
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
  /// `build:`, and it matters exactly when a sheet does run long: a `build:` child is drawn
  /// **once**, where a `header:` is drawn on every physical page the flow lands on. A call sheet
  /// whose cast table and two directories push it onto a second page was handing that page over
  /// naming no project and no document at all — the same fix
  /// `OcptShootingPlanPageParts.runningHead` carries for the same reason, a sheet being read one
  /// page at a time whatever it was stapled to.
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
          style: pw.TextStyle(
            font: painter.fonts.regular,
            fontSize: ocptCallSheetSmallFontSizePt,
            color: ocptCallSheetMutedColor,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Divider(color: ocptCallSheetRuleColor, thickness: 0.5, height: 6),
      ],
    ),
    build: (context) => [pw.SizedBox(height: 6), ...children],
  );
}

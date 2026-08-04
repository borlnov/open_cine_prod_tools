// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shot_list_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_resources_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_day_part_slot.dart';
import 'package:open_cine_prod_tools/types/ocpt_elements_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_locations_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_people_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_roles_xlsx_column.dart';
import 'package:open_cine_prod_tools/utils/ocpt_weekday_mask.dart';

/// Renders a whole resources catalogue into the bytes of an XLSX workbook, one sheet per tab.
///
/// This is pure in-memory workbook building with no I/O of its own (no dialog, no file system
/// access): it's owned by `OcptExportManager` and exposed as a public final field, reached through
/// the manager rather than through `globalGetIt()` (RFL18), exactly like
/// `OcptShotListXlsxExportService`.
///
/// The **locations & sets sheet writes one row per set**, the location's own columns repeated on
/// each of its rows and a location with no set still getting one row with the set columns empty:
/// that is what makes the sheet filterable and sortable by a set's own city, permit status or
/// scenes, which a nested "location → sets" shape could never offer a spreadsheet's own sort/filter
/// tools. The other three sheets write one row per record, every column of it always written,
/// whichever card the person/role/element sheet happens to show at once — the workbook is what
/// leaves the app.
class OcptResourcesXlsxExportService {
  /// The sheet name used when the caller's own [OcptResourcesXlsxLabels.peopleSheetName] is blank.
  static const fallbackPeopleSheetName = "People";

  /// The sheet name used when the caller's own [OcptResourcesXlsxLabels.rolesSheetName] is blank.
  static const fallbackRolesSheetName = "Roles";

  /// The sheet name used when the caller's own [OcptResourcesXlsxLabels.locationsSheetName] is
  /// blank.
  static const fallbackLocationsSheetName = "Locations";

  /// The sheet name used when the caller's own [OcptResourcesXlsxLabels.elementsSheetName] is
  /// blank.
  static const fallbackElementsSheetName = "Elements";

  /// Class constructor
  const OcptResourcesXlsxExportService();

  /// The `.xlsx` file name to suggest when exporting the resources catalogue of the project named
  /// [projectName], with [suffix] appended so it can never collide with the shot list workbook's
  /// own name (`"$projectName.xlsx"`), mirroring `OcptScenarioCoveragePdfService.coverageFileName`.
  String xlsxFileName({required String projectName, required String suffix}) {
    final trimmedSuffix = suffix.trim();
    final extension = OcptShotListXlsxExportService.xlsxFileExtension;

    return trimmedSuffix.isEmpty
        ? "$projectName.$extension"
        : "$projectName - $trimmedSuffix.$extension";
  }

  /// Builds the workbook holding [snapshot]'s whole resources catalogue, titled and headed with
  /// [labels], and returns its bytes.
  ///
  /// Throws a [StateError] if the workbook cannot be encoded, which the caller reports as a failed
  /// export: `excel_community` returns null there rather than throwing anything of its own.
  Uint8List generate({
    required OcptResourcesSnapshot snapshot,
    required OcptResourcesXlsxLabels labels,
  }) {
    final excel = Excel.createExcel();
    final peopleSheetName = _sheetNameOr(labels.peopleSheetName, fallbackPeopleSheetName);
    _renameDefaultSheet(excel, peopleSheetName);

    final peopleById = {for (final person in snapshot.people) person.id: person};
    final roleNamesByPersonId = _roleNamesByPersonId(snapshot.roles);

    final peopleSheet = excel[peopleSheetName];
    _appendHeaderRow(peopleSheet, OcptPeopleXlsxColumn.values, labels.peopleHeaderOf);
    for (final person in snapshot.people) {
      peopleSheet.appendRow([
        for (final column in OcptPeopleXlsxColumn.values)
          _personCellOf(
            column: column,
            person: person,
            labels: labels,
            roleNames: roleNamesByPersonId[person.id] ?? const [],
          ),
      ]);
    }

    final rolesSheet = excel[_sheetNameOr(labels.rolesSheetName, fallbackRolesSheetName)];
    _appendHeaderRow(rolesSheet, OcptRolesXlsxColumn.values, labels.rolesHeaderOf);
    for (final role in snapshot.roles) {
      rolesSheet.appendRow([
        for (final column in OcptRolesXlsxColumn.values)
          _roleCellOf(
            column: column,
            role: role,
            castMember: role.personId == null ? null : peopleById[role.personId],
            labels: labels,
          ),
      ]);
    }

    final locationsSheet =
        excel[_sheetNameOr(labels.locationsSheetName, fallbackLocationsSheetName)];
    _appendHeaderRow(locationsSheet, OcptLocationsXlsxColumn.values, labels.locationsHeaderOf);
    for (final location in snapshot.locations) {
      final contact = location.contactPersonId == null
          ? null
          : peopleById[location.contactPersonId];
      final sets = location.sets;
      if (sets.isEmpty) {
        locationsSheet.appendRow([
          for (final column in OcptLocationsXlsxColumn.values)
            _locationCellOf(
              column: column,
              location: location,
              set: null,
              contact: contact,
              labels: labels,
            ),
        ]);
      } else {
        for (final set in sets) {
          locationsSheet.appendRow([
            for (final column in OcptLocationsXlsxColumn.values)
              _locationCellOf(
                column: column,
                location: location,
                set: set,
                contact: contact,
                labels: labels,
              ),
          ]);
        }
      }
    }

    final elementsSheet = excel[_sheetNameOr(labels.elementsSheetName, fallbackElementsSheetName)];
    _appendHeaderRow(elementsSheet, OcptElementsXlsxColumn.values, labels.elementsHeaderOf);
    for (final element in snapshot.elements) {
      final owner = element.ownerPersonId == null ? null : peopleById[element.ownerPersonId];
      final bringer = element.broughtByPersonId == null
          ? null
          : peopleById[element.broughtByPersonId];
      elementsSheet.appendRow([
        for (final column in OcptElementsXlsxColumn.values)
          _elementCellOf(
            column: column,
            element: element,
            owner: owner,
            bringer: bringer,
            labels: labels,
          ),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError("The resources workbook could not be encoded");
    }

    return Uint8List.fromList(bytes);
  }

  /// [name] if it holds anything other than whitespace, [fallback] otherwise.
  String _sheetNameOr(String name, String fallback) => name.trim().isEmpty ? fallback : name;

  /// Renames the sheet [Excel.createExcel] starts from to [sheetName], so the workbook doesn't end
  /// up with the named sheet plus an empty `Sheet1` next to it. A no-op when the default sheet
  /// already carries that name.
  void _renameDefaultSheet(Excel excel, String sheetName) {
    final defaultSheetName = excel.getDefaultSheet();
    if (defaultSheetName == null || defaultSheetName == sheetName) {
      return;
    }

    excel.rename(defaultSheetName, sheetName);
  }

  /// Appends [sheet]'s single header row, one cell per value of [columns], and emboldens it.
  void _appendHeaderRow<T>(Sheet sheet, List<T> columns, String Function(T column) headerOf) {
    final headerRowIndex = sheet.maxRows;
    sheet.appendRow([for (final column in columns) TextCellValue(headerOf(column))]);

    for (var columnIndex = 0; columnIndex < columns.length; columnIndex++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: columnIndex, rowIndex: headerRowIndex))
          .cellStyle = CellStyle(
        bold: true,
      );
    }
  }

  /// Every role's name of [roles], grouped by its cast member's person id — a person may hold
  /// several roles, and an uncast role contributes to nobody's row.
  Map<String, List<String>> _roleNamesByPersonId(List<OcptRole> roles) {
    final result = <String, List<String>>{};
    for (final role in roles) {
      final personId = role.personId;
      if (personId == null) {
        continue;
      }
      (result[personId] ??= []).add(role.name);
    }
    return result;
  }

  /// The cell [column] holds for [person], or null to leave it empty.
  CellValue? _personCellOf({
    required OcptPeopleXlsxColumn column,
    required OcptPerson person,
    required OcptResourcesXlsxLabels labels,
    required List<String> roleNames,
  }) => switch (column) {
    OcptPeopleXlsxColumn.name => _textOrNull(person.displayName),
    OcptPeopleXlsxColumn.positions => _textOrNull(_positionsTextOf(person: person, labels: labels)),
    OcptPeopleXlsxColumn.roles => _textOrNull(roleNames.join(", ")),
    OcptPeopleXlsxColumn.email => _textOrNull(person.email),
    OcptPeopleXlsxColumn.phone => _textOrNull(person.phone),
    OcptPeopleXlsxColumn.addressLine1 => _textOrNull(person.addressLine1),
    OcptPeopleXlsxColumn.addressLine2 => _textOrNull(person.addressLine2),
    OcptPeopleXlsxColumn.postalCode => _textOrNull(person.postalCode),
    OcptPeopleXlsxColumn.city => _textOrNull(person.city),
    OcptPeopleXlsxColumn.region => _textOrNull(person.region),
    OcptPeopleXlsxColumn.country => _textOrNull(person.country),
    OcptPeopleXlsxColumn.birthDate => switch (person.birthDate) {
      final date? => DateCellValue.fromDateTime(date),
      null => null,
    },
    OcptPeopleXlsxColumn.age => switch (person.age) {
      final age? => IntCellValue(age),
      null => null,
    },
    OcptPeopleXlsxColumn.minorNotes => _textOrNull(person.minorNotes),
    OcptPeopleXlsxColumn.transportAutonomy => switch (person.isTransportAutonomous) {
      final value? => BoolCellValue(value),
      null => null,
    },
    OcptPeopleXlsxColumn.accommodationNotes => _textOrNull(person.accommodationNotes),
    OcptPeopleXlsxColumn.travelNotes => _textOrNull(person.travelNotes),
    OcptPeopleXlsxColumn.dietaryNotes => _textOrNull(person.dietaryNotes),
    OcptPeopleXlsxColumn.allergies => _textOrNull(person.allergies),
    OcptPeopleXlsxColumn.skills => _textOrNull(
      person.skills.map((skill) => skill.label).join(", "),
    ),
    OcptPeopleXlsxColumn.height => _textOrNull(person.measurementHeight),
    OcptPeopleXlsxColumn.chest => _textOrNull(person.measurementChest),
    OcptPeopleXlsxColumn.waist => _textOrNull(person.measurementWaist),
    OcptPeopleXlsxColumn.hips => _textOrNull(person.measurementHips),
    OcptPeopleXlsxColumn.topSize => _textOrNull(person.sizeTop),
    OcptPeopleXlsxColumn.bottomSize => _textOrNull(person.sizeBottom),
    OcptPeopleXlsxColumn.shoeSize => _textOrNull(person.sizeShoes),
    OcptPeopleXlsxColumn.hmcNotes => _textOrNull(person.hmcNotes),
    OcptPeopleXlsxColumn.imageRightsStatus => _textOrNull(
      labels.imageRightsStatusLabelOf(person.imageRightsStatus),
    ),
    OcptPeopleXlsxColumn.imageRightsDate => switch (person.imageRightsDate) {
      final date? => DateCellValue.fromDateTime(date),
      null => null,
    },
    OcptPeopleXlsxColumn.unavailabilities => _textOrNull(
      _unavailabilitiesTextOf(person: person, labels: labels),
    ),
    OcptPeopleXlsxColumn.notes => _textOrNull(person.notes),
  };

  /// The text [person]'s crew positions read as in one cell: each assignment's own label — the
  /// catalogue's localized one when it names a stable position, the free label otherwise — joined
  /// with " · ", mirroring how the person sheet itself joins them.
  String _positionsTextOf({required OcptPerson person, required OcptResourcesXlsxLabels labels}) =>
      person.positions
          .map(
            (position) => position.positionId.isEmpty
                ? position.customLabel
                : labels.crewPositionLabelOf(position.positionId),
          )
          .join(" · ");

  /// The text [person]'s unavailabilities read as in one cell: one description per row — its date
  /// range, its slot (with a custom window's own hours) and, when given, its reason — joined into
  /// the single cell the sheet has room for.
  String _unavailabilitiesTextOf({
    required OcptPerson person,
    required OcptResourcesXlsxLabels labels,
  }) => person.unavailabilities
      .map((unavailability) {
        final parts = [
          _dateRangeOf(unavailability.startDate, unavailability.endDate),
          _slotTextOf(
            slot: unavailability.slot,
            startMinute: unavailability.startMinute,
            endMinute: unavailability.endMinute,
            labels: labels,
          ),
          if (unavailability.reason.trim().isNotEmpty) unavailability.reason.trim(),
        ];
        return parts.join(" · ");
      })
      .join("; ");

  /// The cell [column] holds for [role], or null to leave it empty.
  CellValue? _roleCellOf({
    required OcptRolesXlsxColumn column,
    required OcptRole role,
    required OcptPerson? castMember,
    required OcptResourcesXlsxLabels labels,
  }) => switch (column) {
    OcptRolesXlsxColumn.number => IntCellValue(role.number),
    OcptRolesXlsxColumn.name => _textOrNull(role.name),
    OcptRolesXlsxColumn.kind => _textOrNull(labels.roleKindLabelOf(role.kind)),
    OcptRolesXlsxColumn.castMember => _textOrNull(castMember?.displayName),
    OcptRolesXlsxColumn.fromScreenplay => BoolCellValue(role.isFromScreenplay),
    OcptRolesXlsxColumn.removedFromScreenplay => BoolCellValue(role.orphanedName != null),
    OcptRolesXlsxColumn.castingNotes => _textOrNull(role.castingNotes),
  };

  /// The cell [column] holds for [location]'s row of [set] (null on its no-set row), or null to
  /// leave it empty.
  CellValue? _locationCellOf({
    required OcptLocationsXlsxColumn column,
    required OcptLocation location,
    required OcptSet? set,
    required OcptPerson? contact,
    required OcptResourcesXlsxLabels labels,
  }) => switch (column) {
    OcptLocationsXlsxColumn.locationName => _textOrNull(location.name),
    OcptLocationsXlsxColumn.setCode => _textOrNull(set?.code),
    OcptLocationsXlsxColumn.setName => _textOrNull(set?.name),
    OcptLocationsXlsxColumn.setScenes => _textOrNull(
      set == null ? null : _joinSceneLabels(labels: labels, sceneIds: set.sceneIds),
    ),
    OcptLocationsXlsxColumn.addressLine1 => _textOrNull(location.addressLine1),
    OcptLocationsXlsxColumn.addressLine2 => _textOrNull(location.addressLine2),
    OcptLocationsXlsxColumn.postalCode => _textOrNull(location.postalCode),
    OcptLocationsXlsxColumn.city => _textOrNull(location.city),
    OcptLocationsXlsxColumn.region => _textOrNull(location.region),
    OcptLocationsXlsxColumn.country => _textOrNull(location.country),
    OcptLocationsXlsxColumn.latitude => switch (location.latitude) {
      final value? => DoubleCellValue(value),
      null => null,
    },
    OcptLocationsXlsxColumn.longitude => switch (location.longitude) {
      final value? => DoubleCellValue(value),
      null => null,
    },
    OcptLocationsXlsxColumn.contact => _textOrNull(contact?.displayName),
    OcptLocationsXlsxColumn.contactNotes => _textOrNull(location.contactNotes),
    OcptLocationsXlsxColumn.permitStatus => _textOrNull(
      labels.permitStatusLabelOf(location.permitStatus),
    ),
    OcptLocationsXlsxColumn.permitLabel => _textOrNull(location.permitLabel),
    OcptLocationsXlsxColumn.permitDate => switch (location.permitDate) {
      final date? => DateCellValue.fromDateTime(date),
      null => null,
    },
    OcptLocationsXlsxColumn.availabilityWindows => _textOrNull(
      _availabilityWindowsTextOf(location: location, labels: labels),
    ),
    OcptLocationsXlsxColumn.parkingNotes => _textOrNull(location.parkingNotes),
    OcptLocationsXlsxColumn.powerNotes => _textOrNull(location.powerNotes),
    OcptLocationsXlsxColumn.facilitiesNotes => _textOrNull(location.facilitiesNotes),
    OcptLocationsXlsxColumn.constraintsNotes => _textOrNull(location.constraintsNotes),
    OcptLocationsXlsxColumn.notes => _textOrNull(location.notes),
  };

  /// The text [location]'s availability windows read as in one cell: one description per window —
  /// its date range, the days of the week it covers within it, its slot (with a custom window's own
  /// hours), whether it is free or conditional, and, when given, its note — joined into the single
  /// cell the sheet has room for.
  String _availabilityWindowsTextOf({
    required OcptLocation location,
    required OcptResourcesXlsxLabels labels,
  }) => location.availabilities
      .map((availability) {
        final parts = [
          _dateRangeOf(availability.startDate, availability.endDate),
          _weekdaysTextOf(mask: availability.weekdays, labels: labels),
          _slotTextOf(
            slot: availability.slot,
            startMinute: availability.startMinute,
            endMinute: availability.endMinute,
            labels: labels,
          ),
          labels.availabilityKindLabelOf(availability.kind),
          if (availability.note.trim().isNotEmpty) availability.note.trim(),
        ];
        return parts.join(" · ");
      })
      .join("; ");

  /// The days of the week [mask] covers, named through [labels]: the one word
  /// [OcptResourcesXlsxLabels.everyDayLabel] when it narrows the range to nothing in particular,
  /// the covered days' own names in `DateTime`'s order otherwise.
  ///
  /// Naming them rather than saying "some days" is the difference between a cell a crew can act on
  /// and one that sends them back to the app: a window is only ever read here to know whether a
  /// given day may be shot in.
  String _weekdaysTextOf({required int mask, required OcptResourcesXlsxLabels labels}) {
    if (ocptWeekdayMaskCoversEveryDay(mask)) {
      return labels.everyDayLabel;
    }

    return [
      for (final weekday in ocptWeekdays)
        if (ocptWeekdayMaskContains(mask, weekday)) labels.weekdayLabelOf(weekday),
    ].where((label) => label.isNotEmpty).join(", ");
  }

  /// The scenes named by [sceneIds], through [labels], joined for a set's own column.
  String _joinSceneLabels({
    required OcptResourcesXlsxLabels labels,
    required List<String> sceneIds,
  }) => sceneIds.map(labels.sceneLabelOf).where((label) => label.isNotEmpty).join(", ");

  /// The cell [column] holds for [element], or null to leave it empty.
  CellValue? _elementCellOf({
    required OcptElementsXlsxColumn column,
    required OcptElement element,
    required OcptPerson? owner,
    required OcptPerson? bringer,
    required OcptResourcesXlsxLabels labels,
  }) => switch (column) {
    OcptElementsXlsxColumn.category => _textOrNull(labels.elementCategoryLabelOf(element.category)),
    OcptElementsXlsxColumn.subCategory => _textOrNull(element.subCategory),
    OcptElementsXlsxColumn.code => _textOrNull(element.code),
    OcptElementsXlsxColumn.name => _textOrNull(element.name),
    OcptElementsXlsxColumn.quantity => _textOrNull(element.quantity),
    OcptElementsXlsxColumn.sourceKind => _textOrNull(
      labels.elementSourceKindLabelOf(element.sourceKind),
    ),
    // The owner reads as the person's own display name when there is one; a person is only ever
    // absent when `ownerPersonId` is null (an organisation, said in `ownerNotes` alone) or names a
    // person the address book no longer holds, and both read the same way here.
    OcptElementsXlsxColumn.owner => _textOrNull(owner?.displayName ?? element.ownerNotes),
    OcptElementsXlsxColumn.ownerNotes => _textOrNull(element.ownerNotes),
    OcptElementsXlsxColumn.broughtBy => _textOrNull(bringer?.displayName),
    OcptElementsXlsxColumn.storageNotes => _textOrNull(element.storageNotes),
    OcptElementsXlsxColumn.secured => BoolCellValue(element.isSecured),
    OcptElementsXlsxColumn.ready => BoolCellValue(element.isReadyForShoot),
    OcptElementsXlsxColumn.returned => BoolCellValue(element.isReturned),
    OcptElementsXlsxColumn.trackingStatus => _textOrNull(labels.elementTrackingLabelOf(element)),
    OcptElementsXlsxColumn.cost => switch (element.cost) {
      final cents? => DoubleCellValue(cents / 100),
      null => null,
    },
    OcptElementsXlsxColumn.scenes => _textOrNull(
      _sceneLinksTextOf(element: element, labels: labels),
    ),
    OcptElementsXlsxColumn.purposeNotes => _textOrNull(element.purposeNotes),
    OcptElementsXlsxColumn.notes => _textOrNull(element.notes),
  };

  /// The text [element]'s scene links read as in one cell: each scene's own label, with its
  /// quantity and notes for that scene alone in parentheses when either is given, joined into the
  /// single cell the sheet has room for.
  String _sceneLinksTextOf({
    required OcptElement element,
    required OcptResourcesXlsxLabels labels,
  }) => element.sceneLinks
      .map((link) {
        final label = labels.sceneLabelOf(link.sceneId);
        final suffixParts = [
          if (link.quantity.trim().isNotEmpty) link.quantity.trim(),
          if (link.notes.trim().isNotEmpty) link.notes.trim(),
        ];
        return suffixParts.isEmpty ? label : "$label (${suffixParts.join(", ")})";
      })
      .join("; ");

  /// [startDate]–[endDate], or just [startDate] when the range is a single day.
  String _dateRangeOf(DateTime startDate, DateTime endDate) {
    final isSameDay =
        startDate.year == endDate.year &&
        startDate.month == endDate.month &&
        startDate.day == endDate.day;

    return isSameDay ? _isoDate(startDate) : "${_isoDate(startDate)}–${_isoDate(endDate)}";
  }

  /// The label of [slot], with [startMinute]–[endMinute] appended when [slot] is
  /// [OcptDayPartSlot.custom].
  String _slotTextOf({
    required OcptDayPartSlot slot,
    required int? startMinute,
    required int? endMinute,
    required OcptResourcesXlsxLabels labels,
  }) {
    final label = labels.dayPartSlotLabelOf(slot);
    if (slot != OcptDayPartSlot.custom || startMinute == null || endMinute == null) {
      return label;
    }

    return "$label (${_hoursOf(startMinute)}–${_hoursOf(endMinute)})";
  }

  /// [date] as `yyyy-MM-dd`: unambiguous and locale-free, for the composite summary cells that
  /// otherwise have no `Tr` (or even a locale) to format a date with.
  String _isoDate(DateTime date) =>
      "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-"
      "${date.day.toString().padLeft(2, '0')}";

  /// [minutesFromMidnight] as `HH:mm`.
  String _hoursOf(int minutesFromMidnight) =>
      "${(minutesFromMidnight ~/ 60).toString().padLeft(2, '0')}:"
      "${(minutesFromMidnight % 60).toString().padLeft(2, '0')}";

  /// A text cell holding [value], or null when it is null or holds nothing but whitespace.
  CellValue? _textOrNull(String? value) =>
      value == null || value.trim().isEmpty ? null : TextCellValue(value);
}

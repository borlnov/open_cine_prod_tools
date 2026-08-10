// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:excel_community/excel_community.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_export_file_name.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_shot_list_xlsx_export_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_snapshot.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_target.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_entries_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scenes_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_scene_bars.dart';

/// Renders a project's whole breakdown into the bytes of an XLSX workbook: a `Scenes` sheet, one
/// row per scene, and a `Breakdown` sheet, one row per **distinct** target tagged in a scene — the
/// long, filterable format the mode's own recap cross-table cannot be, since a target tagged in
/// three scenes is three rows there rather than one row with three columns lit up. "Distinct"
/// matters: a target tagged twice in the same scene is still one row, exactly as
/// `ocptBreakdownSceneTargetsOf` counts it for the scene panel's bars and its `N elements` count,
/// and as the `Scenes` sheet's own `neededCount` column counts it too — a per-tag row would make
/// that figure disagree with a `COUNTIF` over this very sheet, in the same workbook.
///
/// This is pure in-memory workbook building with no I/O of its own (no dialog, no file system
/// access): it's owned by `OcptExportManager` and exposed as a public final field, reached through
/// the manager rather than through `globalGetIt()` (RFL18), exactly like `OcptResourcesXlsxExportService`
/// and `OcptShotListXlsxExportService`. Unlike the breakdown sheets PDF, it takes no options: the
/// export panel's card goes straight to the native save dialog.
///
/// `document` is read for one thing only, each scene's own length in page eighths — the same figure
/// `OcptBreakdownSheetsPdfService`'s meta band prints — exactly as that service reads it, and for
/// the same reason: a scene whose position no longer names a scene of `document` (an index rebuilt
/// since, or a snapshot from a version captured against another text) simply writes no length rather
/// than a wrong one.
class OcptBreakdownXlsxExportService {
  /// The sheet name used when the caller's own [OcptBreakdownXlsxLabels.scenesSheetName] is blank.
  static const fallbackScenesSheetName = "Scenes";

  /// The sheet name used when the caller's own [OcptBreakdownXlsxLabels.entriesSheetName] is blank.
  static const fallbackEntriesSheetName = "Breakdown";

  /// Class constructor
  const OcptBreakdownXlsxExportService();

  /// The `.xlsx` file name to suggest when exporting the breakdown of the project named
  /// [projectName], with [suffix] appended, mirroring `OcptResourcesXlsxExportService.xlsxFileName`.
  /// [episodeTag] is the selected episode's own tag, present only while the open project holds more
  /// than one episode — see `ocptExportFileNameOf`'s own doc comment.
  String xlsxFileName({required String projectName, required String suffix, String? episodeTag}) =>
      ocptExportFileNameOf(
        projectName: projectName,
        suffix: suffix,
        episodeTag: episodeTag,
        extension: OcptShotListXlsxExportService.xlsxFileExtension,
      );

  /// Builds the workbook holding [snapshot]'s whole breakdown, titled and headed with [labels], and
  /// returns its bytes.
  ///
  /// [pageSetup] supplies the page geometry each scene's own length in eighths is measured against
  /// — see this class' own doc comment.
  ///
  /// Throws a [StateError] if the workbook cannot be encoded, which the caller reports as a failed
  /// export: `excel_community` returns null there rather than throwing anything of its own.
  Uint8List generate({
    required FountainDocument document,
    required OcptBreakdownSnapshot snapshot,
    required OcptPageSetup pageSetup,
    required OcptBreakdownXlsxLabels labels,
  }) {
    final excel = Excel.createExcel();
    final scenesSheetName = _sheetNameOr(labels.scenesSheetName, fallbackScenesSheetName);
    _renameDefaultSheet(excel, scenesSheetName);

    final metrics = pageSetup.toMetrics();
    final targetById = ocptBreakdownTargetsById(snapshot.targets);
    final locationNameById = snapshot.locationNameById;

    final scenesSheet = excel[scenesSheetName];
    _appendHeaderRow(scenesSheet, OcptBreakdownScenesXlsxColumn.values, labels.scenesHeaderOf);
    for (final scene in snapshot.scenes) {
      scenesSheet.appendRow([
        for (final column in OcptBreakdownScenesXlsxColumn.values)
          _sceneCellOf(
            column: column,
            scene: scene,
            document: document,
            metrics: metrics,
            sets: snapshot.sets,
            locationNameById: locationNameById,
            targetById: targetById,
            labels: labels,
          ),
      ]);
    }

    final elementById = {for (final element in snapshot.elements) element.id: element};
    final roleById = {for (final role in snapshot.roles) role.id: role};
    final setById = {for (final set in snapshot.sets) set.id: set};
    final personById = {for (final person in snapshot.people) person.id: person};

    final entriesSheetName = _sheetNameOr(labels.entriesSheetName, fallbackEntriesSheetName);
    final entriesSheet = excel[entriesSheetName];
    _appendHeaderRow(entriesSheet, OcptBreakdownEntriesXlsxColumn.values, labels.entriesHeaderOf);
    for (final scene in snapshot.scenes) {
      // `ocptBreakdownSceneTargetsOf` is what the `Scenes` sheet's own `neededCount` and the scene
      // panel's bars already count by: one entry per distinct target, a tag whose catalogue row has
      // been tombstoned underneath silently resolving to nothing (its own doc comment) rather than
      // a guard this loop would otherwise need to repeat.
      for (final target in ocptBreakdownSceneTargetsOf(scene, targetById)) {
        entriesSheet.appendRow([
          for (final column in OcptBreakdownEntriesXlsxColumn.values)
            _entryCellOf(
              column: column,
              scene: scene,
              target: target,
              element: elementById[target.id],
              role: roleById[target.id],
              set: setById[target.id],
              personById: personById,
              labels: labels,
            ),
        ]);
      }
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError("The breakdown workbook could not be encoded");
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
          .cellStyle = CellStyle(bold: true);
    }
  }

  /// The cell [column] holds for [scene]'s own row of the `Scenes` sheet, or null to leave it
  /// empty.
  CellValue? _sceneCellOf({
    required OcptBreakdownScenesXlsxColumn column,
    required OcptBreakdownScene scene,
    required FountainDocument document,
    required FountainLayoutMetrics metrics,
    required List<OcptSet> sets,
    required Map<String, String> locationNameById,
    required OcptBreakdownTargetsById targetById,
    required OcptBreakdownXlsxLabels labels,
  }) => switch (column) {
    OcptBreakdownScenesXlsxColumn.number => TextCellValue(scene.displayNumber),
    OcptBreakdownScenesXlsxColumn.heading => _textOrNull(scene.heading),
    OcptBreakdownScenesXlsxColumn.status => _textOrNull(labels.sceneStatusLabelOf(scene.status)),
    OcptBreakdownScenesXlsxColumn.length => _sceneLengthCellOf(
      scene: scene,
      document: document,
      metrics: metrics,
    ),
    OcptBreakdownScenesXlsxColumn.sets => _textOrNull(
      _linkedSetsTextOf(scene: scene, sets: sets, locationNameById: locationNameById),
    ),
    OcptBreakdownScenesXlsxColumn.neededCount => IntCellValue(
      ocptBreakdownSceneTargetsOf(scene, targetById).length,
    ),
    OcptBreakdownScenesXlsxColumn.notes => _textOrNull(scene.notes),
  };

  /// The sets [sets] holding [scene]'s own id among their own `sceneIds`, named `<set> · <location>`
  /// and joined — the scene inspector's own sets row, read here rather than through
  /// `ocptBreakdownSetLabel` (`lib/ui/utils/`, out of reach from the manager layer this service sits
  /// in) so the composition is inlined instead, mirroring
  /// `OcptResourcesXlsxExportService._isoDate`'s own doc comment for why.
  String _linkedSetsTextOf({
    required OcptBreakdownScene scene,
    required List<OcptSet> sets,
    required Map<String, String> locationNameById,
  }) => sets
      .where((set) => set.sceneIds.contains(scene.id))
      .map((set) => _setLabelOf(set, locationNameById))
      .join(", ");

  /// [set] named `<set> · <location>`, or just [OcptSet.name] when [locationNameById] holds no
  /// name for it — mirroring `ocptBreakdownSetLabel`'s own doc comment.
  String _setLabelOf(OcptSet set, Map<String, String> locationNameById) {
    final locationName = locationNameById[set.locationId];

    return locationName == null || locationName.isEmpty ? set.name : "${set.name} · $locationName";
  }

  /// The scene's length, in the eighths notation assistant directors write on a breakdown sheet:
  /// `5/8` under a page, `2` on two whole pages, `1 4/8` in between — mirroring
  /// `OcptBreakdownSheetsPdfService._sceneLengthOf`, returning null in place of its own placeholder
  /// dash: a spreadsheet's own way of saying "nothing here" is a blank cell.
  CellValue? _sceneLengthCellOf({
    required OcptBreakdownScene scene,
    required FountainDocument document,
    required FountainLayoutMetrics metrics,
  }) {
    if (scene.position < 0 || scene.position >= document.scenes.length) {
      return null;
    }

    final pageEighths = FountainSceneStatistics.of(document, metrics, scene.position).pageEighths;
    final whole = pageEighths ~/ 8;
    final eighths = pageEighths % 8;

    if (eighths == 0) {
      return TextCellValue("$whole");
    }

    return TextCellValue(whole == 0 ? "$eighths/8" : "$whole $eighths/8");
  }

  /// The cell [column] holds for [target]'s own row of the `Breakdown` sheet, scoped to [scene] —
  /// one row per **distinct** target, see this class' own doc comment for why.
  ///
  /// [element]/[role]/[set] are the target's own row resolved by [target]'s id against whichever of
  /// the snapshot's three catalogues [target]'s own `kind` names — at most one of the three is ever
  /// non-null — and are what an element's own code, owner, quantity and notes are read from; a
  /// role's code is its own number and a set's its own `code`, both read straight off [role]/[set]
  /// since neither is an [OcptBreakdownTarget] field.
  CellValue? _entryCellOf({
    required OcptBreakdownEntriesXlsxColumn column,
    required OcptBreakdownScene scene,
    required OcptBreakdownTarget target,
    required OcptElement? element,
    required OcptRole? role,
    required OcptSet? set,
    required Map<String, OcptPerson> personById,
    required OcptBreakdownXlsxLabels labels,
  }) => switch (column) {
    OcptBreakdownEntriesXlsxColumn.sceneNumber => TextCellValue(scene.displayNumber),
    OcptBreakdownEntriesXlsxColumn.sceneHeading => _textOrNull(scene.heading),
    OcptBreakdownEntriesXlsxColumn.group => _textOrNull(
      labels.groupLabelOf(kind: target.kind, category: target.category),
    ),
    OcptBreakdownEntriesXlsxColumn.code => _textOrNull(
      _codeOf(kind: target.kind, element: element, role: role, set: set),
    ),
    OcptBreakdownEntriesXlsxColumn.name => _textOrNull(target.name),
    OcptBreakdownEntriesXlsxColumn.status => _textOrNull(
      target.status == null ? null : labels.elementStatusLabelOf(target.status!),
    ),
    OcptBreakdownEntriesXlsxColumn.owner => _textOrNull(
      _ownerNameOf(element: element, personById: personById),
    ),
    OcptBreakdownEntriesXlsxColumn.quantity => _textOrNull(
      _sceneLinkOf(element: element, sceneId: scene.id)?.quantity,
    ),
    OcptBreakdownEntriesXlsxColumn.notes => _textOrNull(
      _sceneLinkOf(element: element, sceneId: scene.id)?.notes,
    ),
    OcptBreakdownEntriesXlsxColumn.passages => _textOrNull(
      _passagesTextOf(scene: scene, target: target),
    ),
  };

  /// The target's own short code: an element's or a set's own `code`, or a role's own number —
  /// neither being an [OcptBreakdownTarget] field, see [_entryCellOf]'s own doc comment.
  String? _codeOf({
    required OcptBreakdownTargetKind kind,
    required OcptElement? element,
    required OcptRole? role,
    required OcptSet? set,
  }) => switch (kind) {
    OcptBreakdownTargetKind.element => element?.code,
    OcptBreakdownTargetKind.role => role == null ? null : "${role.number}",
    OcptBreakdownTargetKind.set => set?.code,
  };

  /// Every passage of [scene] that tags [target], verbatim and joined with `"; "` — the separator
  /// `OcptResourcesXlsxExportService._sceneLinksTextOf` already uses for a composite cell. A target
  /// tagged more than once in the scene therefore reads as more than one passage in this one cell,
  /// which is the whole point of writing one row per distinct target rather than one per tag.
  String _passagesTextOf({required OcptBreakdownScene scene, required OcptBreakdownTarget target}) =>
      scene.tags
          .where((tag) => tag.targetKind == target.kind && tag.targetId == target.id)
          .map((tag) => tag.taggedText)
          .join("; ");

  /// The `scene_elements` link of [element] onto [sceneId], or null while [element] is null (a role
  /// or a set, neither carrying one) or holds no link for that scene.
  _SceneLink? _sceneLinkOf({required OcptElement? element, required String sceneId}) {
    if (element == null) {
      return null;
    }

    for (final link in element.sceneLinks) {
      if (link.sceneId == sceneId) {
        return (quantity: link.quantity, notes: link.notes);
      }
    }

    return null;
  }

  /// The name of [element]'s owner, or null while it has none — a role or a set never has one
  /// ([element] itself is then null), and an element's own `ownerPersonId` may be unset or may name
  /// somebody the address book no longer holds (an erased person, whose row the erasure tombstoned).
  String? _ownerNameOf({required OcptElement? element, required Map<String, OcptPerson> personById}) {
    final ownerPersonId = element?.ownerPersonId;
    if (ownerPersonId == null) {
      return null;
    }

    return personById[ownerPersonId]?.displayName;
  }

  /// A text cell holding [value], or null when it is null or holds nothing but whitespace.
  CellValue? _textOrNull(String? value) =>
      value == null || value.trim().isEmpty ? null : TextCellValue(value);
}

/// The two free-text fields a `scene_elements` link carries for one scene's own need of one
/// element — [OcptBreakdownXlsxExportService._sceneLinkOf]'s own return type, never leaving this
/// file.
typedef _SceneLink = ({String quantity, String notes});

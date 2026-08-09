// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_sheets_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_xlsx_labels.dart';
import 'package:open_cine_prod_tools/models/ocpt_set.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_entries_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scenes_xlsx_column.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_legend.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_scene_bars.dart';

/// The value the "in a new location" entry of a set-creation menu carries, standing for "no
/// location: mint one to hold it".
///
/// A sentinel rather than the null it means: `PopupMenuButton` completes its route with null when
/// the menu is **dismissed**, and calls `onSelected` only for a non-null value — an entry whose
/// value is null is therefore indistinguishable from a click outside the menu, and silently does
/// nothing. The empty string can never be a location id (`Uuid().v4()` never produces one), so it
/// is free to mean this.
const String ocptNewLocationMenuValue = "";

/// The display label of the breakdown status [status], read by the scene panel's own status column.
String ocptBreakdownSceneStatusLabel(Tr tr, OcptBreakdownSceneStatus status) => switch (status) {
  OcptBreakdownSceneStatus.toDo => tr.breakdownSceneStatusToDo,
  OcptBreakdownSceneStatus.inProgress => tr.breakdownSceneStatusInProgress,
  OcptBreakdownSceneStatus.done => tr.breakdownSceneStatusDone,
};

/// The colour the breakdown status [status] is painted with.
///
/// Follows the shot list's own status scale: [OcptBreakdownSceneStatus.toDo] is the neutral one and
/// reads through the colour scheme's own `onSurfaceVariant`, [OcptBreakdownSceneStatus.inProgress]
/// is the workspace's warning colour (a scene that still needs attention), and
/// [OcptBreakdownSceneStatus.done] is the "already shot" green [OcptSpecificColors] carries.
Color ocptBreakdownSceneStatusColor(BuildContext context, OcptBreakdownSceneStatus status) {
  final theme = Theme.of(context);

  return switch (status) {
    OcptBreakdownSceneStatus.toDo => theme.colorScheme.onSurfaceVariant,
    OcptBreakdownSceneStatus.inProgress => ocptWarningColor(context),
    OcptBreakdownSceneStatus.done =>
      theme.extension<OcptSpecificColors>()?.shotStatusShot ?? theme.colorScheme.primary,
  };
}

/// The display label of legend key [key]: an element category's own label
/// ([ocptElementCategoryLabel]), or the fixed role/set label for the other two kinds.
///
/// The single switch every legend-keyed label reads off — the category legend's own rows
/// (`OcptBreakdownCategoryLegend`) and a scene panel bar's tooltip ([ocptBreakdownSceneBarBucketLabel]
/// below) alike — so a category's label is written once.
String ocptBreakdownLegendKeyLabel(Tr tr, OcptBreakdownLegendKey key) => switch (key.$1) {
  OcptBreakdownTargetKind.element => ocptElementCategoryLabel(tr, key.$2!),
  OcptBreakdownTargetKind.role => tr.breakdownTargetKindRoleLabel,
  OcptBreakdownTargetKind.set => tr.breakdownTargetKindSetLabel,
};

/// The tooltip label of a scene panel's bar [bucket]: delegates to [ocptBreakdownLegendKeyLabel]
/// with the bucket's own key.
String ocptBreakdownSceneBarBucketLabel(Tr tr, OcptBreakdownSceneBarBucket bucket) =>
    ocptBreakdownLegendKeyLabel(tr, (bucket.kind, bucket.category));

/// The display label of element status [status], read by the target inspector's status chips and
/// the scene inspector's own status pills.
///
/// Owned by this mode rather than `ocpt_resources_labels.dart`: the resources mode's own element
/// sheet has no status control yet, and gains one — reusing this same label — in a change of its
/// own.
String ocptElementStatusLabel(Tr tr, OcptElementStatus status) => switch (status) {
  OcptElementStatus.toFind => tr.breakdownElementStatusToFind,
  OcptElementStatus.reserved => tr.breakdownElementStatusReserved,
  OcptElementStatus.beingMade => tr.breakdownElementStatusBeingMade,
  OcptElementStatus.confirmed => tr.breakdownElementStatusConfirmed,
};

/// Builds every localized string the exported breakdown sheets carry, for the [scenes] they are
/// being built from.
///
/// The single bridge between the UI's `Tr` and `OcptBreakdownSheetsPdfService`, which runs in the
/// manager layer and has no `BuildContext` to resolve anything of its own — the sibling of
/// `ocptScenarioCoverageLabelsOf` and `ocptResourcesXlsxLabelsOf` for the third export the app
/// offers.
///
/// Almost every string here is a key the mode already shows on screen, resolved through the very
/// same helpers its own widgets call: a printed sheet names a status, a category or a column
/// exactly as the inspector and the recap do. Only what has no on-screen counterpart at all (the
/// document's own name, the length label, the two notes standing in for an empty scene or an empty
/// document, the file name suffix) gets a key of its own. A scene's title is resolved scene by
/// scene, since it takes the scene's display number as a placeholder.
OcptBreakdownSheetsLabels ocptBreakdownSheetsLabelsOf(Tr tr, List<OcptBreakdownScene> scenes) =>
    OcptBreakdownSheetsLabels(
      fileNameSuffix: tr.breakdownExportSheetsFileNameSuffix,
      documentTitle: tr.breakdownExportSheetsDocumentTitle,
      sceneTitles: {
        for (final scene in scenes)
          scene.id: tr.breakdownSceneInspectorTitle(scene.displayNumber),
      },
      statusLabel: tr.breakdownSceneInspectorStatusLabel,
      lengthLabel: tr.breakdownExportSheetsLengthLabel,
      notesLabel: tr.breakdownSceneNotesLabel,
      targetsSectionTitle: tr.breakdownSceneInspectorTargetsSectionTitle,
      toFindSectionTitle: tr.breakdownSceneInspectorToFindLabel,
      nameHeader: tr.breakdownRecapColumnElement,
      statusHeader: tr.breakdownRecapColumnStatus,
      ownerHeader: tr.breakdownRecapColumnOwner,
      sceneStatusLabels: {
        for (final status in OcptBreakdownSceneStatus.values)
          status: ocptBreakdownSceneStatusLabel(tr, status),
      },
      elementStatusLabels: {
        for (final status in OcptElementStatus.values) status: ocptElementStatusLabel(tr, status),
      },
      elementCategoryLabels: {
        for (final category in OcptElementCategory.values)
          category: ocptElementCategoryLabel(tr, category),
      },
      roleGroupLabel: tr.breakdownTargetKindRoleLabel,
      setGroupLabel: tr.breakdownTargetKindSetLabel,
      emptySceneNote: tr.breakdownExportSheetsEmptySceneNote,
      emptyDocumentNote: tr.breakdownExportSheetsEmptyDocumentNote,
    );

/// The colour element status [status] is painted with, following the shot list's own status scale:
/// [OcptElementStatus.toFind] is the neutral one, [OcptElementStatus.reserved] and
/// [OcptElementStatus.beingMade] both read as in-progress work through the workspace's warning
/// colour (reserved is promised, being made is under way — neither is in hand yet), and
/// [OcptElementStatus.confirmed] is the "already shot" green [OcptSpecificColors] carries.
Color ocptElementStatusColor(BuildContext context, OcptElementStatus status) {
  final theme = Theme.of(context);

  return switch (status) {
    OcptElementStatus.toFind => theme.colorScheme.onSurfaceVariant,
    OcptElementStatus.reserved || OcptElementStatus.beingMade => ocptWarningColor(context),
    OcptElementStatus.confirmed =>
      theme.extension<OcptSpecificColors>()?.shotStatusShot ?? theme.colorScheme.primary,
  };
}

/// How a set is named wherever it is shown outside the location sheet that holds it: `Cuisine ·
/// Maison des Martin`.
///
/// A set has no sheet of its own, so its own name is regularly not enough to tell it apart — two
/// houses each having a `Cuisine` is the very case `sets` exists to distinguish. The location is
/// dropped, rather than shown as an empty tail, when [locationNameById] does not name it: a
/// location tombstoned underneath, which the reload that follows will drop the set along with.
String ocptBreakdownSetLabel(OcptSet set, Map<String, String> locationNameById) {
  final locationName = locationNameById[set.locationId];

  return locationName == null || locationName.isEmpty ? set.name : "${set.name} · $locationName";
}

/// The header label of the exported breakdown workbook's `Scenes` sheet's column [column].
String ocptBreakdownScenesXlsxColumnLabel(Tr tr, OcptBreakdownScenesXlsxColumn column) =>
    switch (column) {
      OcptBreakdownScenesXlsxColumn.number => tr.breakdownXlsxScenesColumnNumber,
      OcptBreakdownScenesXlsxColumn.heading => tr.breakdownXlsxScenesColumnHeading,
      OcptBreakdownScenesXlsxColumn.status => tr.breakdownXlsxScenesColumnStatus,
      OcptBreakdownScenesXlsxColumn.length => tr.breakdownXlsxScenesColumnLength,
      OcptBreakdownScenesXlsxColumn.sets => tr.breakdownXlsxScenesColumnSets,
      OcptBreakdownScenesXlsxColumn.neededCount => tr.breakdownXlsxScenesColumnNeededCount,
      OcptBreakdownScenesXlsxColumn.notes => tr.breakdownXlsxScenesColumnNotes,
    };

/// The header label of the exported breakdown workbook's `Breakdown` sheet's column [column].
String ocptBreakdownEntriesXlsxColumnLabel(Tr tr, OcptBreakdownEntriesXlsxColumn column) =>
    switch (column) {
      OcptBreakdownEntriesXlsxColumn.sceneNumber => tr.breakdownXlsxEntriesColumnSceneNumber,
      OcptBreakdownEntriesXlsxColumn.sceneHeading => tr.breakdownXlsxEntriesColumnSceneHeading,
      OcptBreakdownEntriesXlsxColumn.group => tr.breakdownXlsxEntriesColumnGroup,
      OcptBreakdownEntriesXlsxColumn.code => tr.breakdownXlsxEntriesColumnCode,
      OcptBreakdownEntriesXlsxColumn.name => tr.breakdownXlsxEntriesColumnName,
      OcptBreakdownEntriesXlsxColumn.status => tr.breakdownXlsxEntriesColumnStatus,
      OcptBreakdownEntriesXlsxColumn.owner => tr.breakdownXlsxEntriesColumnOwner,
      OcptBreakdownEntriesXlsxColumn.quantity => tr.breakdownXlsxEntriesColumnQuantity,
      OcptBreakdownEntriesXlsxColumn.notes => tr.breakdownXlsxEntriesColumnNotes,
      OcptBreakdownEntriesXlsxColumn.passages => tr.breakdownXlsxEntriesColumnPassages,
    };

/// Builds every localized string the exported breakdown workbook carries.
///
/// The sibling of [ocptBreakdownSheetsLabelsOf] for the second export the breakdown mode offers,
/// and the same single bridge between the UI's `Tr` and `OcptBreakdownXlsxExportService`, which
/// runs in the manager layer and has no `BuildContext` of its own. Every enum label map reuses the
/// very `ocpt…Label` helpers this file already exposes to the mode's own widgets — the status and
/// category maps are exactly [ocptBreakdownSheetsLabelsOf]'s own — so a workbook cell can never
/// name a status or a category differently from the screen or from the breakdown sheets PDF.
OcptBreakdownXlsxLabels ocptBreakdownXlsxLabelsOf(Tr tr) => OcptBreakdownXlsxLabels(
  fileNameSuffix: tr.breakdownExportXlsxFileNameSuffix,
  scenesSheetName: tr.breakdownExportXlsxScenesSheetName,
  entriesSheetName: tr.breakdownExportXlsxEntriesSheetName,
  scenesColumnHeaders: {
    for (final column in OcptBreakdownScenesXlsxColumn.values)
      column: ocptBreakdownScenesXlsxColumnLabel(tr, column),
  },
  entriesColumnHeaders: {
    for (final column in OcptBreakdownEntriesXlsxColumn.values)
      column: ocptBreakdownEntriesXlsxColumnLabel(tr, column),
  },
  sceneStatusLabels: {
    for (final status in OcptBreakdownSceneStatus.values)
      status: ocptBreakdownSceneStatusLabel(tr, status),
  },
  elementStatusLabels: {
    for (final status in OcptElementStatus.values) status: ocptElementStatusLabel(tr, status),
  },
  elementCategoryLabels: {
    for (final category in OcptElementCategory.values)
      category: ocptElementCategoryLabel(tr, category),
  },
  roleGroupLabel: tr.breakdownTargetKindRoleLabel,
  setGroupLabel: tr.breakdownTargetKindSetLabel,
);

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_legend.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_scene_bars.dart';

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

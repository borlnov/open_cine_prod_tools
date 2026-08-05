// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_scene_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';
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

/// The tooltip label of a scene panel's bar [bucket]: an element bucket's category label
/// ([ocptElementCategoryLabel]), or the fixed role/set label for the other two kinds.
String ocptBreakdownSceneBarBucketLabel(Tr tr, OcptBreakdownSceneBarBucket bucket) =>
    switch (bucket.kind) {
      OcptBreakdownTargetKind.element => ocptElementCategoryLabel(tr, bucket.category!),
      OcptBreakdownTargetKind.role => tr.breakdownTargetKindRoleLabel,
      OcptBreakdownTargetKind.set => tr.breakdownTargetKindSetLabel,
    };

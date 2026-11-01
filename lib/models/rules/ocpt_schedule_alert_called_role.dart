// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alerts.dart';

/// One role a placed shot calls for on a given day — the caller's own join of a shot's characters
/// onto the cast, through `fountain_kit`'s `normalizeCharacterName`. This file knows nothing of
/// shots or characters beyond "[roleId] is wanted for [shotId]".
class OcptScheduleAlertCalledRole {
  /// The role a placed shot calls for.
  final String roleId;

  /// The shot that calls for [roleId].
  final String shotId;

  /// Build a called role to feed to [ocptComputeScheduleAlerts].
  const OcptScheduleAlertCalledRole({required this.roleId, required this.shotId});
}

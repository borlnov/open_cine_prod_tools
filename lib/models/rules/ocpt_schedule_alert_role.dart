// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alerts.dart';

/// One role of the cast, reduced to what [OcptScheduleRoleUncastAlert] needs: whether it has an
/// actor.
class OcptScheduleAlertRole extends Equatable {
  /// The role's own id.
  final String id;

  /// The actor cast in this role, or null while it is uncast — `roles.personId` verbatim.
  final String? personId;

  /// Build a role to feed to [ocptComputeScheduleAlerts].
  const OcptScheduleAlertRole({required this.id, required this.personId});

  /// List the fields that decide equality.
  @override
  List<Object?> get props => [id, personId];
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_day_convocation.dart';

/// One row of the day's own cast table.
class OcptCallSheetCastRow {
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

  /// Class constructor
  const OcptCallSheetCastRow({
    required this.role,
    required this.actor,
    required this.sceneNumbers,
    required this.convocation,
  });
}

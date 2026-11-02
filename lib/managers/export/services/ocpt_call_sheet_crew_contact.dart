// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';

/// One crew member's own contact: who they are, what they hold that day, and which department that
/// position belongs to (null for a free-text `OcptShootingSlotCrewMember.customLabel` the catalogue
/// has no department for).
class OcptCallSheetCrewContact {
  /// The person themselves.
  final OcptPerson person;

  /// The label of the position they hold that day — the catalogue's own label, or their own free
  /// text.
  final String positionLabel;

  /// The department [positionLabel] belongs to, or null for a free-text position.
  final OcptCrewDepartment? department;

  /// Class constructor
  const OcptCallSheetCrewContact({
    required this.person,
    required this.positionLabel,
    required this.department,
  });
}

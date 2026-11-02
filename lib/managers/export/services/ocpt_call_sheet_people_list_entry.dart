// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/models/ocpt_call_sheet_labels.dart';

/// One row of the crew list or the cast-and-extras list — the two lists print the same shape, so
/// they share this type.
class OcptCallSheetPeopleListEntry {
  /// The person's own display name, or [OcptCallSheetLabels.unnamedPersonLabel] for an uncast role.
  final String name;

  /// The position(s) they hold, comma-joined, or the role's own number and name.
  final String positionOrRole;

  /// Their own phone number, empty when there is none (an uncast role has nobody's phone to print).
  final String phone;

  /// Their own email address, empty for the same reason.
  final String email;

  /// Their own arrival – departure band, or [ocptScheduleEmptyValue] while they have no convocation
  /// at all.
  final String scheduleLabel;

  /// Class constructor
  const OcptCallSheetPeopleListEntry({
    required this.name,
    required this.positionOrRole,
    required this.phone,
    required this.email,
    required this.scheduleLabel,
  });
}

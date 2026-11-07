// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';

/// One printed row of the day's own audition table: an audition block's resolved hours, the part it
/// sees, and who is being seen for it.
///
/// **One row per candidacy, not per block**: two actors of two different parts read together are
/// two rows sharing one hour (ADR 0024), and a block naming nobody yet is one row carrying its hour
/// alone.
class OcptCallSheetAuditionRow {
  /// Where this audition starts, resolved off the timeline like every other hour on this sheet.
  final int startMinute;

  /// Where it ends, resolved off the same timeline.
  final int endMinute;

  /// The part being seen, as `<number> · <name>` ([ocptScheduleRoleLabelOf]), or null while the
  /// block names nobody — an ordinary state, exactly as a hold with no sequence is — or while the
  /// candidacy names a part the project has since deleted. The caller prints
  /// [ocptScheduleEmptyValue] for it.
  final String? roleLabel;

  /// Who is being seen, or null under the same conditions as [roleLabel]. Their phone number is
  /// deliberately not here: it sits in the day's own candidates directory, where a directory
  /// belongs.
  final String? candidateName;

  /// Class constructor
  const OcptCallSheetAuditionRow({
    required this.startMinute,
    required this.endMinute,
    required this.roleLabel,
    required this.candidateName,
  });
}

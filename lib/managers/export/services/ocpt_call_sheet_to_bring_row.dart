// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/export/services/ocpt_schedule_pdf_shared.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_schedule_plan_snapshot.dart';

/// One row of a named sheet's own "to bring" table: an element
/// [OcptSchedulePlanSnapshot.elementsToBringOnDay] joined onto that sheet's own recipient, and the
/// scene numbers of the day's own shots that play a scene it is linked to.
class OcptCallSheetToBringRow {
  /// The element the recipient is due to bring.
  final OcptElement element;

  /// The scene numbers of the day's own shots that play a scene [element] is linked to, sorted —
  /// empty when [element] is linked to a scene the day plays through no numbered shot at all, which
  /// still prints ([ocptScheduleEmptyValue]) rather than being left out: the join already
  /// established the element belongs on this list, and a bare scene id would explain nothing on a
  /// printed page.
  final List<String> sceneNumbers;

  /// Class constructor
  const OcptCallSheetToBringRow({required this.element, required this.sceneNumbers});
}

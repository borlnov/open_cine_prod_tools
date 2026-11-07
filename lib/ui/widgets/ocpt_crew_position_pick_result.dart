// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_crew_position_ref.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_crew_position_picker_dialog.dart';

/// What [OcptCrewPositionPickerDialog.show] resolves to once something was actually picked:
/// either a position ([position], a catalogue entry or one of the caller's own promoted refs), or
/// the caller's own "Custom label…" entry ([isCustom]) — never both, and the `Future` resolves to
/// null instead of either when the dialog was merely dismissed.
class OcptCrewPositionPickResult {
  /// The position picked, or null when [isCustom] is true instead.
  final OcptCrewPositionRef? position;

  /// True when the "Custom label…" entry was picked rather than a position.
  final bool isCustom;

  /// A catalogue or promoted position was picked.
  const OcptCrewPositionPickResult.position(this.position) : isCustom = false;

  /// The "Custom label…" entry was picked.
  const OcptCrewPositionPickResult.custom() : position = null, isCustom = true;
}

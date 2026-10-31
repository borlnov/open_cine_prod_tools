// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alert_location_window.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_schedule_alerts.dart';

/// One permit window a location declares, reduced to what [OcptSchedulePermitNotValidAlert] needs
/// — the mirror of `OcptAssetRef.validFrom`/`validUntil`, a document's own validity dates rather
/// than a whole asset row, mirroring how [OcptScheduleAlertLocationWindow] strips
/// `OcptLocationAvailability` down to what rule 3 reads.
///
/// **A window with both dates null records nothing and is not a window at all** — the caller must
/// not hand one in, and [ocptComputeScheduleAlerts] filters one out defensively (belt and braces)
/// rather than trusting every caller to have done so: a location whose every recorded permit is
/// dateless reads exactly as one that filed none, the same "absence of data is not a refusal"
/// argument rule 3 already makes for a location declaring no availability window at all.
class OcptSchedulePermitWindow {
  /// Builds a permit window to feed to [ocptComputeScheduleAlerts].
  const OcptSchedulePermitWindow({required this.validFrom, required this.validUntil});

  /// The date this permit becomes valid, or null while unbounded on that side.
  final DateTime? validFrom;

  /// The date this permit stops being valid, or null while unbounded on that side.
  final DateTime? validUntil;
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_presence_code.dart';

/// The next override the presence grid's own cell click writes, given [current] — the override
/// presently stored for that cell (`shooting_presences.code`), or null while there is none.
///
/// The cycle is `null → working → available → travelling → unavailable → null → …`
/// ([OcptPresenceCode.values]' own declared order, wrapping from [OcptPresenceCode.unavailable]
/// back to no override at all) — and it steps the **override**, never the cell's *effective* value:
/// a computed cell shows a code nobody has stated, so starting the cycle from what happens to be on
/// screen would silently promote a guess into a claim the moment a user's first click landed on,
/// say, [OcptPresenceCode.available] rather than [OcptPresenceCode.working]. The first click on a
/// cell carrying no override therefore always lands on [OcptPresenceCode.working], whatever the
/// cell was showing (or not showing) beforehand.
///
/// The null step matters as much as the four codes: without it, a user who clicked past the value
/// they meant could never get back to "let the app compute it" — every cell would have to carry an
/// override forever, once touched once.
OcptPresenceCode? ocptNextPresenceOverride(OcptPresenceCode? current) {
  if (current == null) {
    return OcptPresenceCode.working;
  }

  final nextIndex = current.index + 1;
  return nextIndex < OcptPresenceCode.values.length ? OcptPresenceCode.values[nextIndex] : null;
}

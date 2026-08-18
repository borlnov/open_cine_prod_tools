// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';

/// Whether a role wearing [isFromScreenplay] and [kind] was named by a character introduced in
/// capitals in an action line, as opposed to cued in dialogue or added by hand.
///
/// The three ways a role's two columns combine:
///
/// | `isFromScreenplay` | `kind` | Means |
/// | --- | --- | --- |
/// | true | `speaking` | Cued in the dialogue of at least one episode |
/// | true | non-speaking (`silent`, or requalified `extra`) | Named in the action, never cued |
/// | false | any | Added by hand, or kept through `keepOrphanedRoleAsSilent` |
///
/// The middle row is deliberately **any non-speaking kind**, not [OcptRoleKind.silent] alone: the
/// role sheet lets the user change a role's kind, and requalifying a detected `SILHOUETTE` as an
/// [OcptRoleKind.extra] is legitimate — scoping this predicate to `silent` would make such a role
/// fall through every rule that reads it. That the two `true` rows never collide is what makes the
/// predicate well-defined without a schema change: `keepOrphanedRoleAsSilent` always clears
/// [isFromScreenplay] the moment it turns a role silent, so no other path in the app produces a
/// role wearing both a true [isFromScreenplay] and a non-speaking [kind].
///
/// Read by both `OcptRoleIndexService` (over an `OcptRoleRow`'s columns) and the resources mode
/// (over an `OcptRole`'s), which is why this pure rule lives here rather than in either layer.
bool ocptRoleIsActionDetected({
  required bool isFromScreenplay,
  required OcptRoleKind kind,
}) => isFromScreenplay && kind != OcptRoleKind.speaking;

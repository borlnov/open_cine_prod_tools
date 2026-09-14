// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';

/// A normalised character name shared by a live, `isFromScreenplay` role and a live, hand-added
/// one: `docs/adr/0030-a-shots-characters-are-the-productions-roles.md`'s decision 2.
///
/// A character invented in the shot list is a hand-added role from the moment it is typed (decision
/// 1). When the screenplay later gives that same character a line, `reconcile` creates the speaking
/// role it always would — the screenplay stays the source of truth, and `reconcile` itself is
/// unchanged, matching only its own `isFromScreenplay` roles as it always has — so the project
/// briefly holds two live roles wearing the same name. This is a **pure read over the already-loaded
/// cast**, computed by [buildAll] exactly the way `OcptRemovedRoleAlert.buildAll` is: nothing here
/// changes what `reconcile` writes, and nothing here decides anything — the app never merges the two
/// roles silently, it only ever surfaces that they might be the same person and lets the user say
/// through `OcptRoleIndexService.mergeRole` (the hand-added role is always offered as *source*, the
/// screenplay one as *target*, so the reconciled role keeps being the one `reconcile` owns).
class OcptRoleCollisionAlert extends Equatable {
  /// The normalised name (`fountain_kit`'s `normalizeCharacterName`) both roles below share.
  final String name;

  /// The id of the live, `isFromScreenplay` role wearing [name].
  final String screenplayRoleId;

  /// The id of the live, hand-added role also wearing [name].
  final String handAddedRoleId;

  /// Class constructor
  const OcptRoleCollisionAlert({
    required this.name,
    required this.screenplayRoleId,
    required this.handAddedRoleId,
  });

  /// Every collision found in [roles]: one alert per normalised name worn by both a live
  /// `isFromScreenplay` role and a live hand-added one, sorted by [name] so the banners keep a
  /// stable order across reloads.
  ///
  /// Two roles sharing a name and both `isFromScreenplay`, or both hand-added, are **not** a
  /// collision this reports — `reconcile`'s own doc comment already rules out two live
  /// `isFromScreenplay` roles legitimately sharing a name, and two hand-added roles sharing one is
  /// nothing this ADR is about. Only the from-screenplay/hand-added pairing is reported, because
  /// that is the one the reconciliation itself can produce out from under the user (decision 2).
  static List<OcptRoleCollisionAlert> buildAll(List<OcptRole> roles) {
    final screenplayRoleByName = <String, OcptRole>{};
    final handAddedRoleByName = <String, OcptRole>{};

    for (final role in roles) {
      final normalizedName = normalizeCharacterName(role.name);
      if (role.isFromScreenplay) {
        screenplayRoleByName.putIfAbsent(normalizedName, () => role);
      } else {
        handAddedRoleByName.putIfAbsent(normalizedName, () => role);
      }
    }

    final alerts = [
      for (final entry in screenplayRoleByName.entries)
        if (handAddedRoleByName[entry.key] case final handAddedRole?)
          OcptRoleCollisionAlert(
            name: entry.key,
            screenplayRoleId: entry.value.id,
            handAddedRoleId: handAddedRole.id,
          ),
    ];
    alerts.sort((a, b) => a.name.compareTo(b.name));

    return alerts;
  }

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptRoleCollisionAlert(name: $name, screenplayRoleId: $screenplayRoleId, "
      "handAddedRoleId: $handAddedRoleId)";

  /// Object properties
  @override
  List<Object?> get props => [name, screenplayRoleId, handAddedRoleId];
}

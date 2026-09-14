// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:uuid/uuid.dart';

/// The fixed namespace every deterministic id in this file is minted from, through UUID v5
/// (`docs/adr/0030-a-shots-characters-are-the-productions-roles.md`, decision 6).
///
/// **Never changes.** A v5 UUID is `hash(namespace, name)`: two replicas mint the same id for the
/// same input only as long as they share the same namespace, so this constant is fixed forever the
/// moment the migration that reads it first ships — rotating it would silently stop two replicas'
/// independently minted roles from converging. The value itself carries no meaning; it was minted
/// once as an ordinary random UUID v4 and frozen here.
const _ocptDeterministicIdNamespace = 'e26e6b0e-9a8b-4d5b-9d16-8a6c2d1e9c9a';

/// The id a hand-added silent role must get when the schema v3 migration mints one for a shot
/// list's character name that matches no live role
/// (`docs/adr/0030-a-shots-characters-are-the-productions-roles.md`, decision 6).
///
/// Deterministic in [normalizedCharacterName] alone (already normalised through `fountain_kit`'s
/// `normalizeCharacterName`, the same identity `OcptShotListService.attachCharacter` and
/// `OcptRoleIndexService.reconcile` already compare by): every replica migrating the same name
/// mints the very same `roles.id`, which is what lets the minted rows converge under per-column
/// merge instead of multiplying — see `ocpt_migration_v3.dart`'s own doc comment for the full
/// argument.
String ocptDeterministicRoleId(String normalizedCharacterName) =>
    const Uuid().v5(_ocptDeterministicIdNamespace, normalizedCharacterName);

/// The id the `role_episodes` link from [roleId] to [screenplayId] must get when the schema v3
/// migration mints it alongside a role [ocptDeterministicRoleId] minted for the same name
/// (`docs/adr/0030-a-shots-characters-are-the-productions-roles.md`, decision 6).
///
/// Deterministic in the pair, the same way [ocptDeterministicRoleId] is deterministic in a name:
/// two replicas that mint the same [roleId] for a name, and see it used in the same episode, mint
/// the same link id for it too.
String ocptDeterministicRoleEpisodeId({required String roleId, required String screenplayId}) =>
    const Uuid().v5(_ocptDeterministicIdNamespace, '$roleId/$screenplayId');

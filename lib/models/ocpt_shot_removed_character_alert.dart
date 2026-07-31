// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';

/// A character the screenplay no longer names anywhere — neither as a dialogue cue nor in capitals
/// in an action line — but that is still attached to at least one shot: what the shot list's
/// deleted-character banner is built from.
///
/// A shot's characters are authored in the shot list, not derived from the screenplay (a shot
/// legitimately carries a role the text names nowhere at all), so nothing removes them when the
/// screenplay changes. Renaming or deleting a character therefore leaves the shots that named it
/// pointing at somebody the screenplay no longer knows, which is what this alert reports —
/// together with the two ways out the banner offers: dropping the name everywhere, or replacing it
/// with one of the characters the screenplay still names.
class OcptShotRemovedCharacterAlert extends Equatable {
  /// The character's name, normalised through `fountain_kit`'s `normalizeCharacterName` — both
  /// `shot_characters.characterName` and the screenplay's own cast go through it, so the
  /// comparison this alert comes out of is exact.
  final String characterName;

  /// The `OcptShot.code` of every shot [characterName] is still attached to, in the shot list's own
  /// display order (sequence by sequence, then shot by shot), so the banner reads them in the order
  /// the user would find them in.
  final List<String> shotCodes;

  /// Class constructor
  const OcptShotRemovedCharacterAlert({required this.characterName, required this.shotCodes});

  /// Every alert of [snapshot], given the screenplay's current [screenplayCharacters] (normalised
  /// the same way the shots' own characters are), sorted by [characterName] so the banners keep a
  /// stable order across reloads.
  ///
  /// Returns an empty list when [snapshot] is null — nothing is loaded yet, so nothing can be
  /// reported as removed.
  static List<OcptShotRemovedCharacterAlert> buildAll({
    required OcptShotListSnapshot? snapshot,
    required List<String> screenplayCharacters,
  }) {
    if (snapshot == null) {
      return const [];
    }

    final cast = screenplayCharacters.toSet();
    final shotCodesByCharacter = <String, List<String>>{};

    for (final sequence in snapshot.sequences) {
      for (final shot in sequence.shots) {
        for (final character in shot.characters) {
          if (cast.contains(character)) {
            continue;
          }
          shotCodesByCharacter.putIfAbsent(character, () => []).add(shot.code);
        }
      }
    }

    final characterNames = shotCodesByCharacter.keys.toList()..sort();

    return [
      for (final characterName in characterNames)
        OcptShotRemovedCharacterAlert(
          characterName: characterName,
          shotCodes: List.unmodifiable(shotCodesByCharacter[characterName]!),
        ),
    ];
  }

  /// Object string representation, useful for debugging and logging.
  @override
  String toString() =>
      "OcptShotRemovedCharacterAlert(characterName: $characterName, "
      "shotCount: ${shotCodes.length})";

  /// Object properties
  @override
  List<Object?> get props => [characterName, shotCodes];
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The shot inspector's "Characters in shot" chips: one toggleable chip per character of the whole
/// screenplay — the speaking roles and the ones only introduced in capitals in an action line
/// alike — plus any character attached to this shot the screenplay no longer names at all.
///
/// [screenplayCharacters] and [attachedCharacters] are both already normalised through
/// `fountain_kit`'s `normalizeCharacterName`, so they compare equal byte-for-byte: an attached
/// character not found in the cast is the removed case, appended after every other one, struck
/// through in the error colour with a `(removed)` suffix, and stays listed (and toggleable off)
/// until it is untoggled. Toggling a chip writes immediately — there is no typing debounce for
/// this.
///
/// A chip can only be toggled, never authored: attaching somebody the screenplay names nowhere,
/// not even in an action line, has no input of its own yet, and comes in a future version.
class OcptShotCharacterChips extends StatelessWidget {
  /// Every character the whole screenplay names, normalised, in first-appearance order.
  final List<String> screenplayCharacters;

  /// This shot's own attached characters, normalised, in whatever order they were attached.
  final List<String> attachedCharacters;

  /// Called with a character's name when its chip is clicked.
  final ValueChanged<String> onToggled;

  /// Class constructor
  const OcptShotCharacterChips({
    super.key,
    required this.screenplayCharacters,
    required this.attachedCharacters,
    required this.onToggled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    final removed = [
      for (final name in attachedCharacters)
        if (!screenplayCharacters.contains(name)) name,
    ];
    final everyName = [...screenplayCharacters, ...removed];

    if (everyName.isEmpty) {
      return Text(
        tr.shotListCharactersEmptyHint,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final name in everyName)
          _OcptCharacterChip(
            name: name,
            isAttached: attachedCharacters.contains(name),
            isRemoved: removed.contains(name),
            onTap: () => onToggled(name),
          ),
      ],
    );
  }
}

/// One chip of [OcptShotCharacterChips].
class _OcptCharacterChip extends StatelessWidget {
  /// The character's normalised name.
  final String name;

  /// Whether [name] is currently attached to the shot.
  final bool isAttached;

  /// Whether [name] no longer speaks anywhere in the screenplay.
  final bool isRemoved;

  /// Called when this chip is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptCharacterChip({
    required this.name,
    required this.isAttached,
    required this.isRemoved,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return FilterChip(
      label: Text(isRemoved ? tr.shotListCharacterRemovedLabel(name) : name),
      labelStyle: isRemoved
          ? theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
              decoration: TextDecoration.lineThrough,
            )
          : null,
      selected: isAttached,
      onSelected: (_) => onTap(),
    );
  }
}

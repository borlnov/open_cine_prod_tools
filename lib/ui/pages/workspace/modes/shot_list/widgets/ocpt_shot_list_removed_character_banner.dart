// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_removed_character_alert.dart';

/// The separator between two shot codes in the banner's list of the shots still carrying the
/// removed character, matching the one every other summary line of this mode joins with.
const _shotCodeSeparator = " · ";

/// The alert shown above the shot table for a character that no longer speaks anywhere in the
/// screenplay but is still attached to shots.
///
/// One banner per [OcptShotRemovedCharacterAlert]: it names the character, counts and lists the
/// shots still carrying it, and offers the two ways out — dropping it from every shot, or replacing
/// it everywhere with one of the roles the screenplay still speaks. Both write immediately, and the
/// banner disappears on its own once the reloaded shot list no longer has any shot carrying the
/// name: nothing dismisses it by hand, since the situation it reports would still be there.
///
/// Painted in the error colour, the same one the inspector's chips strike the character through
/// with, rather than the warning colour a stale coverage range wears: a character the screenplay
/// dropped is a mismatch to resolve, not a range to re-read.
class OcptShotListRemovedCharacterBanner extends StatelessWidget {
  /// The character reported, and the shots still carrying it.
  final OcptShotRemovedCharacterAlert alert;

  /// Every character the screenplay still speaks, normalised, offered as replacements. An empty
  /// list simply shows no replacement row at all.
  final List<String> replacementCandidates;

  /// Called when `Remove from every shot` is clicked.
  final VoidCallback onRemoveFromEveryShot;

  /// Called with a replacement's name when one of the replacement chips is clicked.
  final ValueChanged<String> onReplaced;

  /// Class constructor
  const OcptShotListRemovedCharacterBanner({
    super.key,
    required this.alert,
    required this.replacementCandidates,
    required this.onRemoveFromEveryShot,
    required this.onReplaced,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final color = theme.colorScheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.person_off_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr.shotListRemovedCharacterBanner(
                    alert.shotCodes.length,
                    alert.characterName,
                    alert.shotCodes.join(_shotCodeSeparator),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
                const SizedBox(height: 6),
                _buildActions(context, tr, color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the banner's action row: the `Remove from every shot` button, then one chip per
  /// replacement candidate under it.
  Widget _buildActions(BuildContext context, Tr tr, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton(
        onPressed: onRemoveFromEveryShot,
        style: TextButton.styleFrom(foregroundColor: color),
        child: Text(tr.shotListRemovedCharacterRemoveAllAction),
      ),
      if (replacementCandidates.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          tr.shotListRemovedCharacterReplaceLabel,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final candidate in replacementCandidates)
              ActionChip(label: Text(candidate), onPressed: () => onReplaced(candidate)),
          ],
        ),
      ],
    ],
  );
}

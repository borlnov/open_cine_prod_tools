// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_character_chips.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_difficulty_rating.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_status_pill.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';

/// The fixed width every leader card of the board takes, wide enough for a read-out value beside
/// its label without wrapping onto a third line.
const double _leaderCardWidth = 240;

/// The board's own découpage read-out, leading every `OcptStoryboardShotRow`: [shot]'s code and
/// status, its size, framing, camera move, lens and recording format, its attached cast and its
/// four difficulty axes — the very same pills, chips and dots the table and the inspector already
/// render (`docs/plans/storyboard.md`, §4.2), never a rendering of its own.
///
/// Purely presentational and entirely read-only: the board is a reading surface over the
/// découpage the table and the inspector already edit, so every reused widget here is handed a
/// null write callback.
class OcptStoryboardShotLeaderCard extends StatelessWidget {
  /// The shot this card leads.
  final OcptShot shot;

  /// The production's roles currently attached to [shot] — already filtered down to
  /// [OcptShot.characterRoleIds] by the caller, so every chip [OcptShotCharacterChips] draws here
  /// reads as attached.
  final List<OcptRole> attachedRoles;

  /// Class constructor
  const OcptStoryboardShotLeaderCard({super.key, required this.shot, required this.attachedRoles});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Container(
      width: _leaderCardWidth,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                shot.code,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontFamily: ocptMonospaceFontFamily,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              OcptShotStatusPill(status: shot.status),
            ],
          ),
          const SizedBox(height: 10),
          _readOut(context, tr.shotListColumnShotSize, ocptShotFieldOrDash(shot.shotSize)),
          _readOut(context, tr.shotListColumnFraming, ocptShotFieldOrDash(shot.framing)),
          _readOut(context, tr.shotListColumnCameraMove, ocptShotFieldOrDash(shot.cameraMove)),
          _readOut(context, tr.shotListColumnLens, ocptShotFieldOrDash(shot.lens)),
          _readOut(context, tr.shotListColumnFormat, ocptShotFieldOrDash(shot.recordingFormat)),
          if (attachedRoles.isNotEmpty) ...[
            const SizedBox(height: 8),
            OcptShotCharacterChips(
              roles: attachedRoles,
              attachedRoleIds: shot.characterRoleIds,
              onToggled: null,
              onCharacterAdded: null,
            ),
          ],
          const SizedBox(height: 10),
          OcptShotDifficultyRating(
            label: tr.shotListColumnSet,
            value: shot.difficultySet,
            onChanged: null,
          ),
          OcptShotDifficultyRating(
            label: tr.shotListColumnCameraMove,
            value: shot.difficultyCamera,
            onChanged: null,
          ),
          OcptShotDifficultyRating(
            label: tr.shotListDifficultyAxisActing,
            value: shot.difficultyActing,
            onChanged: null,
          ),
          OcptShotDifficultyRating(
            label: tr.shotListColumnSound,
            value: shot.difficultySound,
            onChanged: null,
          ),
        ],
      ),
    );
  }

  /// One `label — value` line of the card's découpage read-out.
  Widget _readOut(BuildContext context, String label, String value) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodySmall, softWrap: true),
          ),
        ],
      ),
    );
  }
}

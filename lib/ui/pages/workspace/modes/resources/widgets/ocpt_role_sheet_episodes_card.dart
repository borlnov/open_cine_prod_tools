// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_workspace_episode_label.dart';

/// "Where this role speaks": one chip per episode of the project, checked when the role is named
/// in it — `OcptShotCharacterChips`'s own toggle pattern (a [FilterChip] whose `onSelected` goes
/// null the moment the value it shows may not be changed by a gesture), read over the project's
/// episodes rather than a shot's attached characters.
///
/// Only ever built between the casting card and the things card, and only while the project holds
/// more than one episode (`docs/adr/0019-one-project-several-episodes.md` §8: a single-episode
/// project names no episode anywhere) — that is `OcptRoleSheet`'s own call, not this card's, since
/// a card that quietly renders nothing would still leave the spacing around it behind.
///
/// A role the screenplay still speaks reads its chips out with no control at all: the cue decides
/// which episodes name it, and offering to contradict it would only invite the two to disagree.
/// [onChanged] is null for that role, exactly as it is under a read-only preview — this card
/// cannot and does not tell the two apart, that distinction is `OcptRoleSheet`'s to make before
/// handing the callback down.
class OcptRoleSheetEpisodesCard extends StatelessWidget {
  /// Every episode of the project, in display order.
  final List<OcptEpisode> episodes;

  /// The ids of the episodes the role is currently named in.
  final Set<String> selectedEpisodeIds;

  /// Called with the full new set of episode ids once a chip is toggled, or null while the role's
  /// episodes may not be changed by a gesture.
  final ValueChanged<Set<String>>? onChanged;

  /// Class constructor
  const OcptRoleSheetEpisodesCard({
    super.key,
    required this.episodes,
    required this.selectedEpisodeIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final onChanged = this.onChanged;

    return OcptResourcesSheetCard(
      title: tr.resourcesRoleEpisodesCardTitle,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final episode in episodes)
            FilterChip(
              label: Text(ocptWorkspaceEpisodeLabelOf(tr, episode)),
              selected: selectedEpisodeIds.contains(episode.id),
              onSelected: onChanged == null
                  ? null
                  : (isSelected) => onChanged(_toggled(episode.id, isSelected)),
            ),
        ],
      ),
    );
  }

  /// [selectedEpisodeIds] with [episodeId] added (while [isSelected]) or removed.
  Set<String> _toggled(String episodeId, bool isSelected) => isSelected
      ? {...selectedEpisodeIds, episodeId}
      : {
          for (final id in selectedEpisodeIds)
            if (id != episodeId) id,
        };
}

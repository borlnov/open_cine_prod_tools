// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/utils/ocpt_scene_display_number.dart';

/// The episode tag to append to a mode's own export suggested file name (`ep. 2`), or null while
/// [episodes] holds one episode or none, or [selectedEpisodeId] names none of them.
///
/// A single-episode project names no episode anywhere (ADR 0019), and this is the one place the
/// screenplay, shot list and breakdown modes resolve that rule for their own exports — reusing
/// [ocptEpisodePrefixNumberOf], the very same "more than one episode" test the scene number prefix
/// already runs, so the two never disagree about when a project counts as multi-episode. No
/// manager or service ever sees a `Tr`, so this — like the scene number prefix's own wording — is
/// resolved here, in the UI layer, and handed down as a plain string.
String? ocptWorkspaceEpisodeExportTagOf({
  required BuildContext context,
  required List<OcptEpisode> episodes,
  required String? selectedEpisodeId,
}) {
  if (selectedEpisodeId == null) {
    return null;
  }

  final episodeNumber = ocptEpisodePrefixNumberOf(
    episodes: episodes,
    screenplayId: selectedEpisodeId,
  );
  if (episodeNumber == null) {
    return null;
  }

  return Tr.of(context).workspaceEpisodeTag(episodeNumber);
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_list_snapshot.dart';

/// What the schedule mode reads in one go to know its shots: the project's live episodes, each
/// one's own shot list in the same order, and the image path of every shot's first storyboard
/// panel, keyed by shot id (a shot whose first panel has no image has no entry).
typedef OcptScheduleShotListsRead = ({
  List<OcptEpisode> episodes,
  List<OcptShotListSnapshot> shotLists,
  Map<String, String> storyboardThumbnailPathByShotId,
});

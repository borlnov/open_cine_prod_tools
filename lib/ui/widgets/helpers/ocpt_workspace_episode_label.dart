// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';

/// [episode]'s label: its title when it has one (`{number}. {title}`), the localized
/// `Episode {number}` when it doesn't — see `OcptEpisode.title`'s own doc comment for why an
/// empty title is an ordinary state rather than a placeholder to fill in a hurry.
///
/// This is the one implementation of that rule: `OcptWorkspaceShell`'s own episode selector and
/// the role sheet's episode chips (`OcptRoleSheetEpisodesCard`) both call it rather than restating
/// it, so an episode reads the same wherever it is named. No manager or service ever sees a `Tr`,
/// so — like every other UI-facing label of the app — this lives here rather than on the model.
String ocptWorkspaceEpisodeLabelOf(Tr tr, OcptEpisode episode) => episode.title.isEmpty
    ? tr.workspaceEpisodeUntitledLabel(episode.number)
    : tr.workspaceEpisodeTitledLabel(episode.number, episode.title);

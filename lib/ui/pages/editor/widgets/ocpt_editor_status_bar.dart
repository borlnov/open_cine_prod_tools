// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_statistics_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_statistics_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_saved_time_segment.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_status_bar.dart';

/// The shell's `statusBar`: the screenplay's own ordered counters (pages, scenes, characters,
/// words, signs — the first three never dropped) plus the self-refreshing last-saved segment.
///
/// Only the statistics bloc's state rebuilds it, so a keystroke does not.
class OcptEditorStatusBar extends StatelessWidget {
  /// The time of the last successful save, or null if nothing was saved in this session yet.
  final DateTime? lastSavedAt;

  /// Class constructor
  const OcptEditorStatusBar({required this.lastSavedAt, super.key});

  /// Build the editor status bar as a [BlocBuilder].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return BlocBuilder<OcptEditorStatisticsBloc, OcptEditorStatisticsState>(
      builder: (context, state) {
        final statistics = state.statistics;

        return OcptWorkspaceStatusBar(
          counters: [
            tr.editorStatsPages(statistics.pageCount),
            tr.editorStatsScenes(statistics.sceneCount),
            tr.editorStatsCharacters(statistics.speakingCharacterCount),
            tr.editorStatsWords(statistics.wordCount),
            tr.editorStatsSigns(statistics.signCount),
          ],
          nonDroppableCount: 3,
          trailingText: OcptEditorSavedTimeSegment.textFor(context, lastSavedAt),
          trailing: OcptEditorSavedTimeSegment(lastSavedAt: lastSavedAt),
        );
      },
    );
  }
}

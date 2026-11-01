// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_statistics_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_statistics_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_inspector_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_metadata_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_versions_panel_view.dart';

/// The tabbed right dock (formatted preview, raw mode only; the Fountain syntax guide, the scene
/// inspector, the read-only metadata panel and the project versions, all four in both modes), the
/// shell's `rightPanel`.
///
/// The preview tab is gated on [liveMode] rather than [OcptEditorState.mode]: on a phone the
/// centre already is the formatted styled editor (see `OcptEditorCentre`), the same reason
/// [OcptEditorState.isPreviewTabAvailable]'s own doc comment gives for leaving it out of styled
/// mode, so it would be redundant chrome even while the persisted preference is raw.
class OcptEditorRightDockView extends StatelessWidget {
  /// The mode's state, whose dock is open.
  final OcptEditorState state;

  /// The editing mode actually driving which surface is live.
  final OcptEditorMode liveMode;

  /// Opens the title page dialog, or null where it may not be edited (a version being previewed).
  final VoidCallback? onEditTitlePage;

  /// Class constructor
  const OcptEditorRightDockView({
    required this.state,
    required this.liveMode,
    required this.onEditTitlePage,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final rightDockTab = state.rightDockTab!;
    final isPreviewTabAvailable = OcptEditorState.isPreviewTabAvailableFor(
      mode: liveMode,
      isReadOnly: state.isPreviewingVersion,
    );
    final previewChild = isPreviewTabAvailable && rightDockTab == OcptEditorRightDockTab.preview
        ? OcptEditorPreview(
            document: state.document,
            pageSetup: state.pageSetup,
            currentLine: state.currentLine,
            isPageSimulationEnabled: state.isPageSimulationEnabled,
          )
        : null;

    final currentSceneIndex = state.currentSceneIndex;

    return OcptEditorRightDock(
      activeTab: rightDockTab,
      isPreviewTabAvailable: isPreviewTabAvailable,
      previewChild: previewChild,
      inspectorChild: BlocBuilder<OcptEditorStatisticsBloc, OcptEditorStatisticsState>(
        builder: (context, statistics) => OcptEditorInspectorPanel(
          scene: currentSceneIndex == null ? null : state.scenes[currentSceneIndex],
          sceneOrdinal: currentSceneIndex == null ? null : currentSceneIndex + 1,
          statistics: statistics.sceneStatistics,
        ),
      ),
      metadataChild: BlocBuilder<OcptEditorStatisticsBloc, OcptEditorStatisticsState>(
        builder: (context, statistics) => OcptEditorMetadataPanel(
          titlePage: state.document?.titlePage,
          statistics: statistics.statistics,
          onEditTitlePage: onEditTitlePage,
        ),
      ),
      versionsChild: OcptEditorVersionsPanelView(state: state),
      onTabSelected: (tab) =>
          context.read<OcptEditorBloc>().add(OcptEditorRightDockTabSelectedEvent(tab: tab)),
      onClose: () => context.read<OcptEditorBloc>().add(const OcptEditorRightDockClosedEvent()),
    );
  }
}

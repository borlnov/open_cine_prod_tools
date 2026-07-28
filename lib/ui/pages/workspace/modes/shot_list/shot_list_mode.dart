// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_columns_menu.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_sequence_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_table.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';

/// The shot list (découpage technique) production mode: the sequence tree on the left, the
/// selected sequence's shot table in the centre, and the tabbed shot inspector on the right.
class OcptShotListMode extends StatelessWidget {
  /// Creates the shot list mode.
  const OcptShotListMode({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (context) => OcptShotListBloc(), child: const _ShotListView());
}

/// The content of [OcptShotListMode], separated from it so [OcptShotListMode] only wires the
/// [OcptShotListBloc] up (RFL3).
///
/// This is a StatefulWidget (the documented RFL1 exception) because it owns the dock layout
/// controller: the live dock fractions must survive a rebuild and be mutated imperatively while a
/// divider is being dragged, without emitting a bloc state per frame.
class _ShotListView extends StatefulWidget {
  /// Class constructor
  const _ShotListView();

  @override
  State<_ShotListView> createState() => _ShotListViewState();
}

/// The state of [_ShotListView]: owns the dock layout controller and keeps it in sync with the
/// fractions the bloc persisted.
class _ShotListViewState extends State<_ShotListView> {
  /// The live source of truth for the two dock fractions while dragging a divider. Initialized
  /// with the defaults; synced to the bloc's persisted values once the load (or a reset)
  /// resolves, in [_onStateChanged].
  final OcptWorkspaceDockLayoutController _dockLayoutController = OcptWorkspaceDockLayoutController(
    leftFraction: OcptWorkspaceDock.leftDefaultFraction,
    rightFraction: OcptWorkspaceDock.rightDefaultFraction,
  );

  @override
  void dispose() {
    _dockLayoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<OcptShotListBloc, OcptShotListState>(
    listener: _onStateChanged,
    builder: (context, state) {
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      return OcptWorkspaceShell(
        title: state.title,
        isDirty: false,
        onBack: () => context.read<OcptShotListBloc>().add(const OcptShotListBackRequestedEvent()),
        modeLabel: Tr.of(context).workspaceModeLabelShotList,
        overflowEntries: _buildOverflowEntries(context),
        isLeftDockOpen: state.isSequencePanelVisible,
        onToggleLeftDock: () => context.read<OcptShotListBloc>().add(
          const OcptShotListSequencePanelToggledEvent(),
        ),
        isRightDockOpen: state.rightDockTab != null,
        onToggleRightDock: () => context.read<OcptShotListBloc>().add(
          const OcptShotListRightDockToggledEvent(),
        ),
        leftPanel: _buildSequencePanel(context, state),
        rightPanel: _buildRightDock(context, state),
        centre: _buildCentre(context, state),
        dockLayoutController: _dockLayoutController,
        onDockFractionsChanged: (fractions) => context.read<OcptShotListBloc>().add(
          OcptShotListDockFractionsChangedEvent(left: fractions.left, right: fractions.right),
        ),
      );
    },
  );

  /// Builds the mode's `⋮` overflow menu entries.
  ///
  /// The shot list has nothing to export or import yet, so resetting the panel layout is its only
  /// entry for now.
  List<PopupMenuEntry<void>> _buildOverflowEntries(BuildContext context) => [
    PopupMenuItem<void>(
      onTap: () => context.read<OcptShotListBloc>().add(const OcptShotListDockLayoutResetEvent()),
      child: Text(Tr.of(context).shotListResetPanelLayoutAction),
    ),
  ];

  /// Builds the sequence tree, the shell's `leftPanel`, or null while it's hidden.
  ///
  /// `+ Shot` is wired only when the selected sequence is a real screenplay scene: the orphan
  /// group is where shots land when their scene disappears, never where new ones are authored.
  Widget? _buildSequencePanel(BuildContext context, OcptShotListState state) {
    if (!state.isSequencePanelVisible) {
      return null;
    }

    return OcptShotListSequencePanel(
      sequences: state.sequences,
      totalShotCount: state.totalShotCount,
      selectedSequenceId: state.selectedSequenceId,
      selectedShotId: state.selectedShotId,
      onSequenceSelected: (sequenceId) => context.read<OcptShotListBloc>().add(
        OcptShotListSequenceSelectedEvent(sequenceId: sequenceId),
      ),
      onShotSelected: (shotId) => context.read<OcptShotListBloc>().add(
        OcptShotListShotSelectedEvent(shotId: shotId),
      ),
      onShotCreated: state.selectedSequence is OcptSceneShotSequence
          ? () => context.read<OcptShotListBloc>().add(
              const OcptShotListShotCreationRequestedEvent(),
            )
          : null,
    );
  }

  /// Builds the shell's `centre`: the selected sequence's header, the `Columns ▾` menu, and the
  /// shot table under them.
  Widget _buildCentre(BuildContext context, OcptShotListState state) {
    final tr = Tr.of(context);
    final sequence = state.selectedSequence;

    if (sequence == null) {
      return OcptWorkspaceEmptyMode(
        icon: Icons.movie_filter_outlined,
        message: tr.shotListNoSequenceSelectedHint,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _SequenceHeader(sequence: sequence)),
              OcptShotListColumnsMenu(
                visibleColumns: state.visibleColumns,
                onColumnToggled: (column) => context.read<OcptShotListBloc>().add(
                  OcptShotListColumnToggledEvent(column: column),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
            child: OcptShotListTable(
              shots: sequence.shots,
              sequenceHeading: switch (sequence) {
                OcptSceneShotSequence() => sequence.heading,
                OcptOrphanShotSequence() => ocptShotListEmptyValue,
              },
              visibleColumns: state.visibleColumns,
              selectedShotId: state.selectedShotId,
              onShotSelected: (shotId) => context.read<OcptShotListBloc>().add(
                OcptShotListShotSelectedEvent(shotId: shotId),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the tabbed right dock, the shell's `rightPanel`, or null while the dock is closed.
  ///
  /// Both bodies are still placeholders: the shot inspector and the shot list metadata panel are
  /// built in their own right in a later version.
  Widget? _buildRightDock(BuildContext context, OcptShotListState state) {
    final rightDockTab = state.rightDockTab;
    if (rightDockTab == null) {
      return null;
    }

    final tr = Tr.of(context);

    return OcptShotListRightDock(
      activeTab: rightDockTab,
      inspectorChild: OcptWorkspaceEmptyMode(
        icon: Icons.tune_outlined,
        message: state.selectedShot == null
            ? tr.shotListNoShotSelectedHint
            : tr.shotListInspectorPlaceholderHint,
      ),
      metadataChild: OcptWorkspaceEmptyMode(
        icon: Icons.info_outline,
        message: tr.shotListMetadataPlaceholderHint,
      ),
      onTabSelected: (tab) => context.read<OcptShotListBloc>().add(
        OcptShotListRightDockTabSelectedEvent(tab: tab),
      ),
      onClose: () =>
          context.read<OcptShotListBloc>().add(const OcptShotListRightDockClosedEvent()),
    );
  }

  /// Applies bloc-driven effects onto the page: the live dock fractions, and the transient write
  /// error SnackBar.
  void _onStateChanged(BuildContext context, OcptShotListState state) {
    // Pushes the bloc's persisted fractions (the initial load, or "Reset panel layout") onto the
    // live controller; a no-op once a drag's own end-of-gesture event brings the bloc back in
    // sync with the value the controller already holds.
    _dockLayoutController.syncFromPersisted(
      leftFraction: state.leftDockFraction,
      rightFraction: state.rightDockFraction,
    );

    if (state.hasWriteError) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(Tr.of(context).shotListWriteError)));
      context.read<OcptShotListBloc>().add(const OcptShotListWriteErrorDismissedEvent());
    }
  }
}

/// The centre's sequence header: its title line, and the muted summary under it.
class _SequenceHeader extends StatelessWidget {
  /// The sequence being shown.
  final OcptShotSequence sequence;

  /// Class constructor
  const _SequenceHeader({required this.sequence});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final sequence = this.sequence;

    final summary = [
      tr.shotListShotsCount(sequence.shotCount),
      tr.shotListAverageDifficulty(
        ocptFormatShotDifficulty(context, sequence.averageDifficulty),
      ),
      tr.shotListLeftToShoot(sequence.shotsLeftToShoot),
    ].join(" · ");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          switch (sequence) {
            OcptSceneShotSequence() => tr.shotListSequenceHeader(
              sequence.displaySceneNumber,
              sequence.heading,
            ),
            OcptOrphanShotSequence() => tr.shotListOrphanSequenceTitle,
          },
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          summary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/shot_list_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_coverage_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_delete_confirm_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_inspector_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_columns_menu.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_right_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_sequence_panel.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_list_table.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_metadata_panel.dart';
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
  void deactivate() {
    // `deactivate()` runs before `dispose()` for every removal from the tree (a mode switch swaps
    // this whole subtree out, and so does the workspace's own back navigation), so flushing here
    // — rather than in `dispose()`, or waiting out the field-edit debounce — is what guarantees
    // the last couple of seconds of typing in an inspector field survive it: by the time
    // `dispose()` runs (and the `BlocProvider` above this widget closes the bloc along with it),
    // there may be nothing left to flush into. See `OcptStyledScreenplayEditor.deactivate()` for
    // the screenplay editor's own instance of the same reasoning.
    unawaited(context.read<OcptShotListBloc>().flushPendingFieldEdits());
    super.deactivate();
  }

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
      onOrphanedShotDeleted: (shotId) => _handleOrphanedShotDeletion(context, state, shotId),
    );
  }

  /// Confirms and dispatches the deletion of the orphaned shot [shotId], the left dock's own delete
  /// button, going through the same confirmation dialog and the same event as the inspector's
  /// `Delete shot` action. Ignores a click on a shot the snapshot no longer holds.
  Future<void> _handleOrphanedShotDeletion(
    BuildContext context,
    OcptShotListState state,
    String shotId,
  ) async {
    final shot = state.snapshot?.shotsById[shotId];
    if (shot == null) {
      return;
    }

    await _handleDeleteRequested(context, shot);
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
  Widget? _buildRightDock(BuildContext context, OcptShotListState state) {
    final rightDockTab = state.rightDockTab;
    if (rightDockTab == null) {
      return null;
    }

    final selectedShot = state.selectedShot;
    final selectedSequence = state.selectedSequence;
    final sequenceDisplayNumber = _sequenceDisplayNumberFor(selectedSequence);
    final sequenceHeading = _sequenceHeadingFor(selectedSequence, selectedShot);
    final coverageLayout = state.buildSelectedCoverageLayout();
    final staleCoverageRangeIds = coverageLayout == null
        ? const <String>{}
        : state.staleCoverageRangeIdsOfSelectedShot(coverageLayout);

    return OcptShotListRightDock(
      activeTab: rightDockTab,
      inspectorChild: OcptShotInspectorPanel(
        shot: selectedShot,
        sequenceHeading: sequenceHeading,
        sequenceDisplayNumber: sequenceDisplayNumber,
        speakingCharacters: state.speakingCharacters,
        suggestions: state.suggestions,
        coverageLayout: coverageLayout,
        otherShotsCoverageRanges: state.otherShotsCoverageOfSelectedScene(),
        staleCoverageRangeIds: staleCoverageRangeIds,
        fieldValueOf: (field) => _fieldValueOf(state, selectedShot, field),
        onDifficultyChanged: (axis, value) => _dispatchIfShotSelected(
          context,
          selectedShot,
          (id) => OcptShotListShotDifficultyChangedEvent(shotId: id, axis: axis, value: value),
        ),
        onCharacterToggled: (name) => _dispatchIfShotSelected(
          context,
          selectedShot,
          (id) => OcptShotListShotCharacterToggledEvent(shotId: id, characterName: name),
        ),
        onFieldChanged: (field, value) => _dispatchIfShotSelected(
          context,
          selectedShot,
          (id) => OcptShotListShotFieldChangedEvent(shotId: id, field: field, rawValue: value),
        ),
        onSelectCoverageRequested: () => _handleCoverageSelectionRequested(context),
        onCoverageClearAll: () => _dispatchIfShotSelected(
          context,
          selectedShot,
          (id) => OcptShotListCoverageClearRequestedEvent(shotId: id),
        ),
        onMarkAsChecked: () => _dispatchIfShotSelected(
          context,
          selectedShot,
          (id) => OcptShotListShotMarkedAsCheckedEvent(shotId: id),
        ),
        onDeleteRequested: selectedShot == null
            ? null
            : () => _handleDeleteRequested(context, selectedShot),
      ),
      metadataChild: OcptShotMetadataPanel(
        shot: selectedShot,
        sequenceDisplayNumber: sequenceDisplayNumber,
        sequenceHeading: sequenceHeading,
      ),
      onTabSelected: (tab) => context.read<OcptShotListBloc>().add(
        OcptShotListRightDockTabSelectedEvent(tab: tab),
      ),
      onClose: () =>
          context.read<OcptShotListBloc>().add(const OcptShotListRightDockClosedEvent()),
    );
  }

  /// The display number of [sequence]: a real scene's own `displaySceneNumber`, or the orphan
  /// placeholder for the orphan group or for no sequence at all.
  String _sequenceDisplayNumberFor(OcptShotSequence? sequence) => switch (sequence) {
    OcptSceneShotSequence() => sequence.displaySceneNumber,
    OcptOrphanShotSequence() || null => ocptShotListEmptyValue,
  };

  /// The heading shown for [sequence]: a real scene's own heading, or [shot]'s
  /// `OcptShot.orphanedHeading` while [sequence] is the orphan group.
  String _sequenceHeadingFor(OcptShotSequence? sequence, OcptShot? shot) => switch (sequence) {
    OcptSceneShotSequence() => sequence.heading,
    OcptOrphanShotSequence() => shot?.orphanedHeading ?? ocptShotListEmptyValue,
    null => ocptShotListEmptyValue,
  };

  /// [shot]'s current value for [field], for the inspector's editable fields: a pending edit
  /// still sitting in the bloc's debounce takes priority over the shot's own stored value, so
  /// typing is never overwritten by an unrelated reload. Formatted for an editable field (an
  /// empty string for a missing value, never [ocptShotListEmptyValue], which is the table and
  /// read-only fields' own placeholder).
  String _fieldValueOf(OcptShotListState state, OcptShot? shot, OcptShotListEditableField field) {
    if (shot == null) {
      return "";
    }

    final pending = state.pendingFieldEdits[(shot.id, field)];
    if (pending != null) {
      return pending;
    }

    return switch (field) {
      OcptShotListEditableField.shotSize => shot.shotSize,
      OcptShotListEditableField.framing => shot.framing,
      OcptShotListEditableField.cameraMove => shot.cameraMove,
      OcptShotListEditableField.lens => shot.lens,
      OcptShotListEditableField.recordingFormat => shot.recordingFormat,
      OcptShotListEditableField.estimatedDuration => shot.estimatedDurationMs == null
          ? ""
          : ocptFormatShotDuration(shot.estimatedDurationMs),
      OcptShotListEditableField.sound => shot.sound,
      OcptShotListEditableField.notes => shot.notes,
      OcptShotListEditableField.locationNotes => shot.locationNotes,
    };
  }

  /// Dispatches the event [buildEvent] builds from [shot]'s id, or does nothing while [shot] is
  /// null: every inspector callback that acts on "the selected shot" goes through this, so none
  /// of them has to force-unwrap it.
  void _dispatchIfShotSelected(
    BuildContext context,
    OcptShot? shot,
    OcptShotListEvent Function(String shotId) buildEvent,
  ) {
    if (shot == null) {
      return;
    }
    context.read<OcptShotListBloc>().add(buildEvent(shot.id));
  }

  /// Opens the dialog a shot's scenario coverage is selected in, keeping it in step with the bloc
  /// for as long as it is open.
  ///
  /// The dialog is built inside a `BlocBuilder` of its own, on the bloc explicitly handed down
  /// rather than read from the dialog's context: a dialog is mounted in the navigator's own
  /// subtree, above this mode, so it inherits nothing from it. That builder is what makes a range
  /// appear the moment it is recorded, since every click writes through the same bloc events the
  /// inspector uses. It renders nothing at all in the two states where there is nothing to select
  /// in — no shot selected any more, or a shot whose sequence disappeared from the screenplay —
  /// which can only happen if the selection changes underneath an open dialog.
  Future<void> _handleCoverageSelectionRequested(BuildContext context) {
    final bloc = context.read<OcptShotListBloc>();

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: bloc,
        child: BlocBuilder<OcptShotListBloc, OcptShotListState>(
          builder: (context, state) {
            final shot = state.selectedShot;
            final layout = state.buildSelectedCoverageLayout();
            if (shot == null || layout == null) {
              return const SizedBox.shrink();
            }

            return OcptShotCoverageDialog(
              shotCode: shot.code,
              sequenceHeading: _sequenceHeadingFor(state.selectedSequence, shot),
              layout: layout,
              pageSetup: state.pageSetup,
              ownRanges: shot.coverageRanges,
              otherShotsRanges: state.otherShotsCoverageOfSelectedScene(),
              pendingAnchor: state.pendingCoverageAnchor,
              onWordTapped: (wordStartOffset, wordEndOffset) => bloc.add(
                OcptShotListCoverageWordClickedEvent(
                  shotId: shot.id,
                  wordStartOffset: wordStartOffset,
                  wordEndOffset: wordEndOffset,
                ),
              ),
              onClearAll: () => bloc.add(OcptShotListCoverageClearRequestedEvent(shotId: shot.id)),
            );
          },
        ),
      ),
    );
  }

  /// Shows the delete confirmation dialog, then dispatches the deletion request if the user
  /// confirmed it.
  Future<void> _handleDeleteRequested(BuildContext context, OcptShot shot) async {
    final bloc = context.read<OcptShotListBloc>();
    final confirmed = await OcptShotDeleteConfirmDialog.show(context, shotCode: shot.code);
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptShotListShotDeletionRequestedEvent(shotId: shot.id));
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

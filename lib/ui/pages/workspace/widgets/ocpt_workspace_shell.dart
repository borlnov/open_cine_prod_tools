// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_toolbar.dart';

/// The persistent application chrome around a production mode's own content: a toolbar, an
/// optional full-width [banner] under it, an optional pair of resizable side docks around a centre
/// area, and an optional status bar.
///
/// A mode contributes its own [toolbarActions]/[overflowEntries] (mode-specific controls) and its
/// [leftPanel]/[centre]/[rightPanel]/[statusBar] content; this widget only assembles the layout
/// and the dock-resizing mechanics shared by every mode.
///
/// The controls every mode ends its toolbar with are built here rather than handed in, so their
/// order is the shell's guarantee and no mode can break it: the [modeLabel], the `Export` control
/// ([onExportRequested]), the dock toggles ([onToggleLeftDock]/[onToggleRightDock]), the save
/// control ([onSave]), then the project settings action ([onProjectSettingsRequested]) — each
/// rendered only when the mode wired it, so a mode with nothing to print, no dock, nothing to
/// save, or nothing to open there simply shows fewer of them.
///
/// The episode selector sits at the *other* end of the toolbar, right after the title and its
/// dirty marker / `Read only` pill, since it qualifies *which content* is on screen — exactly what
/// the title says too. It is built here from [episodes]/[selectedEpisodeId]/[onEpisodeSelected]
/// rather than handed in as a widget, for the same reason the `Export` control is: so the gesture
/// can't drift from one mode to the next. Its last entry, `Manage episodes…`, reuses
/// [onProjectSettingsRequested] rather than a selector-specific callback — it leads to the very
/// same destination, and reusing it means the entry is withheld automatically while a project
/// version is being previewed, exactly like the toolbar's own settings action.
///
/// This widget knows nothing about any specific mode (the screenplay editor included) beyond the
/// moved [OcptWorkspaceDock]/[OcptWorkspaceDockDivider]/[OcptWorkspaceDockLayoutController]
/// primitives.
///
/// The docks row reuses the drag-doesn't-rebuild-the-centre pattern the screenplay editor
/// pioneered: [leftPanel], [centre] and [rightPanel] are built once by the caller and handed in as
/// fixed widget instances, then referenced unchanged from inside the [ListenableBuilder] that
/// listens to [dockLayoutController]. A divider drag only ever calls
/// [OcptWorkspaceDockLayoutController.setLeftFraction]/`setRightFraction`, which notifies that
/// builder alone; since it references the very same widget instances on every rebuild, Flutter's
/// `Element.update` short-circuits on their identity and only re-lays-out the resolved widths —
/// the content underneath never rebuilds mid-drag.
class OcptWorkspaceShell extends StatelessWidget {
  /// The open project's name, shown in the toolbar.
  final String title;

  /// Whether there are unsaved changes, shown as a dot next to the title.
  final bool isDirty;

  /// Whether what the mode shows is a project version being previewed read-only.
  ///
  /// The shell's own answer to it is deliberately minimal — the toolbar shows the `Read only` pill
  /// in place of the unsaved-changes dot, since a preview has nothing to save — and every editing
  /// affordance beyond that is each mode's own to withhold: only the mode knows what its
  /// affordances are. The band naming the previewed version is handed in through [banner].
  final bool isReadOnly;

  /// The back action; the mode decides what flushing it implies.
  final VoidCallback onBack;

  /// The project's episodes, in their own order, or empty for a project that hasn't loaded any yet
  /// — a single-episode project included, [episodes] then holding that one episode too, exactly as
  /// [onEpisodeSelected] is what actually withholds the selector for it.
  final List<OcptEpisode> episodes;

  /// The id of the episode currently selected among [episodes], or null while none is.
  final String? selectedEpisodeId;

  /// Called when the toolbar's episode selector picks a different episode, or null when the mode
  /// withholds the selector outright — no control is rendered at all then, rather than a disabled
  /// one, even when [episodes] holds more than one. This is the schedule mode's own case: it reads
  /// every episode at once, so a selector would either do nothing or lie about what it shows.
  final ValueChanged<String>? onEpisodeSelected;

  /// The active mode's own toolbar controls, right-aligned before the overflow menu.
  final List<Widget> toolbarActions;

  /// The active mode's name, shown muted in the toolbar between the mode's own [toolbarActions]
  /// and the chrome the shell builds itself, or null to show no label.
  final String? modeLabel;

  /// Called when the toolbar's `Export` control is clicked, or null when the mode prints nothing —
  /// no control is rendered at all then, rather than a disabled one.
  final VoidCallback? onExportRequested;

  /// The `⋮` overflow menu's entries. An empty list renders no `⋮` button at all.
  final List<PopupMenuEntry<void>> overflowEntries;

  /// Whether the left dock is open, driving its toolbar toggle's selected state.
  final bool isLeftDockOpen;

  /// Called when the toolbar's left dock toggle is clicked, or null when the mode has no left dock
  /// to toggle — no toggle is rendered at all then.
  final VoidCallback? onToggleLeftDock;

  /// Whether the right dock is open, driving its toolbar toggle's selected state.
  final bool isRightDockOpen;

  /// Called when the toolbar's right dock toggle is clicked, or null when the mode has no right
  /// dock to toggle — no toggle is rendered at all then.
  final VoidCallback? onToggleRightDock;

  /// Called when the toolbar's save action is clicked, or null when the mode has nothing to save —
  /// no save control is rendered at all then.
  final VoidCallback? onSave;

  /// Whether a save is in flight: the save control then shows a spinner in place of its button.
  final bool isSaving;

  /// Called when the toolbar's project settings action is clicked, or null when the mode withholds
  /// it — no control is rendered at all then, rather than a disabled one. A mode withholds it while
  /// a project version is being previewed, the same idiom every other affordance that writes
  /// follows (see `OcptOpenProjectModel.isReadOnly`).
  final VoidCallback? onProjectSettingsRequested;

  /// The full-width band shown between the toolbar and the docks row, or null when there is
  /// nothing to announce.
  ///
  /// `OcptWorkspaceReadOnlyBanner` is what fills it today, and the slot is deliberately a plain
  /// widget rather than that type: the shell announces whatever the mode hands it, and doesn't have
  /// to learn about project versions to lay a band out.
  final Widget? banner;

  /// The left dock's content, or null when the mode has no left dock (no divider is shown either).
  final Widget? leftPanel;

  /// The right dock's content, or null when the mode has no right dock.
  final Widget? rightPanel;

  /// The mode's own main area.
  final Widget centre;

  /// The status band shown under the docks row, or null for no status band.
  final Widget? statusBar;

  /// The live dock fractions while a divider is being dragged, or null when the mode has no dock
  /// at all (in which case [leftPanel] and [rightPanel] must both be null too).
  final OcptWorkspaceDockLayoutController? dockLayoutController;

  /// Called once a drag gesture ends, reporting whichever side's fraction just changed. Only one
  /// of the record's fields is non-null per call, mirroring how the screenplay editor's own
  /// `OcptEditorDockFractionsChangedEvent` is shaped.
  final ValueChanged<({double? left, double? right})>? onDockFractionsChanged;

  /// Class constructor
  ///
  /// [dockLayoutController] must be given whenever [leftPanel] or [rightPanel] is, since resolving
  /// their widths needs the live drag fractions.
  const OcptWorkspaceShell({
    super.key,
    required this.title,
    required this.isDirty,
    this.isReadOnly = false,
    required this.onBack,
    this.episodes = const [],
    this.selectedEpisodeId,
    this.onEpisodeSelected,
    this.toolbarActions = const [],
    this.modeLabel,
    this.onExportRequested,
    this.overflowEntries = const [],
    this.isLeftDockOpen = false,
    this.onToggleLeftDock,
    this.isRightDockOpen = false,
    this.onToggleRightDock,
    this.onSave,
    this.isSaving = false,
    this.onProjectSettingsRequested,
    this.banner,
    this.leftPanel,
    this.rightPanel,
    required this.centre,
    this.statusBar,
    this.dockLayoutController,
    this.onDockFractionsChanged,
  }) : assert(
         (leftPanel == null && rightPanel == null) || dockLayoutController != null,
         "dockLayoutController must be given when leftPanel or rightPanel is",
       );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      OcptWorkspaceToolbar(
        title: title,
        isDirty: isDirty,
        isReadOnly: isReadOnly,
        onBack: onBack,
        episodeSelector: _buildEpisodeSelector(context),
        actions: toolbarActions,
        modeLabel: modeLabel,
        exportAction: _buildExportAction(context),
        dockToggles: _buildDockToggles(context),
        saveAction: _buildSaveAction(context),
        projectSettingsAction: _buildProjectSettingsAction(context),
        overflowEntries: overflowEntries,
      ),
      if (banner != null) banner!,
      Expanded(child: _buildDocksRow()),
      if (statusBar != null) statusBar!,
    ],
  );

  /// Builds the toolbar's `Export` control, or null when the mode withheld it — no control is
  /// rendered at all then, rather than a disabled one.
  ///
  /// Unlike the chrome's icon-only controls, this one carries its own label: an export is not the
  /// kind of gesture a bare glyph reads as, so it does not take [OcptWorkspaceToolbar
  /// .chromeButtonStyle]'s square shape, and is sized to the toolbar band rather than to
  /// [TextButton]'s own default touch target.
  ///
  /// That last part takes **two** overrides, and neither alone is enough.
  /// [MaterialTapTargetSize.shrinkWrap] drops the stock 48 px touch target, which silently wins over
  /// the [ocptToolbarChromeButtonSize] minimum below — the very reason the `iconButtonTheme` already
  /// shrink-wraps every icon button of the app. [VisualDensity.standard] is the one that actually
  /// shows: a [TextButton] takes its density from the ambient theme, which on a desktop platform is
  /// [VisualDensity.compact] and takes **8 px off** every minimum size, so this button drew 22 px
  /// tall beside 30 px toggles — an [IconButton] never does, its own default density being standard
  /// whatever the theme says. Beware that `flutter test` reports the Android density unless the test
  /// overrides `debugDefaultTargetPlatform`, so this is a difference a widget test cannot see by
  /// default.
  Widget? _buildExportAction(BuildContext context) {
    final onExportRequested = this.onExportRequested;
    if (onExportRequested == null) {
      return null;
    }

    final tr = Tr.of(context);

    return Tooltip(
      message: tr.workspaceExportTooltip,
      child: TextButton.icon(
        onPressed: onExportRequested,
        icon: const Icon(Icons.file_upload_outlined, size: 16),
        label: Text(tr.workspaceExportAction),
        style: TextButton.styleFrom(
          minimumSize: const Size(0, ocptToolbarChromeButtonSize),
          maximumSize: const Size(double.infinity, ocptToolbarChromeButtonSize),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.standard,
        ),
      ),
    );
  }

  /// Builds the toolbar's episode selector, or null when [onEpisodeSelected] is null or [episodes]
  /// holds at most one — no control is rendered at all then, rather than a disabled one, exactly
  /// like [_buildExportAction].
  ///
  /// The trigger reads the selected episode's own label; the menu lists every episode with the
  /// selected one marked, followed by `Manage episodes…` when [onProjectSettingsRequested] is
  /// wired (see the class doc comment for why it is that callback rather than a new one). That
  /// entry carries [_manageEpisodesOption] rather than null: a [PopupMenuButton] cannot carry a
  /// null value for an entry that must still be selectable, since it can't tell that apart from the
  /// menu being dismissed without a pick (`OcptResourcesPersonPicker`'s own `_nobodyOption` is the
  /// same workaround, for the same reason).
  Widget? _buildEpisodeSelector(BuildContext context) {
    final onEpisodeSelected = this.onEpisodeSelected;
    if (onEpisodeSelected == null || episodes.length <= 1) {
      return null;
    }

    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final onProjectSettingsRequested = this.onProjectSettingsRequested;
    final selected = _episodeById(selectedEpisodeId);

    return PopupMenuButton<String>(
      tooltip: tr.workspaceEpisodeSelectorTooltip,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      onSelected: (value) => value == _manageEpisodesOption
          ? onProjectSettingsRequested?.call()
          : onEpisodeSelected(value),
      itemBuilder: (context) => [
        for (final episode in episodes)
          PopupMenuItem<String>(
            value: episode.id,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  child: episode.id == selectedEpisodeId
                      ? const Icon(Icons.check, size: 16)
                      : null,
                ),
                const SizedBox(width: 6),
                Text(_episodeLabel(tr, episode)),
              ],
            ),
          ),
        if (onProjectSettingsRequested != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: _manageEpisodesOption,
            child: Text(tr.workspaceManageEpisodesAction),
          ),
        ],
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: SizedBox(
          height: ocptToolbarChromeButtonSize,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  selected == null ? "" : _episodeLabel(tr, selected),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, size: 16, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  /// The episode of [episodes] whose id is [id], or null while [id] is null or names none of
  /// them — the moment right after the project's episodes changed under a stale selection, before
  /// the workspace bloc has re-resolved it.
  OcptEpisode? _episodeById(String? id) {
    for (final episode in episodes) {
      if (episode.id == id) {
        return episode;
      }
    }

    return null;
  }

  /// [episode]'s label: its title when it has one, the localized `Episode 3` when it doesn't — see
  /// `OcptEpisode.title`'s own doc comment for why an empty title is an ordinary state rather than
  /// a placeholder to fill in a hurry.
  String _episodeLabel(Tr tr, OcptEpisode episode) => episode.title.isEmpty
      ? tr.workspaceEpisodeUntitledLabel(episode.number)
      : tr.workspaceEpisodeTitledLabel(episode.number, episode.title);

  /// Builds the toolbar's dock toggles, left one first, skipping whichever side the mode gave no
  /// callback for.
  ///
  /// Both wear the same sidebar glyph, the right one mirrored, so the pair reads as one control
  /// per side of the workspace; the `iconButtonTheme` paints the open one with its accent wash.
  List<Widget> _buildDockToggles(BuildContext context) {
    final tr = Tr.of(context);

    return [
      if (onToggleLeftDock != null)
        IconButton(
          icon: Icon(isLeftDockOpen ? Icons.view_sidebar : Icons.view_sidebar_outlined, size: 20),
          tooltip: tr.workspaceToggleLeftDockTooltip,
          isSelected: isLeftDockOpen,
          style: OcptWorkspaceToolbar.chromeButtonStyle,
          onPressed: onToggleLeftDock,
        ),
      if (onToggleRightDock != null)
        IconButton(
          icon: Transform.flip(
            flipX: true,
            child: Icon(
              isRightDockOpen ? Icons.view_sidebar : Icons.view_sidebar_outlined,
              size: 20,
            ),
          ),
          tooltip: tr.workspaceToggleRightDockTooltip,
          isSelected: isRightDockOpen,
          style: OcptWorkspaceToolbar.chromeButtonStyle,
          onPressed: onToggleRightDock,
        ),
    ];
  }

  /// Builds the toolbar's save control — the button, or the same-sized spinner while [isSaving] —
  /// or null when the mode has nothing to save.
  Widget? _buildSaveAction(BuildContext context) {
    final onSave = this.onSave;
    if (onSave == null) {
      return null;
    }

    if (isSaving) {
      return const SizedBox.square(
        dimension: ocptToolbarChromeButtonSize,
        child: Center(
          child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.save_outlined, size: 20),
      tooltip: Tr.of(context).editorSaveTooltip,
      style: OcptWorkspaceToolbar.chromeButtonStyle,
      onPressed: onSave,
    );
  }

  /// Builds the toolbar's project settings action, or null when the mode withheld it.
  Widget? _buildProjectSettingsAction(BuildContext context) {
    final onProjectSettingsRequested = this.onProjectSettingsRequested;
    if (onProjectSettingsRequested == null) {
      return null;
    }

    return IconButton(
      icon: const Icon(Icons.settings_outlined, size: 20),
      tooltip: Tr.of(context).workspaceProjectSettingsTooltip,
      style: OcptWorkspaceToolbar.chromeButtonStyle,
      onPressed: onProjectSettingsRequested,
    );
  }

  /// Builds the left dock / centre / right dock row, wiring the dividers to
  /// [dockLayoutController] and reporting drag ends through [onDockFractionsChanged].
  ///
  /// Skips the [LayoutBuilder]/[ListenableBuilder]/dock-width machinery entirely when
  /// [dockLayoutController] is null (a mode with no dock at all): [centre] then simply fills the
  /// row.
  Widget _buildDocksRow() {
    final controller = dockLayoutController;
    if (controller == null) {
      return centre;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final rowWidth = constraints.maxWidth;

        return ListenableBuilder(
          listenable: controller,
          builder: (context, child) {
            final widths = OcptWorkspaceDock.resolveDockWidths(
              rowWidth: rowWidth,
              leftFraction: controller.leftFraction,
              rightFraction: controller.rightFraction,
              isLeftDockVisible: leftPanel != null,
              isRightDockVisible: rightPanel != null,
            );

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (leftPanel != null) ...[
                  OcptWorkspaceDock(width: widths.left, child: leftPanel!),
                  OcptWorkspaceDockDivider(
                    onDragUpdate: (deltaX) => controller.setLeftFraction(
                      OcptWorkspaceDock.clampLeftFraction(
                        controller.leftFraction + deltaX / rowWidth,
                        rowWidth,
                      ),
                    ),
                    onDragEnd: () =>
                        onDockFractionsChanged?.call((left: controller.leftFraction, right: null)),
                  ),
                ],
                Expanded(child: centre),
                if (rightPanel != null) ...[
                  OcptWorkspaceDockDivider(
                    onDragUpdate: (deltaX) => controller.setRightFraction(
                      OcptWorkspaceDock.clampRightFraction(
                        controller.rightFraction - deltaX / rowWidth,
                        rowWidth,
                      ),
                    ),
                    onDragEnd: () =>
                        onDockFractionsChanged?.call((left: null, right: controller.rightFraction)),
                  ),
                  OcptWorkspaceDock(width: widths.right, child: rightPanel!),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

/// The value the episode selector's `Manage episodes…` entry carries, distinct from every episode
/// id (a UUID, never empty) — see [OcptWorkspaceShell._buildEpisodeSelector]'s own doc comment for
/// why a [PopupMenuButton] cannot carry a null value for an entry that must still be selectable.
const String _manageEpisodesOption = "";

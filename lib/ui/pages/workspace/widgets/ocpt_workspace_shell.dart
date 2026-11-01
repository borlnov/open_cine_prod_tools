// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_responsive.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell_toolbar.dart';

/// The persistent application chrome around a production mode's own content: a toolbar, an
/// optional full-width [OcptWorkspaceShell.banner] under it, an optional pair of resizable side
/// docks around a centre area, and an optional status bar.
///
/// A mode contributes its own [OcptWorkspaceShell.toolbarActions]/
/// [OcptWorkspaceShell.overflowEntries] (mode-specific controls) and its
/// [OcptWorkspaceShell.leftPanel]/[OcptWorkspaceShell.centre]/[OcptWorkspaceShell.rightPanel]/
/// [OcptWorkspaceShell.statusBar] content; this widget only assembles the layout and the
/// dock-resizing mechanics shared by every mode.
///
/// The controls every mode ends its toolbar with are built here rather than handed in, so their
/// order is the shell's guarantee and no mode can break it: the `modeLabel`, the `Export` control
/// (`onExportRequested`), the dock toggles (`onToggleLeftDock`/`onToggleRightDock`), the save
/// control (`onSave`), the project settings action (`onProjectSettingsRequested`), then the `Help`
/// action (`onHelpRequested`) — each rendered only when the mode wired it, so a mode with nothing
/// to print, no dock, nothing to save, nothing to open there, or no help panel of its own simply
/// shows fewer of them. On a phone ([ocptIsPhoneWidth]) the export, settings and help controls fold
/// out of the toolbar into its `⋮` overflow instead, where the band has room for them. Below
/// [ocptCompactWidthBreakpoint] the title and mode label are dropped from the toolbar entirely
/// instead — both would be cropped noise at that width — and the episode control's single-episode
/// `Add an episode…` button is withheld the same way (the multi-episode selector, and its own
/// phone-width icon-only reduction, are unaffected).
///
/// The episode control sits at the *other* end of the toolbar, right after the title and its
/// dirty marker / `Read only` pill, since it qualifies *which content* is on screen — exactly what
/// the title says too. It is built here from `episodes`/`selectedEpisodeId`/`onEpisodeSelected`
/// rather than handed in as a widget, for the same reason the `Export` control is: so the gesture
/// can't drift from one mode to the next. Its last entry, `Manage episodes…`, reuses
/// `onProjectSettingsRequested` rather than a selector-specific callback — it leads to the very
/// same destination, and reusing it means the entry is withheld automatically while a project
/// version is being previewed, exactly like the toolbar's own settings action.
///
/// That one slot holds the selector for a project with several episodes, and
/// `onAddEpisodeRequested`'s `Add an episode…` button for a project that has a single one — the two
/// are never both drawn, and a mode wiring neither shows nothing at all there.
///
/// This widget knows nothing about any specific mode (the screenplay editor included) beyond the
/// moved [OcptWorkspaceDock]/[OcptWorkspaceDockDivider]/[OcptWorkspaceDockLayoutController]
/// primitives.
///
/// The docks row reuses the drag-doesn't-rebuild-the-centre pattern the screenplay editor
/// pioneered: `leftPanel`, `centre` and `rightPanel` are built once by the caller and handed in as
/// fixed widget instances, then referenced unchanged from inside the [ListenableBuilder] that
/// listens to `dockLayoutController`. A divider drag only ever calls
/// [OcptWorkspaceDockLayoutController.setLeftFraction]/`setRightFraction`, which notifies that
/// builder alone; since it references the very same widget instances on every rebuild, Flutter's
/// `Element.update` short-circuits on their identity and only re-lays-out the resolved widths —
/// the content underneath never rebuilds mid-drag.
///
/// Below [ocptCompactWidthBreakpoint] the two side docks no longer fit as persistent columns
/// beside the centre floor, so the row reduces to edge drawers: the centre fills the width and an
/// open panel slides over it, summoned by the same toolbar dock toggles (see
/// [_OcptWorkspaceCompactDrawers]). This is a pure width reduction — the widget
/// stays presentational and reads no platform.
///
/// This is otherwise a **stateless slot widget with respect to a mode's own content**, exactly as
/// the rest of the app relies on it being: it holds no opinion about what a mode shows, only about
/// how its own chrome is laid out. The one piece of local state it keeps — which side drawer, if
/// any, is open at a compact width — is chrome too, not content: a mode's `isLeftDockOpen`/
/// `isRightDockOpen` flags keep driving the desktop side-by-side docks exactly as before, and the
/// compact reduction below is a presentation choice this widget makes entirely on its own (see
/// [_OcptWorkspaceShellState._compactDrawer]'s own doc comment). That is the only reason this is a
/// [StatefulWidget] rather than the [StatelessWidget] it otherwise reads as.
class OcptWorkspaceShell extends StatefulWidget {
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

  /// Called when the toolbar's `Add an episode…` button is clicked, or null when the mode withholds
  /// it — which every mode but the screenplay one does.
  ///
  /// This button takes the episode selector's own place while the project holds a single episode,
  /// and is the only thing naming an episode on such a project: nothing else would ever say a
  /// project *can* hold several, the settings page's `Episodes` card being reachable only by
  /// someone already looking for it. It is the screenplay mode's alone because that is where an
  /// episode is written — a `screenplays` row *is* one — and because one such button in the whole
  /// app is what makes it a discovery rather than a recurring offer.
  ///
  /// A mode must withhold it while a project version is being previewed, exactly like
  /// [onProjectSettingsRequested], which is where it leads. Below [ocptCompactWidthBreakpoint] the
  /// shell withholds it on its own, regardless of this callback: there is no room for a discovery
  /// affordance at that width, and the episode selector — the button's only alternative in that
  /// slot — is unaffected.
  final VoidCallback? onAddEpisodeRequested;

  /// The active mode's own toolbar controls, right-aligned before the overflow menu.
  final List<Widget> toolbarActions;

  /// The active mode's name, shown muted in the toolbar between the mode's own [toolbarActions]
  /// and the chrome the shell builds itself, or null to show no label.
  final String? modeLabel;

  /// Called when the toolbar's `Export` control is clicked, or null when the mode prints nothing —
  /// no control is rendered at all then, rather than a disabled one.
  ///
  /// Carries the control's own screen `Rect` at the moment it was tapped — null from the phone
  /// overflow menu, where no control's own bounds are meaningful — which a mode threads down to
  /// whichever export it ends up dispatching, for `Share.shareXFiles`' iPad/Mac popover anchor
  /// (`OcptExportManager` sees no `BuildContext` to resolve one itself).
  final ValueSetter<Rect?>? onExportRequested;

  /// The `⋮` overflow menu's entries. An empty list renders no `⋮` button at all.
  final List<PopupMenuEntry<void>> overflowEntries;

  /// Whether the left dock is open, driving its toolbar toggle's selected state.
  ///
  /// Only above [ocptCompactWidthBreakpoint]: below it, which drawer (if any) is visible is this
  /// shell's own local state, since both docks start closed there regardless of this flag (see the
  /// class doc comment).
  final bool isLeftDockOpen;

  /// Called when the toolbar's left dock toggle is clicked, or null when the mode has no left dock
  /// to toggle — no toggle is rendered at all then.
  ///
  /// Only reached above [ocptCompactWidthBreakpoint]: below it, the very same toggle drives this
  /// shell's own local drawer state instead (see the class doc comment), since a mode's flag would
  /// otherwise start the drawer open on a phone the moment its mode does.
  final VoidCallback? onToggleLeftDock;

  /// Whether the right dock is open, driving its toolbar toggle's selected state.
  ///
  /// Only above [ocptCompactWidthBreakpoint]; see [isLeftDockOpen]'s own doc comment.
  final bool isRightDockOpen;

  /// Called when the toolbar's right dock toggle is clicked, or null when the mode has no right
  /// dock to toggle — no toggle is rendered at all then.
  ///
  /// Only reached above [ocptCompactWidthBreakpoint]; see [onToggleLeftDock]'s own doc comment.
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

  /// Called when the toolbar's `Help` action is clicked, or null when the mode has no help panel to
  /// open — no control is rendered at all then, rather than a disabled one.
  ///
  /// Unlike [onProjectSettingsRequested], this one is never withheld under a version preview: a
  /// help panel only reads, it never writes, so there is nothing about it a preview needs to
  /// protect. Only the budget mode wires it in today (`docs/architecture/budget.md`), opening its
  /// own right dock on its `Help` tab rather than a dialog.
  final VoidCallback? onHelpRequested;

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
    this.onAddEpisodeRequested,
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
    this.onHelpRequested,
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

  /// Create the [_OcptWorkspaceShellState] holding the state of the workspace shell.
  @override
  State<OcptWorkspaceShell> createState() => _OcptWorkspaceShellState();
}

/// Which side drawer, if any, [_OcptWorkspaceShellState] shows below [ocptCompactWidthBreakpoint].
///
/// A single value rather than two independent booleans is what makes the two drawers mutually
/// exclusive *by construction* — there is no state this enum can hold in which both sides are
/// open at once.
enum _OcptCompactDrawerSide {
  /// Neither drawer is open — the starting state every time a mode mounts at a compact width.
  none,

  /// The left drawer is open.
  left,

  /// The right drawer is open.
  right,
}

/// State of [OcptWorkspaceShell]: tracks which compact drawer, if any, is open.
class _OcptWorkspaceShellState extends State<OcptWorkspaceShell> {
  /// Which side drawer, if any, is open below [ocptCompactWidthBreakpoint].
  ///
  /// This is the shell's own **chrome** state, not a mode's content: above the breakpoint the
  /// side-by-side docks keep reading [OcptWorkspaceShell.isLeftDockOpen]/
  /// [OcptWorkspaceShell.isRightDockOpen] exactly as before, and this field is simply unused. Below
  /// it, honouring those mode-owned flags for visibility would mean a mode that defaults to open
  /// (most do) covers the whole centre with a drawer the moment it mounts on a phone — so
  /// visibility is driven from here instead, starting closed regardless of what the mode's own
  /// flags say. A fresh mode mount (a mode switch, an episode switch) creates a fresh [State] and
  /// so a fresh `none`, which is what "starts closed" means in practice — there is no reset to
  /// write by hand.
  _OcptCompactDrawerSide _compactDrawer = _OcptCompactDrawerSide.none;

  /// Open or close the compact drawer of a side when its dock opens or closes programmatically.
  @override
  void didUpdateWidget(OcptWorkspaceShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    // A mode opens a dock programmatically as well as by the toolbar's toggle — the budget fiche
    // opens the right dock the moment a line is created or selected, say. Below the breakpoint that
    // open has to reach [_compactDrawer], the sole driver of drawer visibility there; left
    // unsynced it would be swallowed and the drawer stay shut. Only a false→true transition opens
    // (so a mode that merely *defaults* a flag to open still starts closed on a phone — this never
    // runs on the first build), and a true→false one closes that side when it is the one showing.
    // Assigning a single enum value keeps the drawers mutually exclusive here too. It is harmless
    // above the breakpoint, where [_compactDrawer] is unused; no `setState` is needed, the rebuild
    // that follows `didUpdateWidget` reads the field as it now stands.
    if (!oldWidget.isLeftDockOpen && widget.isLeftDockOpen) {
      _compactDrawer = _OcptCompactDrawerSide.left;
    } else if (oldWidget.isLeftDockOpen &&
        !widget.isLeftDockOpen &&
        _compactDrawer == _OcptCompactDrawerSide.left) {
      _compactDrawer = _OcptCompactDrawerSide.none;
    }

    if (!oldWidget.isRightDockOpen && widget.isRightDockOpen) {
      _compactDrawer = _OcptCompactDrawerSide.right;
    } else if (oldWidget.isRightDockOpen &&
        !widget.isRightDockOpen &&
        _compactDrawer == _OcptCompactDrawerSide.right) {
      _compactDrawer = _OcptCompactDrawerSide.none;
    }
  }

  /// Build the workspace shell as a [LayoutBuilder].
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // On a phone the toolbar has no room for its secondary actions beside the mode's own, so the
      // export, project-settings and help controls fold from their toolbar slots into the `⋮`
      // overflow instead (see [OcptWorkspaceShellToolbar]). Above a phone they stay toolbar
      // controls, exactly as before.
      final isPhone = ocptIsPhoneWidth(constraints.maxWidth);
      // Below this width the title, the mode label and the single-episode `Add an episode…`
      // button are dropped from the toolbar entirely, and the docks row reduces to drawers (see
      // [_OcptWorkspaceDocksRow]).
      final isCompact = ocptIsCompactWidth(constraints.maxWidth);

      return Column(
        children: [
          OcptWorkspaceShellToolbar(
            shell: widget,
            isPhone: isPhone,
            isCompact: isCompact,
            isLeftDockToggledOn: isCompact
                ? _compactDrawer == _OcptCompactDrawerSide.left
                : widget.isLeftDockOpen,
            isRightDockToggledOn: isCompact
                ? _compactDrawer == _OcptCompactDrawerSide.right
                : widget.isRightDockOpen,
            onLeftDockToggled: widget.onToggleLeftDock == null
                ? null
                : isCompact
                ? () => _toggleCompactDrawer(_OcptCompactDrawerSide.left)
                : widget.onToggleLeftDock,
            onRightDockToggled: widget.onToggleRightDock == null
                ? null
                : isCompact
                ? () => _toggleCompactDrawer(_OcptCompactDrawerSide.right)
                : widget.onToggleRightDock,
          ),
          if (widget.banner != null) widget.banner!,
          Expanded(
            child: _OcptWorkspaceDocksRow(
              shell: widget,
              isCompact: isCompact,
              compactDrawer: _compactDrawer,
              onCompactDrawerClosed: _closeCompactDrawer,
            ),
          ),
          if (widget.statusBar != null) widget.statusBar!,
        ],
      );
    },
  );

  /// Open [side], or close it back to [_OcptCompactDrawerSide.none] when it is already the open
  /// one — the compact dock toggle's own tap handler. Assigning a single enum value is what keeps
  /// the two drawers mutually exclusive: opening one always replaces whatever the other held.
  ///
  /// A side's drawer only shows once the mode has actually built that side's panel, and a mode
  /// builds a panel gated on its own dock flag — the right dock's tabbed inspector is null until
  /// the dock is opened, say. So opening a side whose mode dock is still closed also fires the
  /// mode's own toggle callback, exactly the tap the desktop dock button makes, to get the panel
  /// built; [didUpdateWidget] then re-syncs [_compactDrawer] to the flag that just flipped (already
  /// this side). Without it the right toggle looked dead on a phone: the drawer had nothing to
  /// show.
  void _toggleCompactDrawer(_OcptCompactDrawerSide side) {
    final isOpening = _compactDrawer != side;
    setState(() {
      _compactDrawer = isOpening ? side : _OcptCompactDrawerSide.none;
    });

    if (!isOpening) {
      return;
    }
    if (side == _OcptCompactDrawerSide.left && !widget.isLeftDockOpen) {
      widget.onToggleLeftDock?.call();
    } else if (side == _OcptCompactDrawerSide.right && !widget.isRightDockOpen) {
      widget.onToggleRightDock?.call();
    }
  }

  /// Close whichever drawer is open — the scrim's own tap handler.
  void _closeCompactDrawer() {
    setState(() => _compactDrawer = _OcptCompactDrawerSide.none);
  }
}

/// Build the left dock / centre / right dock row, wiring the dividers to
/// [OcptWorkspaceShell.dockLayoutController] and reporting drag ends through
/// [OcptWorkspaceShell.onDockFractionsChanged].
///
/// Skips the [LayoutBuilder]/[ListenableBuilder]/dock-width machinery entirely when
/// [OcptWorkspaceShell.dockLayoutController] is null (a mode with no dock at all): `centre` then
/// simply fills the row.
///
/// Below [ocptCompactWidthBreakpoint] ([isCompact], resolved once by the caller from the very
/// same width [build] already reads for the toolbar) the two side docks can no longer coexist
/// with the centre floor as persistent columns, so the row reduces to [_OcptWorkspaceCompactDrawers]:
/// `centre` fills the whole width and at most one panel slides over it as an edge drawer,
/// summoned by the toolbar's own dock toggles. Above the breakpoint the row keeps its persistent
/// side columns unchanged.
class _OcptWorkspaceDocksRow extends StatelessWidget {
  /// The shell whose panels and callbacks the row lays out.
  final OcptWorkspaceShell shell;

  /// Whether the window is below [ocptCompactWidthBreakpoint].
  final bool isCompact;

  /// Which compact drawer, if any, is open.
  final _OcptCompactDrawerSide compactDrawer;

  /// Called when the scrim closes the open compact drawer.
  final VoidCallback onCompactDrawerClosed;

  /// Class constructor
  const _OcptWorkspaceDocksRow({
    required this.shell,
    required this.isCompact,
    required this.compactDrawer,
    required this.onCompactDrawerClosed,
  });

  /// Build the workspace docks row as a [LayoutBuilder].
  @override
  Widget build(BuildContext context) {
    final controller = shell.dockLayoutController;
    if (controller == null) {
      return shell.centre;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final rowWidth = constraints.maxWidth;

        if (isCompact) {
          return _OcptWorkspaceCompactDrawers(
            shell: shell,
            compactDrawer: compactDrawer,
            rowWidth: rowWidth,
            onCompactDrawerClosed: onCompactDrawerClosed,
          );
        }

        return ListenableBuilder(
          listenable: controller,
          builder: (context, child) {
            final widths = OcptWorkspaceDock.resolveDockWidths(
              rowWidth: rowWidth,
              leftFraction: controller.leftFraction,
              rightFraction: controller.rightFraction,
              isLeftDockVisible: shell.leftPanel != null,
              isRightDockVisible: shell.rightPanel != null,
            );

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (shell.leftPanel != null) ...[
                  OcptWorkspaceDock(width: widths.left, child: shell.leftPanel!),
                  OcptWorkspaceDockDivider(
                    onDragUpdate: (deltaX) => controller.setLeftFraction(
                      OcptWorkspaceDock.clampLeftFraction(
                        controller.leftFraction + deltaX / rowWidth,
                        rowWidth,
                      ),
                    ),
                    onDragEnd: () => shell.onDockFractionsChanged?.call((
                      left: controller.leftFraction,
                      right: null,
                    )),
                  ),
                ],
                Expanded(child: shell.centre),
                if (shell.rightPanel != null) ...[
                  OcptWorkspaceDockDivider(
                    onDragUpdate: (deltaX) => controller.setRightFraction(
                      OcptWorkspaceDock.clampRightFraction(
                        controller.rightFraction - deltaX / rowWidth,
                        rowWidth,
                      ),
                    ),
                    onDragEnd: () => shell.onDockFractionsChanged?.call((
                      left: null,
                      right: controller.rightFraction,
                    )),
                  ),
                  OcptWorkspaceDock(width: widths.right, child: shell.rightPanel!),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

/// Build the compact-width presentation of the docks row: [OcptWorkspaceShell.centre] fills the
/// whole row of [rowWidth], and at most one side panel — [compactDrawer]'s own choice — slides
/// over it as an edge drawer, dimming the centre behind a scrim that closes the drawer when
/// tapped.
///
/// The drawers are summoned by the toolbar's own dock toggles (`OcptWorkspaceShellToolbar`), but their
/// visibility here is [compactDrawer] alone — never
/// [OcptWorkspaceShell.isLeftDockOpen]/[OcptWorkspaceShell.isRightDockOpen] — which is what keeps
/// both closed the moment a mode mounts and keeps the two mutually exclusive no matter what a
/// mode's own flags say. A side whose panel the mode never built
/// ([OcptWorkspaceShell.leftPanel]/[OcptWorkspaceShell.rightPanel] null) still has no drawer at
/// all regardless of [compactDrawer], exactly as it has no column at an expanded width.
///
/// A tablet-width drawer ([ocptIsPhoneWidth] false — a tablet in portrait, a narrow desktop
/// window) opens to its dock's own fraction of the row and carries the same
/// [OcptWorkspaceDockDivider] a persistent column has on its centre-facing edge, so it can be
/// resized by touch just as a column is by mouse; the drag reuses the very same
/// [OcptWorkspaceShell.dockLayoutController] fraction, so a width set in portrait carries over to
/// the landscape columns and back. A phone-width drawer fills the whole row instead — there is no
/// centre left to keep in view, so there is nothing to resize against and no divider is drawn.
/// The whole thing is wrapped in a [ListenableBuilder] on the controller so a resize drag
/// re-lays-out the drawer without rebuilding the centre underneath, the same pattern the
/// persistent columns use.
class _OcptWorkspaceCompactDrawers extends StatelessWidget {
  /// The shell whose panels and callbacks the row lays out.
  final OcptWorkspaceShell shell;

  /// Which compact drawer, if any, is open.
  final _OcptCompactDrawerSide compactDrawer;

  /// The width of the docks row.
  final double rowWidth;

  /// Called when the scrim closes the open drawer.
  final VoidCallback onCompactDrawerClosed;

  /// Class constructor
  const _OcptWorkspaceCompactDrawers({
    required this.shell,
    required this.compactDrawer,
    required this.rowWidth,
    required this.onCompactDrawerClosed,
  });

  /// Build the workspace compact drawers as a [ListenableBuilder].
  @override
  Widget build(BuildContext context) {
    // Non-null in this branch: [_OcptWorkspaceDocksRow] returns the bare centre when the controller is
    // null.
    final controller = shell.dockLayoutController!;
    final leftPanel = shell.leftPanel;
    final rightPanel = shell.rightPanel;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final colorScheme = Theme.of(context).colorScheme;
        final isLeftDrawerOpen = leftPanel != null && compactDrawer == _OcptCompactDrawerSide.left;
        final isRightDrawerOpen =
            rightPanel != null && compactDrawer == _OcptCompactDrawerSide.right;

        return Stack(
          children: [
            Positioned.fill(child: shell.centre),
            if (isLeftDrawerOpen || isRightDrawerOpen)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onCompactDrawerClosed,
                  child: ColoredBox(color: colorScheme.scrim.withValues(alpha: 0.46)),
                ),
              ),
            if (isLeftDrawerOpen)
              _OcptWorkspaceCompactDrawer(
                controller: controller,
                rowWidth: rowWidth,
                isLeft: true,
                panel: leftPanel,
                onDockFractionsChanged: shell.onDockFractionsChanged,
              ),
            if (isRightDrawerOpen)
              _OcptWorkspaceCompactDrawer(
                controller: controller,
                rowWidth: rowWidth,
                isLeft: false,
                panel: rightPanel,
                onDockFractionsChanged: shell.onDockFractionsChanged,
              ),
          ],
        );
      },
    );
  }
}

/// Build one open compact drawer, anchored to [isLeft]'s edge of the row of [rowWidth].
///
/// On a phone ([ocptIsPhoneWidth]) it fills the whole row and is not resizable. On a wider
/// compact row it opens to [controller]'s clamped fraction and carries an
/// [OcptWorkspaceDockDivider] on its centre-facing edge, wired exactly like the matching
/// persistent column's — the left drawer's handle on its right, the right drawer's on its left —
/// so the drag sign and the persistence through [OcptWorkspaceShell.onDockFractionsChanged] are
/// identical.
class _OcptWorkspaceCompactDrawer extends StatelessWidget {
  /// The controller holding the dock fractions.
  final OcptWorkspaceDockLayoutController controller;

  /// The width of the docks row.
  final double rowWidth;

  /// Whether the drawer is anchored to the left edge.
  final bool isLeft;

  /// The panel the drawer shows.
  final Widget panel;

  /// Called with the fractions a resize drag ended on.
  final ValueChanged<({double? left, double? right})>? onDockFractionsChanged;

  /// Class constructor
  const _OcptWorkspaceCompactDrawer({
    required this.controller,
    required this.rowWidth,
    required this.isLeft,
    required this.panel,
    required this.onDockFractionsChanged,
  });

  /// Build the workspace compact drawer as a [Positioned].
  @override
  Widget build(BuildContext context) {
    if (ocptIsPhoneWidth(rowWidth)) {
      return Positioned(
        top: 0,
        bottom: 0,
        left: isLeft ? 0 : null,
        right: isLeft ? null : 0,
        width: rowWidth,
        child: OcptWorkspaceDock(width: rowWidth, child: panel),
      );
    }

    final fraction = isLeft
        ? OcptWorkspaceDock.clampLeftFraction(controller.leftFraction, rowWidth)
        : OcptWorkspaceDock.clampRightFraction(controller.rightFraction, rowWidth);
    final drawerWidth = fraction * rowWidth;

    final divider = OcptWorkspaceDockDivider(
      onDragUpdate: (deltaX) => isLeft
          ? controller.setLeftFraction(
              OcptWorkspaceDock.clampLeftFraction(
                controller.leftFraction + deltaX / rowWidth,
                rowWidth,
              ),
            )
          : controller.setRightFraction(
              OcptWorkspaceDock.clampRightFraction(
                controller.rightFraction - deltaX / rowWidth,
                rowWidth,
              ),
            ),
      onDragEnd: () => onDockFractionsChanged?.call(
        isLeft
            ? (left: controller.leftFraction, right: null)
            : (left: null, right: controller.rightFraction),
      ),
    );
    final dock = OcptWorkspaceDock(width: drawerWidth, child: panel);

    return Positioned(
      top: 0,
      bottom: 0,
      left: isLeft ? 0 : null,
      right: isLeft ? null : 0,
      width: drawerWidth + OcptWorkspaceDock.dividerHitWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: isLeft ? [dock, divider] : [divider, dock],
      ),
    );
  }
}

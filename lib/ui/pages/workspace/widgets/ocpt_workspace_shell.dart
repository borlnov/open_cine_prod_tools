// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_presence_indicator.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_dock_layout_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_toolbar.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_export_share_anchor.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_workspace_episode_label.dart';
import 'package:open_cine_prod_tools/utils/ocpt_responsive.dart';

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
/// [_OcptWorkspaceShellState._buildCompactDrawers]). This is a pure width reduction — the widget
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

class _OcptWorkspaceShellState extends State<OcptWorkspaceShell> {
  /// Which side drawer, if any, is open below [ocptCompactWidthBreakpoint].
  ///
  /// This is the shell's own **chrome** state, not a mode's content: above the breakpoint the
  /// side-by-side docks keep reading [OcptWorkspaceShell.isLeftDockOpen]/
  /// [OcptWorkspaceShell.isRightDockOpen] exactly as before, and this field is simply unused. Below
  /// it, honouring those mode-owned flags for visibility would mean a mode that defaults to open
  /// (most do) covers the whole centre with a drawer the moment it mounts on a phone — so visibility
  /// is driven from here instead, starting closed regardless of what the mode's own flags say. A
  /// fresh mode mount (a mode switch, an episode switch) creates a fresh [State] and so a fresh
  /// `none`, which is what "starts closed" means in practice — there is no reset to write by hand.
  _OcptCompactDrawerSide _compactDrawer = _OcptCompactDrawerSide.none;

  /// Opens [side], or closes it back to [_OcptCompactDrawerSide.none] when it is already the open
  /// one — the compact dock toggle's own tap handler. Assigning a single enum value is what keeps
  /// the two drawers mutually exclusive: opening one always replaces whatever the other held.
  void _toggleCompactDrawer(_OcptCompactDrawerSide side) {
    setState(() {
      _compactDrawer = _compactDrawer == side ? _OcptCompactDrawerSide.none : side;
    });
  }

  /// Closes whichever drawer is open — the scrim's own tap handler.
  void _closeCompactDrawer() {
    setState(() => _compactDrawer = _OcptCompactDrawerSide.none);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // On a phone the toolbar has no room for its secondary actions beside the mode's own, so the
      // export, project-settings and help controls fold from their toolbar slots into the `⋮`
      // overflow instead (see [_buildFoldedChromeEntries]). Above a phone they stay toolbar
      // controls, exactly as before.
      final isPhone = ocptIsPhoneWidth(constraints.maxWidth);
      // Below this width the title, the mode label and the single-episode `Add an episode…`
      // button are dropped from the toolbar entirely, and the docks row reduces to drawers (see
      // [_buildDocksRow]).
      final isCompact = ocptIsCompactWidth(constraints.maxWidth);

      return Column(
        children: [
          OcptWorkspaceToolbar(
            title: widget.title,
            isDirty: widget.isDirty,
            isReadOnly: widget.isReadOnly,
            isCompact: isCompact,
            onBack: widget.onBack,
            episodeControl: _buildEpisodeControl(context, isPhone, isCompact),
            actions: widget.toolbarActions,
            modeLabel: widget.modeLabel,
            presenceIndicator: const OcptPresenceIndicator(),
            exportAction: isPhone ? null : _buildExportAction(context),
            dockToggles: _buildDockToggles(context, isCompact),
            saveAction: _buildSaveAction(context),
            projectSettingsAction: isPhone ? null : _buildProjectSettingsAction(context),
            helpAction: isPhone ? null : _buildHelpAction(context),
            overflowEntries: isPhone
                ? _buildPhoneOverflowEntries(context)
                : widget.overflowEntries,
          ),
          if (widget.banner != null) widget.banner!,
          Expanded(child: _buildDocksRow(isCompact)),
          if (widget.statusBar != null) widget.statusBar!,
        ],
      );
    },
  );

  /// Builds the `⋮` overflow entries on a phone: the export, project-settings and help actions the
  /// toolbar folded out of its own slots, above the mode's own [OcptWorkspaceShell.overflowEntries],
  /// separated from them by a divider when both groups are present.
  ///
  /// Each folded action guards on its own callback, exactly as the toolbar slot it replaces did, so
  /// a mode that withholds one (the settings action under a version preview, the help action every
  /// mode but the budget one) simply contributes no entry for it. When nothing folds, the mode's
  /// own entries are returned untouched.
  List<PopupMenuEntry<void>> _buildPhoneOverflowEntries(BuildContext context) {
    final folded = _buildFoldedChromeEntries(context);
    if (folded.isEmpty) {
      return widget.overflowEntries;
    }

    return [
      ...folded,
      if (widget.overflowEntries.isNotEmpty) const PopupMenuDivider(),
      ...widget.overflowEntries,
    ];
  }

  /// Builds the folded export / project-settings / help entries for [_buildPhoneOverflowEntries],
  /// each rendered only when the mode wired its callback, in the same order they hold in the
  /// toolbar. Their labels reuse the controls' own strings, and each fires the very same callback
  /// its toolbar control does.
  List<PopupMenuEntry<void>> _buildFoldedChromeEntries(BuildContext context) {
    final tr = Tr.of(context);
    final onExportRequested = widget.onExportRequested;
    final onProjectSettingsRequested = widget.onProjectSettingsRequested;
    final onHelpRequested = widget.onHelpRequested;

    return [
      // No control's own bounds are meaningful once the gesture came through a menu item rather
      // than the toolbar button itself, so this is the one caller that always hands down null.
      if (onExportRequested != null)
        PopupMenuItem<void>(
          onTap: () => onExportRequested(null),
          child: Text(tr.workspaceExportAction),
        ),
      if (onProjectSettingsRequested != null)
        PopupMenuItem<void>(
          onTap: onProjectSettingsRequested,
          child: Text(tr.workspaceProjectSettingsTooltip),
        ),
      if (onHelpRequested != null)
        PopupMenuItem<void>(onTap: onHelpRequested, child: Text(tr.workspaceHelpTooltip)),
    ];
  }

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
  ///
  /// Wrapped in its own [Builder] so `onPressed` can resolve the button's own screen [Rect] from
  /// its `RenderBox` at tap time — the anchor [OcptWorkspaceShell.onExportRequested] hands down for
  /// the OS share sheet's iPad/Mac popover — without this widget itself needing a [GlobalKey].
  Widget? _buildExportAction(BuildContext context) {
    final onExportRequested = widget.onExportRequested;
    if (onExportRequested == null) {
      return null;
    }

    final tr = Tr.of(context);

    return Tooltip(
      message: tr.workspaceExportTooltip,
      child: Builder(
        builder: (buttonContext) => TextButton.icon(
          onPressed: () => onExportRequested(ocptExportShareAnchorOf(buttonContext)),
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
      ),
    );
  }

  /// Builds whatever fills the toolbar's episode slot: the selector for a project holding several
  /// episodes, the `Add an episode…` button for one holding a single one, or null for neither.
  ///
  /// The two guard themselves on [OcptWorkspaceShell.episodes]'s own length, so the order they are
  /// tried in never decides anything: a project can't be both at once.
  ///
  /// On a phone ([isPhone]) the selector reduces to an icon-only chrome button: the real control
  /// carries a label as wide as the episode's own title, which the phone toolbar has no room for
  /// beside the mode's own controls, and a label-bearing control squeezed into a `Flexible` there
  /// overflows its own icon rather than ellipsizing cleanly. The label lives in the tooltip then.
  ///
  /// Below [ocptCompactWidthBreakpoint] ([isCompact]) the `Add an episode…` button is withheld
  /// outright rather than reduced further — it is a discovery affordance nobody is looking for, and
  /// there is no room left to spend on one at that width. The selector is unaffected: it still
  /// reduces to its own phone-width icon trigger, since a project already known to be a series must
  /// still let its episode be switched, and [ocptPhoneWidthBreakpoint] is always below
  /// [ocptCompactWidthBreakpoint], so a phone never has to reduce the button — it never sees it.
  Widget? _buildEpisodeControl(BuildContext context, bool isPhone, bool isCompact) =>
      _buildEpisodeSelector(context, isPhone) ??
      (isCompact ? null : _buildAddEpisodeAction(context));

  /// Builds the toolbar's episode selector, or null when [OcptWorkspaceShell.onEpisodeSelected] is
  /// null or [OcptWorkspaceShell.episodes] holds at most one — no control is rendered at all then,
  /// rather than a disabled one, exactly like [_buildExportAction].
  ///
  /// The trigger reads the selected episode's own label; the menu lists every episode with the
  /// selected one marked, followed by `Manage episodes…` when
  /// [OcptWorkspaceShell.onProjectSettingsRequested] is wired (see the class doc comment for why it
  /// is that callback rather than a new one). That entry carries [_manageEpisodesOption] rather than
  /// null: a [PopupMenuButton] cannot carry a null value for an entry that must still be selectable,
  /// since it can't tell that apart from the menu being dismissed without a pick
  /// (`OcptResourcesPersonPicker`'s own `_nobodyOption` is the same workaround, for the same reason).
  ///
  /// It wraps itself in a [Flexible] — the toolbar wraps nothing itself — because an episode's
  /// title is as long as the user made it: on a window too narrow for the whole toolbar, this is
  /// the control that gives width up, its trigger ellipsizing like the project title beside it. On
  /// a phone ([isPhone]) it is an icon-only fixed trigger instead (its label in the tooltip), since
  /// the phone toolbar has no room to ellipsize a title beside the mode's own controls.
  Widget? _buildEpisodeSelector(BuildContext context, bool isPhone) {
    final onEpisodeSelected = widget.onEpisodeSelected;
    if (onEpisodeSelected == null || widget.episodes.length <= 1) {
      return null;
    }

    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final onProjectSettingsRequested = widget.onProjectSettingsRequested;
    final selected = _episodeById(widget.selectedEpisodeId);

    final button = PopupMenuButton<String>(
      tooltip: tr.workspaceEpisodeSelectorTooltip,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      onSelected: (value) => value == _manageEpisodesOption
          ? onProjectSettingsRequested?.call()
          : onEpisodeSelected(value),
      itemBuilder: (context) => [
        for (final episode in widget.episodes)
          PopupMenuItem<String>(
            value: episode.id,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  child: episode.id == widget.selectedEpisodeId
                      ? const Icon(Icons.check, size: 16)
                      : null,
                ),
                const SizedBox(width: 6),
                Text(ocptWorkspaceEpisodeLabelOf(tr, episode)),
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
      child: isPhone
          ? _buildEpisodeIconTrigger(theme)
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                height: ocptToolbarChromeButtonSize,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        selected == null ? "" : ocptWorkspaceEpisodeLabelOf(tr, selected),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
    );

    // On a phone the trigger is a fixed, icon-only chrome button, so it stays out of the toolbar's
    // flexible width entirely; only on a wider window does it share (and give up) that width.
    return isPhone ? button : Flexible(child: button);
  }

  /// Builds the phone-width, icon-only trigger for [_buildEpisodeSelector]: a fixed chrome-sized
  /// glyph pair (an episode library icon and the dropdown caret), reading which episode is on
  /// screen from its tooltip rather than a label the phone toolbar has no room for.
  Widget _buildEpisodeIconTrigger(ThemeData theme) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: SizedBox(
      height: ocptToolbarChromeButtonSize,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.video_library_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
          Icon(Icons.arrow_drop_down, size: 16, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    ),
  );

  /// Builds the toolbar's `Add an episode…` button, or null when
  /// [OcptWorkspaceShell.onAddEpisodeRequested] is null or [OcptWorkspaceShell.episodes] holds
  /// anything other than exactly one.
  ///
  /// The empty list is deliberately not the button's case either: it means the project's episodes
  /// haven't loaded yet, and a button flashing in for one frame before the selector replaces it
  /// would be a lie about a project that turns out to be a series.
  ///
  /// It is dressed as the selector it stands in for rather than as an action: muted foreground,
  /// [TextTheme.bodySmall], no fill. Sizing it to the toolbar band takes the same two overrides
  /// [_buildExportAction] documents at length, and neither alone is enough.
  ///
  /// It is laid out by hand rather than as a [TextButton.icon] so its label sits in a [Flexible]:
  /// this control shares the toolbar's flexible width with the project title, and a window too
  /// narrow for the whole band ellipsizes the label down to the glyph instead of striping the row.
  ///
  /// Never called at all below [ocptCompactWidthBreakpoint] — [_buildEpisodeControl] withholds it
  /// there itself — and [ocptPhoneWidthBreakpoint] is always below that breakpoint too, so this
  /// method never has to reduce itself to an icon-only trigger the way the selector does: by the
  /// time it runs, the toolbar is already wide enough for its label.
  Widget? _buildAddEpisodeAction(BuildContext context) {
    final onAddEpisodeRequested = widget.onAddEpisodeRequested;
    if (onAddEpisodeRequested == null || widget.episodes.length != 1) {
      return null;
    }

    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Flexible(
      child: Tooltip(
        message: tr.workspaceAddEpisodeTooltip,
        child: TextButton(
          onPressed: onAddEpisodeRequested,
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            textStyle: theme.textTheme.bodySmall,
            minimumSize: const Size(0, ocptToolbarChromeButtonSize),
            maximumSize: const Size(double.infinity, ocptToolbarChromeButtonSize),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.standard,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.playlist_add, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  tr.workspaceAddEpisodeAction,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The episode of [OcptWorkspaceShell.episodes] whose id is [id], or null while [id] is null or
  /// names none of them — the moment right after the project's episodes changed under a stale
  /// selection, before the workspace bloc has re-resolved it.
  OcptEpisode? _episodeById(String? id) {
    for (final episode in widget.episodes) {
      if (episode.id == id) {
        return episode;
      }
    }

    return null;
  }

  /// Builds the toolbar's dock toggles, left one first, skipping whichever side the mode gave no
  /// callback for.
  ///
  /// Both wear the same sidebar glyph, the right one mirrored, so the pair reads as one control
  /// per side of the workspace; the `iconButtonTheme` paints the open one with its accent wash.
  ///
  /// Above [ocptCompactWidthBreakpoint] ([isCompact] false) a tap calls the mode's own
  /// [OcptWorkspaceShell.onToggleLeftDock]/[OcptWorkspaceShell.onToggleRightDock] and the button's
  /// selected state reads the mode's own [OcptWorkspaceShell.isLeftDockOpen]/
  /// [OcptWorkspaceShell.isRightDockOpen] flag, exactly as before. Below it, the very same buttons
  /// drive [_compactDrawer] instead — the mode's own flags and callbacks are not consulted at all —
  /// so the mode never has to know its dock became a drawer, and the shell never has to know
  /// anything about what that drawer contains.
  List<Widget> _buildDockToggles(BuildContext context, bool isCompact) {
    final tr = Tr.of(context);
    final onToggleLeftDock = widget.onToggleLeftDock;
    final onToggleRightDock = widget.onToggleRightDock;

    final isLeftOpen = isCompact
        ? _compactDrawer == _OcptCompactDrawerSide.left
        : widget.isLeftDockOpen;
    final isRightOpen = isCompact
        ? _compactDrawer == _OcptCompactDrawerSide.right
        : widget.isRightDockOpen;

    return [
      if (onToggleLeftDock != null)
        IconButton(
          icon: Icon(isLeftOpen ? Icons.view_sidebar : Icons.view_sidebar_outlined, size: 20),
          tooltip: tr.workspaceToggleLeftDockTooltip,
          isSelected: isLeftOpen,
          style: OcptWorkspaceToolbar.chromeButtonStyle,
          onPressed: isCompact
              ? () => _toggleCompactDrawer(_OcptCompactDrawerSide.left)
              : onToggleLeftDock,
        ),
      if (onToggleRightDock != null)
        IconButton(
          icon: Transform.flip(
            flipX: true,
            child: Icon(isRightOpen ? Icons.view_sidebar : Icons.view_sidebar_outlined, size: 20),
          ),
          tooltip: tr.workspaceToggleRightDockTooltip,
          isSelected: isRightOpen,
          style: OcptWorkspaceToolbar.chromeButtonStyle,
          onPressed: isCompact
              ? () => _toggleCompactDrawer(_OcptCompactDrawerSide.right)
              : onToggleRightDock,
        ),
    ];
  }

  /// Builds the toolbar's save control — the button, or the same-sized spinner while
  /// [OcptWorkspaceShell.isSaving] — or null when the mode has nothing to save.
  Widget? _buildSaveAction(BuildContext context) {
    final onSave = widget.onSave;
    if (onSave == null) {
      return null;
    }

    if (widget.isSaving) {
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
    final onProjectSettingsRequested = widget.onProjectSettingsRequested;
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

  /// Builds the toolbar's `Help` action, or null when the mode withheld it.
  Widget? _buildHelpAction(BuildContext context) {
    final onHelpRequested = widget.onHelpRequested;
    if (onHelpRequested == null) {
      return null;
    }

    return IconButton(
      icon: const Icon(Icons.help_outline, size: 20),
      tooltip: Tr.of(context).workspaceHelpTooltip,
      style: OcptWorkspaceToolbar.chromeButtonStyle,
      onPressed: onHelpRequested,
    );
  }

  /// Builds the left dock / centre / right dock row, wiring the dividers to
  /// [OcptWorkspaceShell.dockLayoutController] and reporting drag ends through
  /// [OcptWorkspaceShell.onDockFractionsChanged].
  ///
  /// Skips the [LayoutBuilder]/[ListenableBuilder]/dock-width machinery entirely when
  /// [OcptWorkspaceShell.dockLayoutController] is null (a mode with no dock at all): `centre` then
  /// simply fills the row.
  ///
  /// Below [ocptCompactWidthBreakpoint] ([isCompact], resolved once by the caller from the very
  /// same width [build] already reads for the toolbar) the two side docks can no longer coexist
  /// with the centre floor as persistent columns, so the row reduces to [_buildCompactDrawers]:
  /// `centre` fills the whole width and at most one panel slides over it as an edge drawer,
  /// summoned by the toolbar's own dock toggles. Above the breakpoint the row keeps its persistent
  /// side columns unchanged.
  Widget _buildDocksRow(bool isCompact) {
    final controller = widget.dockLayoutController;
    if (controller == null) {
      return widget.centre;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final rowWidth = constraints.maxWidth;

        if (isCompact) {
          return _buildCompactDrawers(context, rowWidth);
        }

        return ListenableBuilder(
          listenable: controller,
          builder: (context, child) {
            final widths = OcptWorkspaceDock.resolveDockWidths(
              rowWidth: rowWidth,
              leftFraction: controller.leftFraction,
              rightFraction: controller.rightFraction,
              isLeftDockVisible: widget.leftPanel != null,
              isRightDockVisible: widget.rightPanel != null,
            );

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.leftPanel != null) ...[
                  OcptWorkspaceDock(width: widths.left, child: widget.leftPanel!),
                  OcptWorkspaceDockDivider(
                    onDragUpdate: (deltaX) => controller.setLeftFraction(
                      OcptWorkspaceDock.clampLeftFraction(
                        controller.leftFraction + deltaX / rowWidth,
                        rowWidth,
                      ),
                    ),
                    onDragEnd: () => widget.onDockFractionsChanged?.call((
                      left: controller.leftFraction,
                      right: null,
                    )),
                  ),
                ],
                Expanded(child: widget.centre),
                if (widget.rightPanel != null) ...[
                  OcptWorkspaceDockDivider(
                    onDragUpdate: (deltaX) => controller.setRightFraction(
                      OcptWorkspaceDock.clampRightFraction(
                        controller.rightFraction - deltaX / rowWidth,
                        rowWidth,
                      ),
                    ),
                    onDragEnd: () => widget.onDockFractionsChanged?.call((
                      left: null,
                      right: controller.rightFraction,
                    )),
                  ),
                  OcptWorkspaceDock(width: widths.right, child: widget.rightPanel!),
                ],
              ],
            );
          },
        );
      },
    );
  }

  /// Builds the compact-width presentation of the docks row: [OcptWorkspaceShell.centre] fills the
  /// whole row of [rowWidth], and at most one side panel — [_compactDrawer]'s own choice — slides
  /// over it as an edge drawer, dimming the centre behind a scrim that closes the drawer when
  /// tapped.
  ///
  /// The drawers are summoned by the toolbar's own dock toggles ([_buildDockToggles]), but their
  /// visibility here is [_compactDrawer] alone — never
  /// [OcptWorkspaceShell.isLeftDockOpen]/[OcptWorkspaceShell.isRightDockOpen] — which is what keeps
  /// both closed the moment a mode mounts and keeps the two mutually exclusive no matter what a
  /// mode's own flags say. A side whose panel the mode never built
  /// ([OcptWorkspaceShell.leftPanel]/[OcptWorkspaceShell.rightPanel] null) still has no drawer at
  /// all regardless of [_compactDrawer], exactly as it has no column at an expanded width.
  ///
  /// There are no resize dividers at this width; a drawer is [ocptCompactDrawerWidthFor] wide (the
  /// whole row on a phone, an edge drawer above that), and carries a 1 px `outlineVariant` line on
  /// its centre-facing edge, the same seam the divider draws between a column and the centre.
  Widget _buildCompactDrawers(BuildContext context, double rowWidth) {
    final colorScheme = Theme.of(context).colorScheme;
    final drawerWidth = ocptCompactDrawerWidthFor(rowWidth);
    final leftPanel = widget.leftPanel;
    final rightPanel = widget.rightPanel;
    final isLeftDrawerOpen = leftPanel != null && _compactDrawer == _OcptCompactDrawerSide.left;
    final isRightDrawerOpen =
        rightPanel != null && _compactDrawer == _OcptCompactDrawerSide.right;

    return Stack(
      children: [
        Positioned.fill(child: widget.centre),
        if (isLeftDrawerOpen || isRightDrawerOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeCompactDrawer,
              child: ColoredBox(color: colorScheme.scrim.withValues(alpha: 0.46)),
            ),
          ),
        if (isLeftDrawerOpen)
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: drawerWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: colorScheme.outlineVariant)),
              ),
              child: OcptWorkspaceDock(width: drawerWidth, child: leftPanel),
            ),
          ),
        if (isRightDrawerOpen)
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: drawerWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: colorScheme.outlineVariant)),
              ),
              child: OcptWorkspaceDock(width: drawerWidth, child: rightPanel),
            ),
          ),
      ],
    );
  }
}

/// The value the episode selector's `Manage episodes…` entry carries, distinct from every episode
/// id (a UUID, never empty) — see [_OcptWorkspaceShellState._buildEpisodeSelector]'s own doc
/// comment for why a [PopupMenuButton] cannot carry a null value for an entry that must still be
/// selectable.
const String _manageEpisodesOption = "";

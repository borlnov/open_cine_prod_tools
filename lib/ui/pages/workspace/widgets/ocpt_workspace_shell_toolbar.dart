// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_responsive.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_presence_indicator.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_shell.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_toolbar.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_export_share_anchor.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_workspace_episode_label.dart';

/// The value the episode selector's `Manage episodes…` entry carries, distinct from every episode
/// id (a UUID, never empty) — see [OcptWorkspaceShellToolbar._buildEpisodeSelector]'s own doc
/// comment for why a [PopupMenuButton] cannot carry a null value for an entry that must still be
/// selectable.
const String _manageEpisodesOption = "";

/// The shell's [OcptWorkspaceToolbar], with every control the shell builds itself rather than
/// takes from a mode: the episode control, the `Export` control, the dock toggles, the save
/// control, the project settings and `Help` actions, and the `⋮` overflow on a phone, all read off
/// [shell].
///
/// What the shell alone knows — which of the two dock toggles is on, and what a tap on each does —
/// is handed in resolved ([isLeftDockToggledOn], [onLeftDockToggled] and their right-hand twins),
/// since below [ocptCompactWidthBreakpoint] they drive the shell's drawers and not the mode's own
/// docks.
class OcptWorkspaceShellToolbar extends StatelessWidget {
  /// The shell whose configuration the toolbar is built from.
  final OcptWorkspaceShell shell;

  /// Whether the window is phone-wide: the export, settings and help controls then fold into the
  /// `⋮` overflow, and the episode selector shrinks to its icon.
  final bool isPhone;

  /// Whether the window is below [ocptCompactWidthBreakpoint].
  final bool isCompact;

  /// Whether the left dock toggle shows as on.
  final bool isLeftDockToggledOn;

  /// Whether the right dock toggle shows as on.
  final bool isRightDockToggledOn;

  /// Called when the left dock toggle is tapped, or null when there is no such toggle.
  final VoidCallback? onLeftDockToggled;

  /// Called when the right dock toggle is tapped, or null when there is no such toggle.
  final VoidCallback? onRightDockToggled;

  /// Class constructor
  const OcptWorkspaceShellToolbar({
    super.key,
    required this.shell,
    required this.isPhone,
    required this.isCompact,
    required this.isLeftDockToggledOn,
    required this.isRightDockToggledOn,
    required this.onLeftDockToggled,
    required this.onRightDockToggled,
  });

  /// Build the workspace shell toolbar as an [OcptWorkspaceToolbar].
  @override
  Widget build(BuildContext context) => OcptWorkspaceToolbar(
    title: shell.title,
    isDirty: shell.isDirty,
    isReadOnly: shell.isReadOnly,
    isCompact: isCompact,
    onBack: shell.onBack,
    episodeControl: _buildEpisodeControl(context, isPhone, isCompact),
    actions: shell.toolbarActions,
    modeLabel: shell.modeLabel,
    presenceIndicator: const OcptPresenceIndicator(),
    exportAction: isPhone ? null : _buildExportAction(context),
    dockToggles: _buildDockToggles(context),
    saveAction: _buildSaveAction(context),
    projectSettingsAction: isPhone ? null : _buildProjectSettingsAction(context),
    helpAction: isPhone ? null : _buildHelpAction(context),
    overflowEntries: isPhone ? _buildPhoneOverflowEntries(context) : shell.overflowEntries,
  );

  /// Build the `⋮` overflow entries on a phone: the export, project-settings and help actions the
  /// toolbar folded out of its own slots, above the mode's own
  /// [OcptWorkspaceShell.overflowEntries], separated from them by a divider when both groups are
  /// present.
  ///
  /// Each folded action guards on its own callback, exactly as the toolbar slot it replaces did, so
  /// a mode that withholds one (the settings action under a version preview, the help action every
  /// mode but the budget one) simply contributes no entry for it. When nothing folds, the mode's
  /// own entries are returned untouched.
  List<PopupMenuEntry<void>> _buildPhoneOverflowEntries(BuildContext context) {
    final folded = _buildFoldedChromeEntries(context);
    if (folded.isEmpty) {
      return shell.overflowEntries;
    }

    return [
      ...folded,
      if (shell.overflowEntries.isNotEmpty) const PopupMenuDivider(),
      ...shell.overflowEntries,
    ];
  }

  /// Build the folded export / project-settings / help entries for [_buildPhoneOverflowEntries],
  /// each rendered only when the mode wired its callback, in the same order they hold in the
  /// toolbar. Their labels reuse the controls' own strings, and each fires the very same callback
  /// its toolbar control does.
  List<PopupMenuEntry<void>> _buildFoldedChromeEntries(BuildContext context) {
    final tr = Tr.of(context);
    final onExportRequested = shell.onExportRequested;
    final onProjectSettingsRequested = shell.onProjectSettingsRequested;
    final onHelpRequested = shell.onHelpRequested;

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

  /// Build the toolbar's `Export` control, or null when the mode withheld it — no control is
  /// rendered at all then, rather than a disabled one.
  ///
  /// Unlike the chrome's icon-only controls, this one carries its own label: an export is not the
  /// kind of gesture a bare glyph reads as, so it does not take [OcptWorkspaceToolbar
  /// .chromeButtonStyle]'s square shape, and is sized to the toolbar band rather than to
  /// [TextButton]'s own default touch target.
  ///
  /// That last part takes **two** overrides, and neither alone is enough.
  /// [MaterialTapTargetSize.shrinkWrap] drops the stock 48 px touch target, which silently wins
  /// over the [ocpt_theme.ocptToolbarChromeButtonSize] minimum below — the very reason the
  /// `iconButtonTheme` already shrink-wraps every icon button of the app. [VisualDensity.standard]
  /// is the one that actually shows: a [TextButton] takes its density from the ambient theme, which
  /// on a desktop platform is [VisualDensity.compact] and takes **8 px off** every minimum size, so
  /// this button drew 22 px tall beside 30 px toggles — an [IconButton] never does, its own default
  /// density being standard whatever the theme says. Beware that `flutter test` reports the Android
  /// density unless the test overrides `debugDefaultTargetPlatform`, so this is a difference a
  /// widget test cannot see by default.
  ///
  /// Wrapped in its own [Builder] so `onPressed` can resolve the button's own screen [Rect] from
  /// its `RenderBox` at tap time — the anchor [OcptWorkspaceShell.onExportRequested] hands down for
  /// the OS share sheet's iPad/Mac popover — without this widget itself needing a [GlobalKey].
  Widget? _buildExportAction(BuildContext context) {
    final onExportRequested = shell.onExportRequested;
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
            minimumSize: const Size(0, ocpt_theme.ocptToolbarChromeButtonSize),
            maximumSize: const Size(double.infinity, ocpt_theme.ocptToolbarChromeButtonSize),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.standard,
          ),
        ),
      ),
    );
  }

  /// Build whatever fills the toolbar's episode slot: the selector for a project holding several
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

  /// Build the toolbar's episode selector, or null when [OcptWorkspaceShell.onEpisodeSelected] is
  /// null or [OcptWorkspaceShell.episodes] holds at most one — no control is rendered at all then,
  /// rather than a disabled one, exactly like [_buildExportAction].
  ///
  /// The trigger reads the selected episode's own label; the menu lists every episode with the
  /// selected one marked, followed by `Manage episodes…` when
  /// [OcptWorkspaceShell.onProjectSettingsRequested] is wired (see the class doc comment for why it
  /// is that callback rather than a new one). That entry carries [_manageEpisodesOption] rather
  /// than null: a [PopupMenuButton] cannot carry a null value for an entry that must still be
  /// selectable, since it can't tell that apart from the menu being dismissed without a pick
  /// (`OcptResourcesPersonPicker`'s own `_nobodyOption` is the same workaround, for the same
  /// reason).
  ///
  /// It wraps itself in a [Flexible] — the toolbar wraps nothing itself — because an episode's
  /// title is as long as the user made it: on a window too narrow for the whole toolbar, this is
  /// the control that gives width up, its trigger ellipsizing like the project title beside it. On
  /// a phone ([isPhone]) it is an icon-only fixed trigger instead (its label in the tooltip), since
  /// the phone toolbar has no room to ellipsize a title beside the mode's own controls.
  Widget? _buildEpisodeSelector(BuildContext context, bool isPhone) {
    final onEpisodeSelected = shell.onEpisodeSelected;
    if (onEpisodeSelected == null || shell.episodes.length <= 1) {
      return null;
    }

    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final onProjectSettingsRequested = shell.onProjectSettingsRequested;
    final selected = _episodeById(shell.selectedEpisodeId);

    final button = PopupMenuButton<String>(
      tooltip: tr.workspaceEpisodeSelectorTooltip,
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
      onSelected: (value) => value == _manageEpisodesOption
          ? onProjectSettingsRequested?.call()
          : onEpisodeSelected(value),
      itemBuilder: (context) => [
        for (final episode in shell.episodes)
          PopupMenuItem<String>(
            value: episode.id,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  child: episode.id == shell.selectedEpisodeId
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
          ? const _OcptWorkspaceEpisodeIconTrigger()
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: SizedBox(
                height: ocpt_theme.ocptToolbarChromeButtonSize,
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

  /// Build the toolbar's `Add an episode…` button, or null when
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
    final onAddEpisodeRequested = shell.onAddEpisodeRequested;
    if (onAddEpisodeRequested == null || shell.episodes.length != 1) {
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
            minimumSize: const Size(0, ocpt_theme.ocptToolbarChromeButtonSize),
            maximumSize: const Size(double.infinity, ocpt_theme.ocptToolbarChromeButtonSize),
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

  /// Get the episode of [OcptWorkspaceShell.episodes] whose id is [id], or null while [id] is null
  /// or
  /// names none of them — the moment right after the project's episodes changed under a stale
  /// selection, before the workspace bloc has re-resolved it.
  OcptEpisode? _episodeById(String? id) {
    for (final episode in shell.episodes) {
      if (episode.id == id) {
        return episode;
      }
    }

    return null;
  }

  /// Build the toolbar's dock toggles, left one first, skipping whichever side has no callback.
  ///
  /// Both wear the same sidebar glyph, the right one mirrored, so the pair reads as one control
  /// per side of the workspace; the `iconButtonTheme` paints the open one with its accent wash.
  ///
  /// What a tap does and which state the button reads is the shell's decision, handed in resolved:
  /// above [ocptCompactWidthBreakpoint] a tap calls the mode's own
  /// [OcptWorkspaceShell.onToggleLeftDock]/[OcptWorkspaceShell.onToggleRightDock] and the button's
  /// selected state reads the mode's own flag, while below it the very same buttons drive the
  /// shell's drawers instead, so the mode never has to know its dock became a drawer.
  List<Widget> _buildDockToggles(BuildContext context) {
    final tr = Tr.of(context);
    final onLeftDockToggled = this.onLeftDockToggled;
    final onRightDockToggled = this.onRightDockToggled;

    return [
      if (onLeftDockToggled != null)
        IconButton(
          icon: Icon(
            isLeftDockToggledOn ? Icons.view_sidebar : Icons.view_sidebar_outlined,
            size: 24,
          ),
          tooltip: tr.workspaceToggleLeftDockTooltip,
          isSelected: isLeftDockToggledOn,
          style: OcptWorkspaceToolbar.chromeButtonStyle,
          onPressed: onLeftDockToggled,
        ),
      if (onRightDockToggled != null)
        IconButton(
          icon: Transform.flip(
            flipX: true,
            child: Icon(
              isRightDockToggledOn ? Icons.view_sidebar : Icons.view_sidebar_outlined,
              size: 24,
            ),
          ),
          tooltip: tr.workspaceToggleRightDockTooltip,
          isSelected: isRightDockToggledOn,
          style: OcptWorkspaceToolbar.chromeButtonStyle,
          onPressed: onRightDockToggled,
        ),
    ];
  }

  /// Build the toolbar's save control — the button, or the same-sized spinner while
  /// [OcptWorkspaceShell.isSaving] — or null when the mode has nothing to save.
  Widget? _buildSaveAction(BuildContext context) {
    final onSave = shell.onSave;
    if (onSave == null) {
      return null;
    }

    if (shell.isSaving) {
      return const SizedBox.square(
        dimension: ocpt_theme.ocptToolbarChromeButtonSize,
        child: Center(
          child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.save_outlined, size: 24),
      tooltip: Tr.of(context).editorSaveTooltip,
      style: OcptWorkspaceToolbar.chromeButtonStyle,
      onPressed: onSave,
    );
  }

  /// Build the toolbar's project settings action, or null when the mode withheld it.
  Widget? _buildProjectSettingsAction(BuildContext context) {
    final onProjectSettingsRequested = shell.onProjectSettingsRequested;
    if (onProjectSettingsRequested == null) {
      return null;
    }

    return IconButton(
      icon: const Icon(Icons.settings_outlined, size: 24),
      tooltip: Tr.of(context).workspaceProjectSettingsTooltip,
      style: OcptWorkspaceToolbar.chromeButtonStyle,
      onPressed: onProjectSettingsRequested,
    );
  }

  /// Build the toolbar's `Help` action, or null when the mode withheld it.
  Widget? _buildHelpAction(BuildContext context) {
    final onHelpRequested = shell.onHelpRequested;
    if (onHelpRequested == null) {
      return null;
    }

    return IconButton(
      icon: const Icon(Icons.help_outline, size: 24),
      tooltip: Tr.of(context).workspaceHelpTooltip,
      style: OcptWorkspaceToolbar.chromeButtonStyle,
      onPressed: onHelpRequested,
    );
  }
}

/// The phone-width, icon-only trigger of the episode selector: a fixed chrome-sized glyph pair (an
/// episode library icon and the dropdown caret), reading which episode is on screen from its
/// tooltip rather than a label the phone toolbar has no room for.
class _OcptWorkspaceEpisodeIconTrigger extends StatelessWidget {
  /// Class constructor
  const _OcptWorkspaceEpisodeIconTrigger();

  /// Build the workspace episode icon trigger as a [Padding].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        height: ocpt_theme.ocptToolbarChromeButtonSize,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.video_library_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
            Icon(Icons.arrow_drop_down, size: 16, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

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
/// id (a UUID, never empty) — see [_OcptToolbarEpisodeSelector]'s own doc
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
  Widget build(BuildContext context) {
    final onExportRequested = shell.onExportRequested;
    final onEpisodeSelected = shell.onEpisodeSelected;
    final onAddEpisodeRequested = shell.onAddEpisodeRequested;
    final onProjectSettingsRequested = shell.onProjectSettingsRequested;
    final onHelpRequested = shell.onHelpRequested;
    final onSave = shell.onSave;
    final onLeftDockToggled = this.onLeftDockToggled;
    final onRightDockToggled = this.onRightDockToggled;

    // The selector gives width up off a phone, being as long as the user made the episode's title;
    // on a phone it is a fixed icon and stays out of the toolbar's flexible width entirely.
    final episodeSelector = onEpisodeSelected == null || shell.episodes.length <= 1
        ? null
        : _OcptToolbarEpisodeSelector(
            shell: shell,
            isPhone: isPhone,
            onEpisodeSelected: onEpisodeSelected,
          );

    return OcptWorkspaceToolbar(
      title: shell.title,
      isDirty: shell.isDirty,
      isReadOnly: shell.isReadOnly,
      isCompact: isCompact,
      onBack: shell.onBack,
      episodeControl: episodeSelector != null
          ? (isPhone ? episodeSelector : Flexible(child: episodeSelector))
          : (!isCompact && onAddEpisodeRequested != null && shell.episodes.length == 1
                ? Flexible(child: _OcptToolbarAddEpisodeAction(onPressed: onAddEpisodeRequested))
                : null),
      actions: shell.toolbarActions,
      modeLabel: shell.modeLabel,
      presenceIndicator: const OcptPresenceIndicator(),
      exportAction: isPhone || onExportRequested == null
          ? null
          : _OcptToolbarExportAction(onExportRequested: onExportRequested),
      dockToggles: [
        if (onLeftDockToggled != null)
          _OcptToolbarDockToggle(
            isRight: false,
            isToggledOn: isLeftDockToggledOn,
            onPressed: onLeftDockToggled,
          ),
        if (onRightDockToggled != null)
          _OcptToolbarDockToggle(
            isRight: true,
            isToggledOn: isRightDockToggledOn,
            onPressed: onRightDockToggled,
          ),
      ],
      saveAction: onSave == null
          ? null
          : _OcptToolbarSaveAction(isSaving: shell.isSaving, onSave: onSave),
      projectSettingsAction: isPhone || onProjectSettingsRequested == null
          ? null
          : _OcptToolbarProjectSettingsAction(onPressed: onProjectSettingsRequested),
      helpAction: isPhone || onHelpRequested == null
          ? null
          : _OcptToolbarHelpAction(onPressed: onHelpRequested),
      overflowEntries: isPhone ? _buildPhoneOverflowEntries(context) : shell.overflowEntries,
    );
  }

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
}

/// The toolbar's `Export` control. The toolbar renders none at all, rather than a disabled one,
/// when the mode withheld it.
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
class _OcptToolbarExportAction extends StatelessWidget {
  /// Called with the control's own screen bounds when it is tapped, for the OS share sheet's
  /// anchor.
  final ValueSetter<Rect?> onExportRequested;

  /// Class constructor
  const _OcptToolbarExportAction({required this.onExportRequested});

  /// Build the toolbar export action as a [Tooltip].
  @override
  Widget build(BuildContext context) {
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
}

/// The toolbar's episode selector. The toolbar renders none at all, rather than a disabled one,
/// when [OcptWorkspaceShell.onEpisodeSelected] is null or [OcptWorkspaceShell.episodes] holds at
/// most one.
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
/// The toolbar wraps it in a [Flexible] off a phone, because an episode's
/// title is as long as the user made it: on a window too narrow for the whole toolbar, this is
/// the control that gives width up, its trigger ellipsizing like the project title beside it. On
/// a phone ([isPhone]) it is an icon-only fixed trigger instead (its label in the tooltip), since
/// the phone toolbar has no room to ellipsize a title beside the mode's own controls.
class _OcptToolbarEpisodeSelector extends StatelessWidget {
  /// The shell whose episodes the selector lists.
  final OcptWorkspaceShell shell;

  /// Whether the window is phone-wide: the trigger then reduces to its icon.
  final bool isPhone;

  /// Called with the id of the episode picked.
  final ValueChanged<String> onEpisodeSelected;

  /// Class constructor
  const _OcptToolbarEpisodeSelector({
    required this.shell,
    required this.isPhone,
    required this.onEpisodeSelected,
  });

  /// Build the toolbar episode selector as a [PopupMenuButton].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final onProjectSettingsRequested = shell.onProjectSettingsRequested;
    final selected = _episodeById(shell.selectedEpisodeId);

    return PopupMenuButton<String>(
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
}

/// The toolbar's `Add an episode…` button. The toolbar renders none when
/// [OcptWorkspaceShell.onAddEpisodeRequested] is null or [OcptWorkspaceShell.episodes] holds
/// anything other than exactly one.
///
/// The empty list is deliberately not the button's case either: it means the project's episodes
/// haven't loaded yet, and a button flashing in for one frame before the selector replaces it
/// would be a lie about a project that turns out to be a series.
///
/// It is dressed as the selector it stands in for rather than as an action: muted foreground,
/// [TextTheme.bodySmall], no fill. Sizing it to the toolbar band takes the same two overrides
/// [_OcptToolbarExportAction] documents at length, and neither alone is enough.
///
/// It is laid out by hand rather than as a [TextButton.icon] so its label sits in a [Flexible]:
/// this control shares the toolbar's flexible width with the project title, and a window too
/// narrow for the whole band ellipsizes the label down to the glyph instead of striping the row.
///
/// Never built at all below [ocptCompactWidthBreakpoint] — the toolbar withholds it there — and
/// [ocptPhoneWidthBreakpoint] is always below that breakpoint too, so this widget never
/// has to reduce itself to an icon-only trigger the way the selector does: by the time it runs,
/// the toolbar is already wide enough for its label.
class _OcptToolbarAddEpisodeAction extends StatelessWidget {
  /// Called when the button is tapped.
  final VoidCallback onPressed;

  /// Class constructor
  const _OcptToolbarAddEpisodeAction({required this.onPressed});

  /// Build the toolbar add episode action as a [Tooltip].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Tooltip(
      message: tr.workspaceAddEpisodeTooltip,
      child: TextButton(
        onPressed: onPressed,
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
    );
  }
}

/// One of the toolbar's dock toggles: the left or the right one.
///
/// Both wear the same sidebar glyph, the right one mirrored, so the pair reads as one control
/// per side of the workspace; the `iconButtonTheme` paints the open one with its accent wash.
///
/// What a tap does and which state the button reads is the shell's decision, handed in resolved:
/// above [ocptCompactWidthBreakpoint] a tap calls the mode's own
/// [OcptWorkspaceShell.onToggleLeftDock]/[OcptWorkspaceShell.onToggleRightDock] and the button's
/// selected state reads the mode's own flag, while below it the very same buttons drive the
/// shell's drawers instead, so the mode never has to know its dock became a drawer.
class _OcptToolbarDockToggle extends StatelessWidget {
  /// Whether this is the right toggle, rather than the left one.
  final bool isRight;

  /// Whether the toggle shows as on.
  final bool isToggledOn;

  /// Called when the toggle is tapped.
  final VoidCallback onPressed;

  /// Class constructor
  const _OcptToolbarDockToggle({
    required this.isRight,
    required this.isToggledOn,
    required this.onPressed,
  });

  /// Build the toolbar dock toggle as an [IconButton].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final glyph = Icon(isToggledOn ? Icons.view_sidebar : Icons.view_sidebar_outlined, size: 24);

    return IconButton(
      icon: isRight ? Transform.flip(flipX: true, child: glyph) : glyph,
      tooltip: isRight ? tr.workspaceToggleRightDockTooltip : tr.workspaceToggleLeftDockTooltip,
      isSelected: isToggledOn,
      style: OcptWorkspaceToolbar.chromeButtonStyle,
      onPressed: onPressed,
    );
  }
}

/// The toolbar's save control: the button, or the same-sized spinner while the shell is saving.
class _OcptToolbarSaveAction extends StatelessWidget {
  /// Whether the shell is saving.
  final bool isSaving;

  /// Called when the button is tapped.
  final VoidCallback onSave;

  /// Class constructor
  const _OcptToolbarSaveAction({required this.isSaving, required this.onSave});

  /// Build the toolbar save action as the button or the spinner.
  @override
  Widget build(BuildContext context) {
    if (isSaving) {
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
}

/// The toolbar's project settings action.
class _OcptToolbarProjectSettingsAction extends StatelessWidget {
  /// Called when the button is tapped.
  final VoidCallback onPressed;

  /// Class constructor
  const _OcptToolbarProjectSettingsAction({required this.onPressed});

  /// Build the toolbar project settings action as an [IconButton].
  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.settings_outlined, size: 24),
    tooltip: Tr.of(context).workspaceProjectSettingsTooltip,
    style: OcptWorkspaceToolbar.chromeButtonStyle,
    onPressed: onPressed,
  );
}

/// The toolbar's `Help` action.
class _OcptToolbarHelpAction extends StatelessWidget {
  /// Called when the button is tapped.
  final VoidCallback onPressed;

  /// Class constructor
  const _OcptToolbarHelpAction({required this.onPressed});

  /// Build the toolbar help action as an [IconButton].
  @override
  Widget build(BuildContext context) => IconButton(
    icon: const Icon(Icons.help_outline, size: 24),
    tooltip: Tr.of(context).workspaceHelpTooltip,
    style: OcptWorkspaceToolbar.chromeButtonStyle,
    onPressed: onPressed,
  );
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

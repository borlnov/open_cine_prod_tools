// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_warning_color.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_logo.dart';
import 'package:open_cine_prod_tools/utils/ocpt_responsive.dart';

/// The size of the accent-filled square carrying the back action, small enough to sit inside the
/// [ocptToolbarHeight] band with room to breathe, and deliberately smaller than the chrome buttons
/// around it so the accent fill reads as a compact badge rather than a button.
const double _backActionSize = 26;

/// The width of the logo glyph inside the back action's [_backActionSize] square.
const double _backActionIconSize = 16;

/// The diameter of the dot marking unsaved changes.
const double _dirtyMarkerSize = 6;

/// The workspace shell's thin, discreet toolbar: the back action leading to the projects list, the
/// open project's title (with a dot marking unsaved changes, or the `Read only` pill while
/// [isReadOnly]), the [episodeControl] right after it, a trailing slot for the active mode's own
/// controls ([actions]), then the shell's own chrome — the active mode's name ([modeLabel]), the
/// [exportAction], the [dockToggles], the [saveAction], the [projectSettingsAction], the
/// [helpAction] and an overflow `⋮` menu built from [overflowEntries].
///
/// Everything mode-specific (format controls, tab selectors, an editing-mode toggle, export
/// entries…) is the active mode's own job to build and hand in through [actions] /
/// [overflowEntries]. The chrome slots after them are ordered by this widget rather than by the
/// mode, so every mode's toolbar ends the same way; a mode that has nothing to put in one of them
/// simply leaves it empty and it is not rendered at all.
///
/// Below [ocptCompactWidthBreakpoint] ([isCompact]), [title] and [modeLabel] are withheld outright
/// — see [isCompact]'s own doc comment.
class OcptWorkspaceToolbar extends StatelessWidget {
  /// The title shown at the left of the toolbar (the open project's name).
  final String title;

  /// Whether there are unsaved changes, shown as a dot next to the title.
  final bool isDirty;

  /// Whether the shell has laid this toolbar out below [ocptCompactWidthBreakpoint].
  ///
  /// Below it, [title] and [modeLabel] are dropped entirely rather than shown ellipsized: neither
  /// reads as anything but noise once the band has no room to show it in full, and dropping them
  /// frees space the phone/tablet controls need more. This is distinct from [ocptIsPhoneWidth],
  /// which folds a different set of controls (export, settings, help) into the `⋮` overflow at a
  /// narrower width still — the two breakpoints are never the same width, so this flag is never a
  /// stand-in for that one.
  final bool isCompact;

  /// Whether what the workspace shows is a project version being previewed read-only, shown as the
  /// `Read only` pill in place of the unsaved-changes dot.
  ///
  /// The two can never legitimately be true at once — a preview is only entered once every mode
  /// has flushed what it held — but the pill wins if they ever were: what may not be edited is the
  /// more important of the two things to say.
  final bool isReadOnly;

  /// Called when the back action is clicked.
  final VoidCallback onBack;

  /// Whatever the shell has to say about *which episode* is on screen, shown right after [title]
  /// and its dirty marker / `Read only` pill: the episode selector, or the screenplay mode's
  /// `Add an episode…` button in its place, or null for no control at all.
  ///
  /// This toolbar only lays the slot out; which of the two fills it — and when neither does — is
  /// `OcptWorkspaceShell`'s own call, built there exactly as [exportAction] is.
  ///
  /// It is dropped into the row as handed in, **not** wrapped in a [Flexible] here: whether the
  /// control gives width up on a window too narrow for the whole toolbar is a property of the
  /// control itself, and only the shell knows it. The selector wraps itself in one, since an
  /// episode's title is as long as the user made it; the fixed-width `Add an episode…` button does
  /// not, and the title ellipsizes around it exactly as it does around every other chrome button.
  final Widget? episodeControl;

  /// The active mode's own controls, right-aligned before the chrome slots.
  final List<Widget> actions;

  /// The active mode's name, shown muted between the mode's own [actions] and the chrome slots, or
  /// null to show no label at all.
  final String? modeLabel;

  /// The presence indicator, shown after [modeLabel] and before [exportAction] — workspace chrome
  /// rather than a mode's own control, exactly like the rest of this widget's trailing slots, which
  /// is why it is built by the shell and handed in here rather than contributed through [actions].
  /// Null renders nothing at all, the unpaired-project case the indicator itself already answers.
  final Widget? presenceIndicator;

  /// The `Export` control, shown after [presenceIndicator] and before [dockToggles], or null when
  /// the mode prints nothing — no control is rendered at all then, rather than a disabled one. Every
  /// implemented mode wires it today, the budget mode included: even at M1, before it prints a
  /// document of its own, the panel it opens still offers the project package export every mode's
  /// panel carries as its own standing card (`OcptWorkspaceExportDialog`'s own doc comment).
  final Widget? exportAction;

  /// The dock toggles, shown after [exportAction]. An empty list renders none of them (a mode with
  /// no dock at all).
  final List<Widget> dockToggles;

  /// The save control, shown after [dockToggles], or null when the mode has nothing to save.
  final Widget? saveAction;

  /// The project settings action, shown after [saveAction], or null when the mode withholds it —
  /// while a project version is being previewed, since a preview has nothing here that may be
  /// written.
  final Widget? projectSettingsAction;

  /// The `Help` control, shown after [projectSettingsAction] and before the `⋮` menu, or null when
  /// the mode has no help panel to open — no control is rendered at all then, rather than a
  /// disabled one. It sits at the far end of the chrome, beside the settings action, because
  /// reaching for it is the outlier gesture on this toolbar: nobody clicks it while doing the
  /// mode's own routine work, unlike the dock toggles or the save control, and pairing it with
  /// settings is where a reader already expects a "what is this" affordance to live.
  ///
  /// Only the budget mode wires this in for now (`docs/architecture/budget.md`); every other mode
  /// leaves it null, and it opens onto that mode's own right dock rather than a dialog, so it
  /// never asks for anything to be withheld under a version preview — a help panel writes nothing.
  final Widget? helpAction;

  /// The `⋮` overflow menu's entries. An empty list renders no `⋮` button at all.
  final List<PopupMenuEntry<void>> overflowEntries;

  /// The style every chrome button of the toolbar wears: [ocptToolbarChromeButtonSize] square,
  /// with no padding of its own around the glyph.
  ///
  /// The shell builds the [dockToggles] and the [saveAction] itself and hands them in already
  /// built, so this is exposed for it to dress them exactly like the `⋮` button below. Everything
  /// else (shape, the selected wash, colors) is left to the `iconButtonTheme`.
  static final ButtonStyle chromeButtonStyle = IconButton.styleFrom(
    minimumSize: const Size.square(ocptToolbarChromeButtonSize),
    padding: EdgeInsets.zero,
  );

  /// Class constructor
  const OcptWorkspaceToolbar({
    super.key,
    required this.title,
    required this.isDirty,
    this.isCompact = false,
    this.isReadOnly = false,
    required this.onBack,
    this.episodeControl,
    this.actions = const [],
    this.modeLabel,
    this.presenceIndicator,
    this.exportAction,
    this.dockToggles = const [],
    this.saveAction,
    this.projectSettingsAction,
    this.helpAction,
    this.overflowEntries = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return SizedBox(
      height: ocptToolbarHeight,
      child: ColoredBox(
        color: theme.colorScheme.surfaceContainerLow,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  spacing: 10,
                  children: [
                    _buildBackAction(theme: theme, tr: tr),
                    if (!isCompact)
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    if (isReadOnly)
                      _buildReadOnlyPill(context: context, theme: theme, tr: tr)
                    else if (isDirty)
                      _buildDirtyMarker(theme: theme, tr: tr),
                    if (episodeControl != null) episodeControl!,
                    const Spacer(),
                    ...actions,
                    if (modeLabel != null && !isCompact)
                      // Flexible like the title, so a window too narrow for a mode's whole
                      // toolbar ellipsizes the two labels rather than overflowing the row: every
                      // control around them is a fixed-size button that can't give any width up.
                      Flexible(
                        child: Text(
                          modeLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (presenceIndicator != null) presenceIndicator!,
                    if (exportAction != null) exportAction!,
                    ...dockToggles,
                    if (saveAction != null) saveAction!,
                    if (projectSettingsAction != null) projectSettingsAction!,
                    if (helpAction != null) helpAction!,
                    if (overflowEntries.isNotEmpty)
                      PopupMenuButton<void>(
                        icon: const Icon(Icons.more_vert, size: 24),
                        tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                        style: chromeButtonStyle,
                        itemBuilder: (context) => overflowEntries,
                      ),
                  ],
                ),
              ),
            ),
            // The divider theme already gives this its `outlineVariant` color, 1 px thickness and
            // no surrounding space, so the band as a whole still measures [ocptToolbarHeight].
            const Divider(),
          ],
        ),
      ),
    );
  }

  /// Builds the back action: an accent-filled square badge carrying the application logo rather
  /// than a plain icon button, so the one control leading out of the workspace reads as distinct
  /// from every mode and chrome control around it. Its "back to projects" meaning is carried by
  /// the tooltip alone.
  Widget _buildBackAction({required ThemeData theme, required Tr tr}) => Tooltip(
    message: tr.editorBackToProjectsTooltip,
    child: Material(
      color: theme.colorScheme.primary,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onBack,
        mouseCursor: ocptClickableCursor,
        child: SizedBox.square(
          dimension: _backActionSize,
          child: Center(
            child: OcptLogoGlyph(
              width: _backActionIconSize,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    ),
  );

  /// Builds the pill telling that what is on screen may not be edited, in place of the
  /// unsaved-changes dot, tinted with the same warning colour the read-only banner under the
  /// toolbar wears so the two read as one state.
  Widget _buildReadOnlyPill({
    required BuildContext context,
    required ThemeData theme,
    required Tr tr,
  }) {
    final color = ocptWarningColor(context);

    return Tooltip(
      message: tr.workspaceReadOnlyTooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: ocptSelectedStateAlpha),
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
        ),
        child: Text(
          tr.workspaceReadOnlyPill,
          style: theme.textTheme.labelSmall?.copyWith(color: color),
        ),
      ),
    );
  }

  /// Builds the dot marking unsaved changes, next to the title.
  Widget _buildDirtyMarker({required ThemeData theme, required Tr tr}) => Tooltip(
    message: tr.editorUnsavedChangesTooltip,
    child: Container(
      width: _dirtyMarkerSize,
      height: _dirtyMarkerSize,
      decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
    ),
  );
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The size of the accent-filled square carrying the back action, small enough to sit inside the
/// [ocptToolbarHeight] band with room to breathe, and deliberately smaller than the chrome buttons
/// around it so the accent fill reads as a compact badge rather than a button.
const double _backActionSize = 26;

/// The size of the glyph inside the back action's [_backActionSize] square.
const double _backActionIconSize = 16;

/// The diameter of the dot marking unsaved changes.
const double _dirtyMarkerSize = 6;

/// The workspace shell's thin, discreet toolbar: the back action leading to the projects list, the
/// open project's title (with a dot marking unsaved changes), a trailing slot for the active
/// mode's own controls ([actions]), then the shell's own chrome — the active mode's name
/// ([modeLabel]), the [dockToggles], the [saveAction] and an overflow `⋮` menu built from
/// [overflowEntries].
///
/// Everything mode-specific (format controls, tab selectors, an editing-mode toggle, export
/// entries…) is the active mode's own job to build and hand in through [actions] /
/// [overflowEntries]. The chrome slots after them are ordered by this widget rather than by the
/// mode, so every mode's toolbar ends the same way; a mode that has nothing to put in one of them
/// simply leaves it empty and it is not rendered at all.
class OcptWorkspaceToolbar extends StatelessWidget {
  /// The title shown at the left of the toolbar (the open project's name).
  final String title;

  /// Whether there are unsaved changes, shown as a dot next to the title.
  final bool isDirty;

  /// Called when the back action is clicked.
  final VoidCallback onBack;

  /// The active mode's own controls, right-aligned before the chrome slots.
  final List<Widget> actions;

  /// The active mode's name, shown muted between the mode's own [actions] and the chrome slots, or
  /// null to show no label at all.
  final String? modeLabel;

  /// The dock toggles, shown after [modeLabel]. An empty list renders none of them (a mode with no
  /// dock at all).
  final List<Widget> dockToggles;

  /// The save control, shown after [dockToggles], or null when the mode has nothing to save.
  final Widget? saveAction;

  /// The `⋮` overflow menu's entries. An empty list renders no `⋮` button at all.
  final List<PopupMenuEntry<void>> overflowEntries;

  /// Class constructor
  const OcptWorkspaceToolbar({
    super.key,
    required this.title,
    required this.isDirty,
    required this.onBack,
    this.actions = const [],
    this.modeLabel,
    this.dockToggles = const [],
    this.saveAction,
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
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (isDirty) _buildDirtyMarker(theme: theme, tr: tr),
                    const Spacer(),
                    ...actions,
                    if (modeLabel != null)
                      Text(
                        modeLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ...dockToggles,
                    if (saveAction != null) saveAction!,
                    if (overflowEntries.isNotEmpty)
                      PopupMenuButton<void>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        tooltip: MaterialLocalizations.of(context).showMenuTooltip,
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

  /// Builds the back action: an accent-filled square badge rather than a plain icon button, so the
  /// one control leading out of the workspace reads as distinct from every mode and chrome control
  /// around it. Its "back to projects" meaning is carried by the tooltip alone.
  Widget _buildBackAction({required ThemeData theme, required Tr tr}) => Tooltip(
    message: tr.editorBackToProjectsTooltip,
    child: Material(
      color: theme.colorScheme.primary,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onBack,
        child: SizedBox.square(
          dimension: _backActionSize,
          child: Icon(
            Icons.web_asset,
            size: _backActionIconSize,
            color: theme.colorScheme.onPrimary,
          ),
        ),
      ),
    ),
  );

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

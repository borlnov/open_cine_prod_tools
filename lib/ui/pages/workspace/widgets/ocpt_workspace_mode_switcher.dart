// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_workspace_mode.dart';

/// The width of one mode entry, wide enough for the longest mode label without wrapping.
const _entryWidth = 110.0;

/// The persistent bottom band choosing which production mode fills the rest of the window: one
/// entry per [OcptWorkspaceMode], icon over label, the active one tinted `primary` over a soft
/// wash, the others `onSurfaceVariant` over transparent.
///
/// Every mode is selectable (decision: a disabled bar reads as a bug), and every one of them is
/// implemented today. The "coming soon" corner marker [_OcptWorkspaceModeIcon] carries is dormant
/// rather than removed: [OcptWorkspaceMode.isImplemented] stays an explicit, extensible check
/// rather than a bare `true` for exactly this reason, so a mode added ahead of its own content
/// finds the marker already wired rather than having to reinvent it.
class OcptWorkspaceModeSwitcher extends StatelessWidget {
  /// The currently active mode.
  final OcptWorkspaceMode activeMode;

  /// Called with the mode the user tapped.
  final ValueChanged<OcptWorkspaceMode> onModeSelected;

  /// Class constructor
  const OcptWorkspaceModeSwitcher({
    super.key,
    required this.activeMode,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: ocptModeSwitcherHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final mode in OcptWorkspaceMode.values)
            _OcptWorkspaceModeEntry(
              mode: mode,
              isActive: mode == activeMode,
              onTap: () => onModeSelected(mode),
            ),
        ],
      ),
    );
  }
}

/// The label shown under [mode]'s icon, and used as its tooltip base text.
String _labelFor(Tr tr, OcptWorkspaceMode mode) => switch (mode) {
  OcptWorkspaceMode.screenplay => tr.workspaceModeScreenplay,
  OcptWorkspaceMode.breakdown => tr.workspaceModeBreakdown,
  OcptWorkspaceMode.shotList => tr.workspaceModeShotList,
  OcptWorkspaceMode.resources => tr.workspaceModeResources,
  OcptWorkspaceMode.schedule => tr.workspaceModeSchedule,
  OcptWorkspaceMode.budget => tr.workspaceModeBudget,
};

/// The icon shown above [mode]'s label.
IconData _iconFor(OcptWorkspaceMode mode) => switch (mode) {
  OcptWorkspaceMode.screenplay => Icons.description_outlined,
  OcptWorkspaceMode.breakdown => Icons.fact_check_outlined,
  OcptWorkspaceMode.shotList => Icons.movie_filter_outlined,
  OcptWorkspaceMode.resources => Icons.groups_outlined,
  OcptWorkspaceMode.schedule => Icons.calendar_month_outlined,
  OcptWorkspaceMode.budget => Icons.payments_outlined,
};

/// One clickable entry of [OcptWorkspaceModeSwitcher].
class _OcptWorkspaceModeEntry extends StatelessWidget {
  /// The mode this entry represents.
  final OcptWorkspaceMode mode;

  /// Whether [mode] is the currently active one.
  final bool isActive;

  /// Called when this entry is tapped.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptWorkspaceModeEntry({required this.mode, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final color = isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    final label = _labelFor(tr, mode);
    final tooltip = mode.isImplemented ? label : tr.workspaceModeComingSoonTooltip(label);

    return SizedBox(
      width: _entryWidth,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          mouseCursor: ocptClickableCursor,
          borderRadius: BorderRadius.circular(ocptRadiusMedium),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(ocptRadiusMedium),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _OcptWorkspaceModeIcon(mode: mode, color: color),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The icon of a mode switcher entry, carrying a small "coming soon" corner marker for a mode
/// that isn't implemented yet.
class _OcptWorkspaceModeIcon extends StatelessWidget {
  /// The mode this icon represents.
  final OcptWorkspaceMode mode;

  /// The icon's color, matching the entry's active/inactive state.
  final Color color;

  /// Class constructor
  const _OcptWorkspaceModeIcon({required this.mode, required this.color});

  @override
  Widget build(BuildContext context) {
    final icon = Icon(_iconFor(mode), size: 22, color: color);
    if (mode.isImplemented) {
      return icon;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          top: -4,
          right: -4,
          child: Icon(
            Icons.schedule,
            size: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

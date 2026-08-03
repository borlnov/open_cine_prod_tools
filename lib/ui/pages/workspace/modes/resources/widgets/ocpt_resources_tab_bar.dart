// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

/// The four-tab segmented control at the top of the resources mode's left dock: a rounded strip
/// over `surfaceContainerLowest`, each tab sharing the strip's width equally, the active one
/// tinted `primary` over a soft wash.
///
/// All four tabs are always selectable, including [OcptResourcesTab.locations] and
/// [OcptResourcesTab.elements], which show only a discreet placeholder line this milestone — a
/// disabled strip would read as a bug, exactly the reasoning `OcptWorkspaceModeSwitcher` already
/// follows for the modes not implemented yet.
class OcptResourcesTabBar extends StatelessWidget {
  /// The currently active tab.
  final OcptResourcesTab activeTab;

  /// Called with the tab tapped.
  final ValueChanged<OcptResourcesTab> onTabSelected;

  /// Class constructor
  const OcptResourcesTabBar({super.key, required this.activeTab, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(ocptRadiusMedium),
        ),
        child: Row(
          children: [
            for (final tab in OcptResourcesTab.values)
              Expanded(
                child: _OcptResourcesTabEntry(
                  label: ocptResourcesTabLabel(Tr.of(context), tab),
                  isActive: tab == activeTab,
                  onTap: () => onTabSelected(tab),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One clickable entry of [OcptResourcesTabBar].
class _OcptResourcesTabEntry extends StatelessWidget {
  /// The tab's display name.
  final String label;

  /// Whether this is the currently active tab.
  final bool isActive;

  /// Called when this entry is tapped.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptResourcesTabEntry({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

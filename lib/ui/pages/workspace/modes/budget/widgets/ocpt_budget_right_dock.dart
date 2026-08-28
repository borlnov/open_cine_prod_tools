// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';

/// The chrome of the budget mode's right dock: a compact tab row, a trailing × close button, and
/// the active tab's body below — the exact mirror of `OcptScheduleRightDock`, carrying the three
/// tabs [OcptBudgetRightDockTab] declares.
class OcptBudgetRightDock extends StatelessWidget {
  /// The currently active tab, whose body is shown below the tab row.
  final OcptBudgetRightDockTab activeTab;

  /// Which tabs this dock offers at all, in the order they are drawn.
  ///
  /// **Not always every value of the enum**: the `Inspector` is offered only on a view that has
  /// something to inspect (`ocptBudgetCentreViewHasInspector`), and a tab that is not offered is
  /// **withheld, not disabled**, exactly as this app withholds any affordance without a subject.
  final List<OcptBudgetRightDockTab> availableTabs;

  /// The built poste inspector, shown when [activeTab] is [OcptBudgetRightDockTab.inspector].
  final Widget inspectorChild;

  /// The built project versions panel, shown when [activeTab] is
  /// [OcptBudgetRightDockTab.versions].
  final Widget versionsChild;

  /// The built help panel, shown when [activeTab] is [OcptBudgetRightDockTab.help].
  final Widget helpChild;

  /// Called with a tab when its label in the tab row is clicked.
  final ValueChanged<OcptBudgetRightDockTab> onTabSelected;

  /// Called when the × close button is clicked.
  final VoidCallback onClose;

  /// Class constructor
  const OcptBudgetRightDock({
    super.key,
    required this.activeTab,
    required this.availableTabs,
    required this.inspectorChild,
    required this.versionsChild,
    required this.helpChild,
    required this.onTabSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final tab in availableTabs)
                      _OcptBudgetRightDockTabLabel(
                        label: switch (tab) {
                          OcptBudgetRightDockTab.inspector => tr.budgetRightDockInspectorTabLabel,
                          OcptBudgetRightDockTab.versions => tr.budgetRightDockVersionsTabLabel,
                          OcptBudgetRightDockTab.help => tr.budgetRightDockHelpTabLabel,
                        },
                        isActive: activeTab == tab,
                        onTap: () => onTabSelected(tab),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: tr.budgetRightDockCloseTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
            ),
          ],
        ),
        Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
        Expanded(
          child: switch (activeTab) {
            OcptBudgetRightDockTab.inspector => inspectorChild,
            OcptBudgetRightDockTab.versions => versionsChild,
            OcptBudgetRightDockTab.help => helpChild,
          },
        ),
      ],
    );
  }
}

/// One clickable label of the tab row, mirroring `OcptScheduleRightDock`'s own private label.
class _OcptBudgetRightDockTabLabel extends StatelessWidget {
  /// The tab's display name.
  final String label;

  /// Whether this is the currently active tab.
  final bool isActive;

  /// Called when this label is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptBudgetRightDockTabLabel({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color)),
            const SizedBox(height: 4),
            Container(
              height: 2,
              width: 32,
              color: isActive ? theme.colorScheme.primary : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}

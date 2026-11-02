// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_budget_right_dock_tab.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_right_dock_frame.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_right_dock_tab_label.dart';

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

  /// The built account inspector, shown when [activeTab] is [OcptBudgetRightDockTab.inspector].
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

  /// Build the budget right dock as a [Column].
  /// Build the budget right dock as an [OcptRightDockFrame].
  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return OcptRightDockFrame(
      tabs: [
        for (final tab in availableTabs)
          OcptRightDockTabLabel(
            label: switch (tab) {
              OcptBudgetRightDockTab.inspector => tr.budgetRightDockInspectorTabLabel,
              OcptBudgetRightDockTab.versions => tr.budgetRightDockVersionsTabLabel,
              OcptBudgetRightDockTab.help => tr.budgetRightDockHelpTabLabel,
            },
            isActive: activeTab == tab,
            onTap: () => onTabSelected(tab),
          ),
      ],
      closeTooltip: tr.budgetRightDockCloseTooltip,
      onClose: onClose,
      body: switch (activeTab) {
        OcptBudgetRightDockTab.inspector => inspectorChild,
        OcptBudgetRightDockTab.versions => versionsChild,
        OcptBudgetRightDockTab.help => helpChild,
      },
    );
  }
}

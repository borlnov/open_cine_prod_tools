// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_people_list.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_tab_bar.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

/// The resources mode's left dock body: the tab bar, a header row (the active tab's title on the
/// left, its count on the right), the scrolling list, and — on the [OcptResourcesTab.people] tab
/// alone — a full-width accent button at the bottom.
///
/// That button is the mode's only person-creation affordance: Benoit chose the mock-up's placement
/// over the plan's own toolbar action. It is withheld (a null [onAddPersonRequested], rendered as
/// no button at all) while a project version is being previewed read-only, and it is only shown on
/// the people tab in this milestone — [OcptResourcesTab.roles], [OcptResourcesTab.locations] and
/// [OcptResourcesTab.elements] show a shared, discreet "coming in a future version" placeholder
/// line instead of a list, and have nothing to add yet.
class OcptResourcesListPanel extends StatelessWidget {
  /// The left dock's currently active tab.
  final OcptResourcesTab activeTab;

  /// The whole address book, in display order — read regardless of [activeTab], since the header
  /// count of the [OcptResourcesTab.people] tab needs it even when another tab is showing.
  final List<OcptPerson> people;

  /// The id of the selected person, or null if none is.
  final String? selectedPersonId;

  /// Called with the tab tapped in the tab bar.
  final ValueChanged<OcptResourcesTab> onTabSelected;

  /// Called with a person's id when their row is clicked.
  final ValueChanged<String> onPersonSelected;

  /// Called when the footer's `+ Add a person` button is clicked, or null while it may not be used
  /// (a project version being previewed read-only) — no button is rendered at all then.
  final VoidCallback? onAddPersonRequested;

  /// Class constructor
  const OcptResourcesListPanel({
    super.key,
    required this.activeTab,
    required this.people,
    required this.selectedPersonId,
    required this.onTabSelected,
    required this.onPersonSelected,
    required this.onAddPersonRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isPeopleTab = activeTab == OcptResourcesTab.people;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OcptResourcesTabBar(activeTab: activeTab, onTabSelected: onTabSelected),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(ocptResourcesTabLabel(tr, activeTab), style: theme.textTheme.titleSmall),
              ),
              if (isPeopleTab)
                Text(
                  tr.resourcesStatsPeople(people.length),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _buildBody(context, tr)),
        if (isPeopleTab) ...[
          Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(10),
            child: FilledButton(
              onPressed: onAddPersonRequested,
              child: Text(tr.resourcesAddPersonAction),
            ),
          ),
        ],
      ],
    );
  }

  /// The list area: [OcptPeopleList] on the people tab, or a shared, discreet muted placeholder
  /// line on the three tabs with no content yet.
  Widget _buildBody(BuildContext context, Tr tr) {
    if (activeTab == OcptResourcesTab.people) {
      return OcptPeopleList(
        people: people,
        selectedPersonId: selectedPersonId,
        onPersonSelected: onPersonSelected,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        tr.workspaceEmptyModeMessage(ocptResourcesTabLabel(tr, activeTab)),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

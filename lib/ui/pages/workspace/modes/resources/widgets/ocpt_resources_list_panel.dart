// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_location.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/types/ocpt_resources_tab.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_locations_list.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_people_list.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_tab_bar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_roles_list.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

/// The resources mode's left dock body: the tab bar, a header row (the active tab's title on the
/// left, its count on the right), the scrolling list, and — on [OcptResourcesTab.people] and
/// [OcptResourcesTab.roles] — a full-width footer action, contextual to whichever tab is active.
///
/// The people and locations tabs' footers create a record outright; the roles tab's opens a small
/// menu offering `Silent role` and `Extra` — `speaking` is never offered, since only
/// `OcptRoleIndexService.reconcile` ever creates one, from the screenplay's own speaking
/// characters. Every footer is withheld — no button at all, rather than a disabled one — while a
/// project version is being previewed read-only. [OcptResourcesTab.elements] shows a discreet
/// "coming in a future version" placeholder line instead of a list, and has nothing to add yet.
class OcptResourcesListPanel extends StatelessWidget {
  /// The left dock's currently active tab.
  final OcptResourcesTab activeTab;

  /// The whole address book, in display order — read regardless of [activeTab], since the header
  /// count of the [OcptResourcesTab.people] tab needs it even when another tab is showing, and the
  /// roles list resolves a role's cast member from it.
  final List<OcptPerson> people;

  /// The id of the selected person, or null if none is.
  final String? selectedPersonId;

  /// The whole cast, in display order — read regardless of [activeTab] for the same reason
  /// [people] is.
  final List<OcptRole> roles;

  /// The id of the selected role, or null if none is.
  final String? selectedRoleId;

  /// Every location, in display order — read regardless of [activeTab] for the same reason [people]
  /// is: the [OcptResourcesTab.locations] header count is shown whichever tab is active.
  final List<OcptLocation> locations;

  /// The id of the selected location, or null if none is.
  final String? selectedLocationId;

  /// Called with the tab tapped in the tab bar.
  final ValueChanged<OcptResourcesTab> onTabSelected;

  /// Called with a person's id when their row is clicked.
  final ValueChanged<String> onPersonSelected;

  /// Called with a role's id when their row is clicked.
  final ValueChanged<String> onRoleSelected;

  /// Called with a location's id when its row is clicked.
  final ValueChanged<String> onLocationSelected;

  /// Called when the footer's `+ Add a person` button is clicked, or null while it may not be used
  /// (a project version being previewed read-only) — no button is rendered at all then.
  final VoidCallback? onAddPersonRequested;

  /// Called with the kind picked from the footer's `+ Add a role` menu (`silent` or `extra`), or
  /// null while it may not be used — no button is rendered at all then.
  final ValueChanged<OcptRoleKind>? onAddRoleRequested;

  /// Called when the footer's `+ Add a location` button is clicked, or null while it may not be
  /// used — no button is rendered at all then.
  final VoidCallback? onAddLocationRequested;

  /// Class constructor
  const OcptResourcesListPanel({
    super.key,
    required this.activeTab,
    required this.people,
    required this.selectedPersonId,
    required this.roles,
    required this.selectedRoleId,
    required this.locations,
    required this.selectedLocationId,
    required this.onTabSelected,
    required this.onPersonSelected,
    required this.onRoleSelected,
    required this.onLocationSelected,
    required this.onAddPersonRequested,
    required this.onAddRoleRequested,
    required this.onAddLocationRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final isPeopleTab = activeTab == OcptResourcesTab.people;
    final isRolesTab = activeTab == OcptResourcesTab.roles;
    final isLocationsTab = activeTab == OcptResourcesTab.locations;

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
                )
              else if (isRolesTab)
                Text(
                  tr.resourcesStatsRoles(roles.length),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else if (isLocationsTab)
                Text(
                  tr.resourcesStatsLocations(locations.length),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _buildBody(context, tr)),
        if (isPeopleTab && onAddPersonRequested != null) ...[
          Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(10),
            child: FilledButton(
              onPressed: onAddPersonRequested,
              child: Text(tr.resourcesAddPersonAction),
            ),
          ),
        ] else if (isRolesTab && onAddRoleRequested != null) ...[
          Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(10),
            child: _OcptAddRoleButton(onKindPicked: onAddRoleRequested!),
          ),
        ] else if (isLocationsTab && onAddLocationRequested != null) ...[
          Divider(height: 1, thickness: 1, color: theme.colorScheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(10),
            child: FilledButton(
              onPressed: onAddLocationRequested,
              child: Text(tr.resourcesAddLocationAction),
            ),
          ),
        ],
      ],
    );
  }

  /// The list area: [OcptPeopleList] on the people tab, [OcptRolesList] on the roles tab,
  /// [OcptLocationsList] on the locations tab, or a discreet muted placeholder line on the one tab
  /// with no content yet.
  Widget _buildBody(BuildContext context, Tr tr) {
    if (activeTab == OcptResourcesTab.people) {
      return OcptPeopleList(
        people: people,
        selectedPersonId: selectedPersonId,
        onPersonSelected: onPersonSelected,
      );
    }

    if (activeTab == OcptResourcesTab.roles) {
      return OcptRolesList(
        roles: roles,
        people: people,
        selectedRoleId: selectedRoleId,
        onRoleSelected: onRoleSelected,
      );
    }

    if (activeTab == OcptResourcesTab.locations) {
      return OcptLocationsList(
        locations: locations,
        selectedLocationId: selectedLocationId,
        onLocationSelected: onLocationSelected,
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

/// The roles tab's footer button: a full-width `+ Add a role` action opening a small menu of the
/// two kinds a role may be hand-added as (`silent` and `extra`) — `speaking` is deliberately never
/// one of them, see the class doc comment above.
///
/// Built on [MenuAnchor]/[MenuItemButton], exactly as `OcptPersonSheetAvatar`'s own colour popover
/// is, so picking an entry closes the menu for free.
class _OcptAddRoleButton extends StatelessWidget {
  /// Called with the kind picked.
  final ValueChanged<OcptRoleKind> onKindPicked;

  /// Class constructor
  const _OcptAddRoleButton({required this.onKindPicked});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          onPressed: () => onKindPicked(OcptRoleKind.silent),
          child: Text(tr.resourcesAddRoleSilentOption),
        ),
        MenuItemButton(
          onPressed: () => onKindPicked(OcptRoleKind.extra),
          child: Text(tr.resourcesAddRoleExtraOption),
        ),
      ],
      builder: (context, controller, child) => SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: () => controller.isOpen ? controller.close() : controller.open(),
          child: Text(tr.resourcesAddRoleAction),
        ),
      ),
    );
  }
}

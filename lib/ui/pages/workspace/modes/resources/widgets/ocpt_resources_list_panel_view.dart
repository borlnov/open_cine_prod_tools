// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_elements_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_locations_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_people_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_roles_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_list_panel.dart';

/// The resources mode's left dock, the shell's `leftPanel`: an [OcptResourcesListPanel] wired to
/// the mode bloc and to the view blocs that create records.
///
/// Every `+ Add …` action is withheld — a null callback — while a project version is being
/// previewed: the list is then a way of reading that version, not of changing it.
class OcptResourcesListPanelView extends StatelessWidget {
  /// The mode's state, which the lists, the selection and the search are read from.
  final OcptResourcesState state;

  /// The project's episodes, from `OcptWorkspaceBloc.state.episodes` — the shell's own selector
  /// reads the same list, so the roles tab's episode lines can never disagree with it — rather
  /// than a second load of its own: only the workspace bloc owns and refreshes a project's
  /// episodes.
  final List<OcptEpisode> episodes;

  /// Class constructor
  const OcptResourcesListPanelView({super.key, required this.state, required this.episodes});

  @override
  Widget build(BuildContext context) => OcptResourcesListPanel(
    activeTab: state.activeTab,
    people: state.people,
    selectedPersonId: state.selectedPersonId,
    roles: state.roles,
    candidatesByRoleId: state.snapshot?.candidatesByRoleId ?? const {},
    selectedRoleId: state.selectedRoleId,
    episodes: episodes,
    locations: state.locations,
    selectedLocationId: state.selectedLocationId,
    elements: state.elements,
    selectedElementId: state.selectedElementId,
    isSearchVisible: state.isSearchVisible,
    searchQuery: state.searchQuery,
    onTabSelected: (tab) =>
        context.read<OcptResourcesBloc>().add(OcptResourcesTabSelectedEvent(tab: tab)),
    onSearchQueryChanged: (query) =>
        context.read<OcptResourcesBloc>().add(OcptResourcesSearchQueryChangedEvent(query: query)),
    onPersonSelected: (personId) =>
        context.read<OcptResourcesBloc>().add(OcptResourcesPersonSelectedEvent(personId: personId)),
    onRoleSelected: (roleId) =>
        context.read<OcptResourcesBloc>().add(OcptResourcesRoleSelectedEvent(roleId: roleId)),
    onLocationSelected: (locationId) => context.read<OcptResourcesBloc>().add(
      OcptResourcesLocationSelectedEvent(locationId: locationId),
    ),
    onElementSelected: (elementId) => context.read<OcptResourcesBloc>().add(
      OcptResourcesElementSelectedEvent(elementId: elementId),
    ),
    onAddPersonRequested: state.isPreviewingVersion
        ? null
        : () => context.read<OcptResourcesPeopleBloc>().add(
            const OcptResourcesPersonCreationRequestedEvent(),
          ),
    onAddRoleRequested: state.isPreviewingVersion
        ? null
        : (kind) => context.read<OcptResourcesRolesBloc>().add(
            OcptResourcesRoleCreationRequestedEvent(kind: kind),
          ),
    onAddLocationRequested: state.isPreviewingVersion
        ? null
        : () => context.read<OcptResourcesLocationsBloc>().add(
            const OcptResourcesLocationCreationRequestedEvent(),
          ),
    onAddElementRequested: state.isPreviewingVersion
        ? null
        : (category) => context.read<OcptResourcesElementsBloc>().add(
            OcptResourcesElementCreationRequestedEvent(category: category),
          ),
  );
}

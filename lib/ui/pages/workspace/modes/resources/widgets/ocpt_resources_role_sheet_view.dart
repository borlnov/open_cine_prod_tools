// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_episode.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_elements_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_event.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_roles_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_roles_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/resources_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_role_sheet.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_empty_mode.dart';

/// The resources mode's centre while the roles tab is active: the selected role's [OcptRoleSheet],
/// or the empty state — the one explaining where roles come from while the cast itself is empty,
/// the one asking for a selection otherwise.
///
/// The sheet sits inside a [BlocBuilder] on [OcptResourcesRolesBloc] alone, so a keystroke in one
/// of its fields redraws the sheet and not the shell around it. The element links go to
/// [OcptResourcesElementsBloc]; opening a person's sheet stays on the mode bloc. Deleting the role
/// or removing a candidate and merging two roles are only *asked*, through [onDeleteRequested],
/// [onCandidateRemoveRequested] and [onMergeRequested]: the mode owns their confirmation dialogs.
class OcptResourcesRoleSheetView extends StatelessWidget {
  /// The mode's state, which the selected role and the shared lists are read from.
  final OcptResourcesState state;

  /// The project's episodes, the roles tab's own: handed down rather than reloaded, since only the
  /// workspace bloc owns and refreshes them.
  final List<OcptEpisode> episodes;

  /// Called when the user asked to delete the selected role.
  final VoidCallback onDeleteRequested;

  /// Called with the id of the candidacy the user asked to remove.
  final ValueChanged<String> onCandidateRemoveRequested;

  /// Called with the source and the target role ids when the user asked to merge two roles.
  final void Function(String sourceRoleId, String targetRoleId) onMergeRequested;

  /// Class constructor
  const OcptResourcesRoleSheetView({
    super.key,
    required this.state,
    required this.episodes,
    required this.onDeleteRequested,
    required this.onCandidateRemoveRequested,
    required this.onMergeRequested,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final selectedRole = state.selectedRole;

    if (selectedRole == null) {
      return OcptWorkspaceEmptyMode(
        icon: Icons.theater_comedy_outlined,
        message: state.roles.isEmpty ? tr.resourcesRolesEmptyHint : tr.resourcesNoRoleSelectedHint,
      );
    }

    final bloc = context.read<OcptResourcesBloc>();
    final rolesBloc = context.read<OcptResourcesRolesBloc>();
    final elementsBloc = context.read<OcptResourcesElementsBloc>();
    final castMember = state.personOf(selectedRole.personId);

    return BlocBuilder<OcptResourcesRolesBloc, OcptResourcesRolesState>(
      builder: (context, rolesState) => OcptRoleSheet(
        key: ValueKey(selectedRole.id),
        role: selectedRole,
        castMember: castMember,
        otherRoles: _otherRolesOf(selectedRole, castMember),
        people: state.people,
        candidates: state.candidatesOfRole(selectedRole.id),
        candidateNotesValueOf: (candidateId) =>
            _candidateNotesValueOf(rolesState, selectedRole, candidateId),
        elements: state.elements,
        episodes: episodes,
        removedRoleAlert: state.selectedRoleAlert,
        mergeTargets: state.selectedRoleAlert == null
            ? const []
            : state.mergeTargetsOf(state.selectedRoleAlert!),
        collisionAlert: state.selectedRoleCollisionAlert,
        onMergeRequested: onMergeRequested,
        isReadOnly: state.isPreviewingVersion,
        fieldValueOf: (field) => _roleFieldValueOf(rolesState, selectedRole, field),
        onFieldChanged: (field, rawValue) => rolesBloc.add(
          OcptResourcesRoleFieldChangedEvent(
            roleId: selectedRole.id,
            field: field,
            rawValue: rawValue,
          ),
        ),
        onCastChanged: (personId) => rolesBloc.add(
          OcptResourcesRoleCastChangedEvent(roleId: selectedRole.id, personId: personId),
        ),
        onKindChanged: (kind) =>
            rolesBloc.add(OcptResourcesRoleKindChangedEvent(roleId: selectedRole.id, kind: kind)),
        onEpisodesChanged: (episodeIds) => rolesBloc.add(
          OcptResourcesRoleEpisodesChangedEvent(roleId: selectedRole.id, episodeIds: episodeIds),
        ),
        onDeleteRequested: onDeleteRequested,
        onOrphanedRoleKept: () =>
            rolesBloc.add(OcptResourcesOrphanedRoleKeptEvent(roleId: selectedRole.id)),
        onPersonSheetOpenRequested: (personId) =>
            bloc.add(OcptResourcesPersonSheetOpenRequestedEvent(personId: personId)),
        onCandidateAdded: (personId) => rolesBloc.add(
          OcptResourcesRoleCandidateAddedEvent(roleId: selectedRole.id, personId: personId),
        ),
        onCandidateStatusChanged: (candidateId, status) => rolesBloc.add(
          OcptResourcesRoleCandidateStatusChangedEvent(candidateId: candidateId, status: status),
        ),
        onCandidateAuditionDateChanged: (candidateId, auditionedOn) => rolesBloc.add(
          OcptResourcesRoleCandidateAuditionDateChangedEvent(
            candidateId: candidateId,
            auditionedOn: auditionedOn,
          ),
        ),
        onCandidateNotesChanged: (candidateId, rawValue) => rolesBloc.add(
          OcptResourcesRoleCandidateFieldChangedEvent(
            candidateId: candidateId,
            field: OcptRoleCandidateField.notes,
            rawValue: rawValue,
          ),
        ),
        onCandidateRemoveRequested: onCandidateRemoveRequested,
        onElementLinked: (elementId) => elementsBloc.add(
          OcptResourcesElementLinkedToRoleEvent(roleId: selectedRole.id, elementId: elementId),
        ),
        onRoleElementUpdated: (id, notes) =>
            elementsBloc.add(OcptResourcesRoleElementUpdatedEvent(id: id, notes: notes)),
        onRoleElementRemoved: (id) =>
            elementsBloc.add(OcptResourcesRoleElementRemovedEvent(id: id)),
      ),
    );
  }

  /// The other roles [castMember] holds beside [role], in display order, or empty while [role] is
  /// uncast or its cast member holds only this one.
  List<OcptRole> _otherRolesOf(OcptRole role, OcptPerson? castMember) {
    if (castMember == null) {
      return const [];
    }

    return [
      for (final other in state.roles)
        if (other.id != role.id && other.personId == castMember.id) other,
    ];
  }

  /// [role]'s current value for [field]: a pending edit still sitting in the bloc's debounce takes
  /// priority over the role's own stored value, so typing is never overwritten by an unrelated
  /// reload. Mirrors `OcptResourcesPersonSheetView`'s own lookup.
  String _roleFieldValueOf(OcptResourcesRolesState state, OcptRole role, OcptRoleField field) {
    final pending = state.pendingRoleFieldEdits[(role.id, field)];
    if (pending != null) {
      return pending;
    }

    return switch (field) {
      OcptRoleField.name => role.name,
      OcptRoleField.castingNotes => role.castingNotes,
    };
  }

  /// Candidacy [candidateId]'s current note: a pending edit still sitting in the bloc's debounce
  /// takes priority over the candidacy's own stored value, so typing is never overwritten by an
  /// unrelated reload. Mirrors [_roleFieldValueOf], one level down — a candidacy rather than a
  /// role.
  String _candidateNotesValueOf(
    OcptResourcesRolesState rolesState,
    OcptRole role,
    String candidateId,
  ) {
    final pending =
        rolesState.pendingCandidateFieldEdits[(candidateId, OcptRoleCandidateField.notes)];
    if (pending != null) {
      return pending;
    }

    for (final candidate in state.candidatesOfRole(role.id)) {
      if (candidate.id == candidateId) {
        return candidate.notes;
      }
    }

    return "";
  }
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/types/ocpt_role_candidate_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/events/resources_base_event.dart';

/// The events about roles and their candidates.
sealed class OcptResourcesRolesEvent extends OcptResourcesEvent {
  /// Class constructor
  const OcptResourcesRolesEvent();
}

/// Requests adding a hand-added role of [kind] at the end of the cast, then selecting it: the
/// left dock's `+ Add a role` action, offering `silent` and `extra` (never `speaking`, which only
/// `OcptRoleIndexService.reconcile` ever creates).
class OcptResourcesRoleCreationRequestedEvent extends OcptResourcesRolesEvent {
  /// The kind of the role to create, never [OcptRoleKind.speaking].
  final OcptRoleKind kind;

  /// Class constructor
  const OcptResourcesRoleCreationRequestedEvent({required this.kind});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, kind];
}

/// Records the raw text just typed into [field] of role [roleId], dispatched by the role sheet on
/// every keystroke.
///
/// Rides the same field-edit autosave debounce as `OcptResourcesPersonFieldChangedEvent`: the
/// typed value becomes visible immediately as a pending edit in
/// `OcptResourcesRolesState.pendingRoleFieldEdits`, and (re)starts the debounce that eventually
/// writes it.
class OcptResourcesRoleFieldChangedEvent extends OcptResourcesRolesEvent {
  /// The id of the role whose field was edited.
  final String roleId;

  /// The field edited.
  final OcptRoleField field;

  /// The raw text now sitting in the field, exactly as typed.
  final String rawValue;

  /// Class constructor
  const OcptResourcesRoleFieldChangedEvent({
    required this.roleId,
    required this.field,
    required this.rawValue,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, roleId, field, rawValue];
}

/// Casts person [personId] to role [roleId] (or uncasts it, when [personId] is null), written
/// immediately: picking a cast member from a menu is a single discrete action, not typing.
class OcptResourcesRoleCastChangedEvent extends OcptResourcesRolesEvent {
  /// The id of the role being cast.
  final String roleId;

  /// The id of the person now cast in this role, or null to uncast it.
  final String? personId;

  /// Class constructor
  const OcptResourcesRoleCastChangedEvent({required this.roleId, required this.personId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, roleId, personId];
}

/// Sets role [roleId]'s kind to [kind], written immediately: picking a kind from a menu is a
/// single discrete action, not typing.
class OcptResourcesRoleKindChangedEvent extends OcptResourcesRolesEvent {
  /// The id of the role whose kind changed.
  final String roleId;

  /// The new kind.
  final OcptRoleKind kind;

  /// Class constructor
  const OcptResourcesRoleKindChangedEvent({required this.roleId, required this.kind});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, roleId, kind];
}

/// Sets the exact episodes role [roleId] is named in to [episodeIds], written immediately —
/// `OcptRoleSheetEpisodesCard`'s own chips, the one place in the app a `role_episodes` row is
/// written by a gesture rather than by `OcptRoleIndexService.reconcile`
/// (`docs/adr/0019-one-project-several-episodes.md` §4.3). Only ever dispatched for a hand-added
/// role: the sheet withholds the card's callback for one the screenplay still owns.
class OcptResourcesRoleEpisodesChangedEvent extends OcptResourcesRolesEvent {
  /// The id of the role whose episodes changed.
  final String roleId;

  /// The full new set of episode ids the role is named in.
  final Set<String> episodeIds;

  /// Class constructor
  const OcptResourcesRoleEpisodesChangedEvent({required this.roleId, required this.episodeIds});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, roleId, episodeIds];
}

/// Requests deleting role [roleId], dispatched once `OcptResourcesDeleteConfirmDialog` has already
/// confirmed it — or straight from the removed-role banner, which is that question itself.
/// Tombstones the role,
/// clears the selection when it was the selected role, and drops any pending field edit that
/// still targeted it.
class OcptResourcesRoleDeletionRequestedEvent extends OcptResourcesRolesEvent {
  /// The id of the role to delete.
  final String roleId;

  /// Class constructor
  const OcptResourcesRoleDeletionRequestedEvent({required this.roleId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, roleId];
}

/// The removed-role banner's "keep it" action for role [roleId]: it stops being owned by
/// `OcptRoleIndexService.reconcile` and becomes a hand-added `silent` role, its casting and notes
/// untouched.
class OcptResourcesOrphanedRoleKeptEvent extends OcptResourcesRolesEvent {
  /// The id of the orphaned role to keep.
  final String roleId;

  /// Class constructor
  const OcptResourcesOrphanedRoleKeptEvent({required this.roleId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, roleId];
}

/// Requests merging role [sourceRoleId] into role [targetRoleId], dispatched once the shared role
/// alert banner's merge affordance — either variant — has already been confirmed through
/// `OcptConfirmDialog`, by the mode.
///
/// Written immediately through `OcptRoleIndexService.mergeRole`: the banner disappears on its own
/// once the reloaded cast no longer holds [sourceRoleId], or is no longer orphaned/collided.
class OcptResourcesRoleMergeRequestedEvent extends OcptResourcesRolesEvent {
  /// The id of the role merged away.
  final String sourceRoleId;

  /// The id of the role [sourceRoleId] is merged into.
  final String targetRoleId;

  /// Class constructor
  const OcptResourcesRoleMergeRequestedEvent({
    required this.sourceRoleId,
    required this.targetRoleId,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, sourceRoleId, targetRoleId];
}

/// Records that person [personId] is a candidate for role [roleId], appended after that role's
/// other candidates, written immediately: `OcptResourcesPersonPicker`'s own pick, dispatched by the
/// candidates card's `Candidate` action.
class OcptResourcesRoleCandidateAddedEvent extends OcptResourcesRolesEvent {
  /// The id of the role the person is a candidate for.
  final String roleId;

  /// The id of the person now a candidate for this role.
  final String personId;

  /// Class constructor
  const OcptResourcesRoleCandidateAddedEvent({required this.roleId, required this.personId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, roleId, personId];
}

/// Sets candidacy [candidateId]'s status to [status], written immediately.
///
/// **The single event behind every status gesture the candidates card offers**, `Retain` and
/// `Drop` included: retaining a candidate is this event with
/// [OcptRoleCandidateStatus.retained], and dropping one is this event with
/// [OcptRoleCandidateStatus.seen]. The rule keeping `roles.personId` in step with the retained
/// candidacy lives in `OcptRoleCandidatesService.setStatus` alone — a second event could only ever
/// end up disagreeing with it.
class OcptResourcesRoleCandidateStatusChangedEvent extends OcptResourcesRolesEvent {
  /// The id of the candidacy whose status changed.
  final String candidateId;

  /// The new status.
  final OcptRoleCandidateStatus status;

  /// Class constructor
  const OcptResourcesRoleCandidateStatusChangedEvent({
    required this.candidateId,
    required this.status,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, candidateId, status];
}

/// Sets candidacy [candidateId]'s audition date to [auditionedOn] (or clears it, when null),
/// written immediately: picking a date is a single discrete action, not typing.
class OcptResourcesRoleCandidateAuditionDateChangedEvent extends OcptResourcesRolesEvent {
  /// The id of the candidacy whose audition date changed.
  final String candidateId;

  /// The new date, or null to clear it.
  final DateTime? auditionedOn;

  /// Class constructor
  const OcptResourcesRoleCandidateAuditionDateChangedEvent({
    required this.candidateId,
    required this.auditionedOn,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, candidateId, auditionedOn];
}

/// Records the raw text just typed into [field] of candidacy [candidateId], dispatched by the
/// candidates card on every keystroke.
///
/// Rides the same field-edit autosave debounce as `OcptResourcesRoleFieldChangedEvent`: the typed
/// value becomes visible immediately as a pending edit in
/// `OcptResourcesRolesState.pendingCandidateFieldEdits`, and (re)starts the debounce that
/// eventually writes it.
class OcptResourcesRoleCandidateFieldChangedEvent extends OcptResourcesRolesEvent {
  /// The id of the candidacy whose field was edited.
  final String candidateId;

  /// The field edited.
  final OcptRoleCandidateField field;

  /// The raw text now sitting in the field, exactly as typed.
  final String rawValue;

  /// Class constructor
  const OcptResourcesRoleCandidateFieldChangedEvent({
    required this.candidateId,
    required this.field,
    required this.rawValue,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, candidateId, field, rawValue];
}

/// Requests removing candidacy [candidateId], dispatched once `OcptResourcesDeleteConfirmDialog`
/// (or its own confirm dialog, opened by the mode) has already confirmed it. Drops any pending
/// field edit that still targeted it.
///
/// **The `people` row it names is never touched** — a person outlives a candidacy — and neither is
/// any other candidacy of the role.
class OcptResourcesRoleCandidateRemovedEvent extends OcptResourcesRolesEvent {
  /// The id of the candidacy to remove.
  final String candidateId;

  /// Class constructor
  const OcptResourcesRoleCandidateRemovedEvent({required this.candidateId});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, candidateId];
}

/// Fired by the field-edit debounce timer `OcptResourcesRoleFieldChangedEvent` and
/// `OcptResourcesRoleCandidateFieldChangedEvent` (re)start, once it elapses with no further edit.
/// Not meant to be dispatched by a widget directly.
class OcptResourcesRolesFieldEditFlushRequestedEvent extends OcptResourcesRolesEvent {
  /// Class constructor
  const OcptResourcesRolesFieldEditFlushRequestedEvent();
}

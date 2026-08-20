// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/types/ocpt_role_candidate_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_avatar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_sheet_date_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

/// The radius of a row's avatar, matching the roles and people lists' own rows.
const double _avatarRadius = 13;

/// "Who was seen for this part": one row per live `role_candidates` link, the retained one pinned
/// on top, over the picker adding another.
///
/// `OcptRoleSheetElementsCard`'s sibling on the casting side, and built to the same chrome and
/// prose density: a row rather than a chip, because a candidacy carries a status, an audition date
/// and a note of its own — none of it about the person, all of it about how this part's casting
/// is going.
///
/// **The retained candidacy is pinned on top and wears the accent**; every other candidacy keeps
/// the `sortKey` order it came in — the order the casting director actually ranked them in. This
/// pinning is a reading this card does when it draws the list: `OcptRoleCandidatesService
/// .loadCandidatesByRoleId`'s own doc comment says, deliberately, that it does not do this itself.
///
/// Every write callback is nullable, null being what withholds the affordance it drives (a project
/// version being previewed read-only): `OcptRoleSheet` nulls every one of them out itself before
/// handing them down, exactly as it already does for the casting, episodes and things cards.
class OcptRoleSheetCandidatesCard extends StatelessWidget {
  /// This role's own live candidacies, in their own `sortKey` order.
  final List<OcptRoleCandidate> candidates;

  /// The whole address book: what the `+ Candidate` picker offers, once the people already
  /// candidates for this role are excluded.
  final List<OcptPerson> people;

  /// The note to show for a candidacy, given its id: a pending edit still sitting in the bloc's
  /// debounce, or the candidacy's own stored value — resolved by the mode exactly as
  /// `OcptRoleSheet.fieldValueOf` resolves a role's own fields.
  final String Function(String candidateId) notesValueOf;

  /// Called with a person's id when the `+ Candidate` picker adds them, or null while it may not be
  /// used.
  final ValueChanged<String>? onCandidateAdded;

  /// Called with a candidacy's id and its newly picked status, or null while it may not be used —
  /// every status gesture the `⋮` menu offers, `Retain` and `Drop` included.
  final void Function(String candidateId, OcptRoleCandidateStatus status)? onStatusChanged;

  /// Called with a candidacy's id and its newly picked audition date (or null, once cleared), or
  /// null while it may not be used.
  final void Function(String candidateId, DateTime? auditionedOn)? onAuditionDateChanged;

  /// Called with a candidacy's id and its note's raw text on every keystroke, or null while it may
  /// not be used.
  ///
  /// Rides the bloc's own 2 s autosave debounce through `OcptResourcesState
  /// .pendingCandidateFieldEdits`: **no local debounce is added here**, unlike the things card's
  /// own row, whose note has no map of its own in the bloc.
  final void Function(String candidateId, String rawValue)? onNotesChanged;

  /// Called with a candidacy's id when the `⋮` menu's `Remove this candidate` entry is picked, or
  /// null while it may not be used. **Only asks** — the mode opens `OcptConfirmDialog`.
  final ValueChanged<String>? onCandidateRemoveRequested;

  /// Class constructor
  const OcptRoleSheetCandidatesCard({
    super.key,
    required this.candidates,
    required this.people,
    required this.notesValueOf,
    required this.onCandidateAdded,
    required this.onStatusChanged,
    required this.onAuditionDateChanged,
    required this.onNotesChanged,
    required this.onCandidateRemoveRequested,
  });

  /// [candidates], the retained one (if any) pinned first, every other one keeping its own
  /// `sortKey` order.
  List<OcptRoleCandidate> get _orderedCandidates => [
    for (final candidate in candidates)
      if (candidate.isRetained) candidate,
    for (final candidate in candidates)
      if (!candidate.isRetained) candidate,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final ordered = _orderedCandidates;

    return OcptResourcesSheetCard(
      title: tr.resourcesRoleCandidatesCardTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ordered.isEmpty)
            Text(
              tr.resourcesRoleNoCandidateHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          for (final candidate in ordered) ...[
            _OcptRoleCandidateRow(
              key: ValueKey(candidate.id),
              candidate: candidate,
              notesValue: notesValueOf(candidate.id),
              onStatusChanged: onStatusChanged,
              onAuditionDateChanged: onAuditionDateChanged,
              onNotesChanged: onNotesChanged,
              onCandidateRemoveRequested: onCandidateRemoveRequested,
            ),
            const SizedBox(height: 8),
          ],
          if (onCandidateAdded != null) _buildCandidatePicker(context, tr, ordered),
        ],
      ),
    );
  }

  /// The `+ Candidate` picker: every address-book entry not already a candidate for this role,
  /// following `OcptRoleSheetElementsCard._buildElementPicker`'s own shape — including rendering
  /// nothing at all once there is nobody left to offer.
  Widget _buildCandidatePicker(BuildContext context, Tr tr, List<OcptRoleCandidate> ordered) {
    final onCandidateAdded = this.onCandidateAdded!;
    final candidatePersonIds = {for (final candidate in ordered) candidate.person.id};
    final offered = [
      for (final person in people)
        if (!candidatePersonIds.contains(person.id)) person,
    ];

    if (offered.isEmpty) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<String>(
        tooltip: "",
        onSelected: onCandidateAdded,
        itemBuilder: (context) => [
          for (final person in offered)
            PopupMenuItem<String>(value: person.id, child: Text(_personLabel(tr, person))),
        ],
        child: Chip(
          avatar: const Icon(Icons.add, size: 14),
          label: Text(tr.resourcesAddCandidateToRoleAction),
        ),
      ),
    );
  }

  /// How a person reads in the picker: their display name, or the shared placeholder for somebody
  /// whose name has not been typed in yet.
  static String _personLabel(Tr tr, OcptPerson person) =>
      person.displayName.isEmpty ? tr.resourcesUnnamedPerson : person.displayName;
}

/// The colour a status pill wears: the accent for [OcptRoleCandidateStatus.retained], a warmer read
/// for [OcptRoleCandidateStatus.shortlisted], the error colour for the two ways a candidacy stops
/// (`declined`, `unavailable`), and a neutral read for [OcptRoleCandidateStatus.seen] — the one
/// status that says nothing has been decided yet.
Color _statusColorOf(ColorScheme scheme, OcptRoleCandidateStatus status) => switch (status) {
  OcptRoleCandidateStatus.retained => scheme.primary,
  OcptRoleCandidateStatus.shortlisted => scheme.tertiary,
  OcptRoleCandidateStatus.seen => scheme.onSurfaceVariant,
  OcptRoleCandidateStatus.declined => scheme.error,
  OcptRoleCandidateStatus.unavailable => scheme.error,
};

/// One row of [OcptRoleSheetCandidatesCard]: the person, their status pill, their `⋮` menu, their
/// audition date and their foldable note.
///
/// A small [StatefulWidget] for one reason alone — the note's fold state, local to the row and
/// **not** riding any bloc state, exactly as the class doc comment explains. Keyed by the
/// candidacy's id, so switching role sheets (a fresh set of candidacy ids) always starts from the
/// row's own default fold rule rather than a stale toggle.
class _OcptRoleCandidateRow extends StatefulWidget {
  /// The candidacy this row shows.
  final OcptRoleCandidate candidate;

  /// The note's current authoritative value — see
  /// [OcptRoleSheetCandidatesCard.notesValueOf].
  final String notesValue;

  /// See [OcptRoleSheetCandidatesCard.onStatusChanged].
  final void Function(String candidateId, OcptRoleCandidateStatus status)? onStatusChanged;

  /// See [OcptRoleSheetCandidatesCard.onAuditionDateChanged].
  final void Function(String candidateId, DateTime? auditionedOn)? onAuditionDateChanged;

  /// See [OcptRoleSheetCandidatesCard.onNotesChanged].
  final void Function(String candidateId, String rawValue)? onNotesChanged;

  /// See [OcptRoleSheetCandidatesCard.onCandidateRemoveRequested].
  final ValueChanged<String>? onCandidateRemoveRequested;

  /// Class constructor
  const _OcptRoleCandidateRow({
    super.key,
    required this.candidate,
    required this.notesValue,
    required this.onStatusChanged,
    required this.onAuditionDateChanged,
    required this.onNotesChanged,
    required this.onCandidateRemoveRequested,
  });

  @override
  State<_OcptRoleCandidateRow> createState() => _OcptRoleCandidateRowState();
}

/// The state of [_OcptRoleCandidateRow]: only the note's local fold flag, seeded once from whether
/// the candidacy already carries a note — so a card of five candidates stays readable at a glance
/// without ever hiding what somebody actually wrote.
class _OcptRoleCandidateRowState extends State<_OcptRoleCandidateRow> {
  /// Whether the note field is currently shown.
  late bool _isNoteExpanded = widget.notesValue.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final candidate = widget.candidate;
    final isRetained = candidate.isRetained;
    final onStatusChanged = widget.onStatusChanged;
    final onCandidateRemoveRequested = widget.onCandidateRemoveRequested;
    final showsMenu = onStatusChanged != null || onCandidateRemoveRequested != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: isRetained
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(ocptRadiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OcptPersonAvatar(person: candidate.person, radius: _avatarRadius),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  OcptRoleSheetCandidatesCard._personLabel(tr, candidate.person),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isRetained ? theme.colorScheme.primary : null,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _OcptCandidateStatusPill(status: candidate.status),
              if (showsMenu) ...[
                const SizedBox(width: 2),
                _buildActionsMenu(
                  context,
                  tr,
                  isRetained,
                  onStatusChanged,
                  onCandidateRemoveRequested,
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          OcptPersonSheetDateField(
            label: tr.resourcesRoleCandidateAuditionDateLabel,
            value: candidate.auditionedOn,
            onChanged: widget.onAuditionDateChanged == null
                ? null
                : (auditionedOn) => widget.onAuditionDateChanged!(candidate.id, auditionedOn),
          ),
          const SizedBox(height: 8),
          _buildNoteToggle(context, tr),
          if (_isNoteExpanded) ...[
            const SizedBox(height: 4),
            OcptResourcesSheetField(
              ownerId: candidate.id,
              label: "",
              value: widget.notesValue,
              multiline: true,
              onChanged: widget.onNotesChanged == null
                  ? null
                  : (value) => widget.onNotesChanged!(candidate.id, value),
            ),
          ],
        ],
      ),
    );
  }

  /// The row's own `⋮`: the five statuses under a heading entry, `Retain`/`Drop`, a divider, then
  /// `Remove this candidate` — each group withheld on its own when the callback behind it is
  /// null.
  Widget _buildActionsMenu(
    BuildContext context,
    Tr tr,
    bool isRetained,
    void Function(String candidateId, OcptRoleCandidateStatus status)? onStatusChanged,
    ValueChanged<String>? onCandidateRemoveRequested,
  ) {
    final candidateId = widget.candidate.id;

    return PopupMenuButton<VoidCallback>(
      icon: const Icon(Icons.more_vert, size: 16),
      tooltip: tr.resourcesRoleCandidateActionsTooltip,
      padding: EdgeInsets.zero,
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        if (onStatusChanged != null) ...[
          PopupMenuItem<VoidCallback>(
            enabled: false,
            height: 28,
            child: Text(
              tr.resourcesRoleCandidateStatusMenuLabel,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          for (final status in OcptRoleCandidateStatus.values)
            PopupMenuItem<VoidCallback>(
              value: () => onStatusChanged(candidateId, status),
              child: Text(ocptRoleCandidateStatusLabel(tr, status)),
            ),
          PopupMenuItem<VoidCallback>(
            value: () => onStatusChanged(
              candidateId,
              isRetained ? OcptRoleCandidateStatus.seen : OcptRoleCandidateStatus.retained,
            ),
            child: Text(
              isRetained ? tr.resourcesDropCandidateAction : tr.resourcesRetainCandidateAction,
            ),
          ),
        ],
        if (onStatusChanged != null && onCandidateRemoveRequested != null) const PopupMenuDivider(),
        if (onCandidateRemoveRequested != null)
          PopupMenuItem<VoidCallback>(
            value: () => onCandidateRemoveRequested(candidateId),
            child: Text(
              tr.resourcesRemoveCandidateAction,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  /// The small toggle row revealing the note field — `▸`/`▾` and the note's own label.
  Widget _buildNoteToggle(BuildContext context, Tr tr) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => setState(() => _isNoteExpanded = !_isNoteExpanded),
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isNoteExpanded ? Icons.expand_more : Icons.chevron_right,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 2),
          Text(
            tr.resourcesRoleCandidateNotesLabel.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// A candidacy's own status pill: [ocptRoleCandidateStatusLabel]'s text, tinted with
/// [_statusColorOf] — the same "text pill on a soft wash" family the roles tab's own casting pill
/// wears, without sharing a widget with it: one reads a candidacy's status, the other a role's
/// progress, and they must not be able to disagree about what either of those means.
class _OcptCandidateStatusPill extends StatelessWidget {
  /// The status this pill reads.
  final OcptRoleCandidateStatus status;

  /// Class constructor
  const _OcptCandidateStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final color = _statusColorOf(theme.colorScheme, status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusLarge),
      ),
      child: Text(
        ocptRoleCandidateStatusLabel(tr, status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

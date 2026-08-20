// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_role.dart';
import 'package:open_cine_prod_tools/models/ocpt_role_candidate.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_resources_search.dart';

/// The tallest the dialog's own scrollable list is ever drawn before it starts scrolling, in
/// logical pixels — the same figure `OcptScheduleShotPickerDialog` holds, a casting of a hundred
/// candidates having to fit inside one screen exactly as a découpage of a hundred shots does.
const double _ocptScheduleCandidatePickerMaxListHeight = 420;

/// The dialog opened by a slot's own `+ Block` menu's `Audition` entry: every candidacy of the
/// project, grouped by the **part** it is for, searchable, each row clickable — picking one plans
/// an audition of that candidate, for that part, on the slot that opened this dialog.
///
/// `OcptScheduleShotPickerDialog`'s twin on the casting side, and the same three rules: the mode
/// opens it (a widget only ever asks), it is purely presentational, and it lists **everything**
/// rather than only what is still unplanned — somebody may well be seen twice in one day, so a row
/// already carrying an audition on this day stays clickable and merely says so, muted
/// ([plannedCandidacyIds]).
///
/// A candidacy names a person and a part, which is exactly what a convocation is about: two
/// candidacies of one person are two rows here, under two different headings, because they are two
/// different things to see them about.
///
/// [show] opens it and returns the id of the candidacy picked, or null if the user dismissed it.
/// The router manager (`OcptRouterManager`, never `Navigator`) is what pops it, both on a row click
/// and on `Cancel`.
class OcptScheduleCandidatePickerDialog extends StatefulWidget {
  /// Every live candidacy of the project — `OcptScheduleState.roleCandidates` — in no particular
  /// order: this dialog groups them by part itself, and orders each group by the candidate's own
  /// display name, the casting director's own ranking being a reading of the role sheet rather
  /// than of a running order.
  final List<OcptRoleCandidate> roleCandidates;

  /// The whole cast, keyed by id — what a group's own heading names the part through. A candidacy
  /// whose role this map no longer holds is grouped under the fallback name, read defensively
  /// exactly as the convocations panel reads a stale role id.
  final Map<String, OcptRole> roleById;

  /// The ids of the candidacies the **selected day** already carries an audition block for — the
  /// mark a row wears, never a bar on picking it again.
  final Set<String> plannedCandidacyIds;

  /// Class constructor
  const OcptScheduleCandidatePickerDialog({
    super.key,
    required this.roleCandidates,
    required this.roleById,
    required this.plannedCandidacyIds,
  });

  /// Shows the dialog and returns the id of the candidacy picked, or null if the user dismissed it.
  static Future<String?> show(
    BuildContext context, {
    required List<OcptRoleCandidate> roleCandidates,
    required Map<String, OcptRole> roleById,
    required Set<String> plannedCandidacyIds,
  }) => showDialog<String>(
    context: context,
    builder: (context) => OcptScheduleCandidatePickerDialog(
      roleCandidates: roleCandidates,
      roleById: roleById,
      plannedCandidacyIds: plannedCandidacyIds,
    ),
  );

  @override
  State<OcptScheduleCandidatePickerDialog> createState() =>
      _OcptScheduleCandidatePickerDialogState();
}

/// One part's own section of the dialog's filtered list: the part's own name, over the candidacies
/// of it still matching the search — a plain data holder `_filteredSections` builds and
/// `_buildRoleSection` draws.
class _OcptScheduleCandidatePickerSection {
  /// The part this section's candidacies are for, as it is to be printed.
  final String roleName;

  /// This part's own candidacies still matching the search, in display-name order.
  final List<OcptRoleCandidate> candidates;

  /// Class constructor
  const _OcptScheduleCandidatePickerSection({required this.roleName, required this.candidates});
}

/// The state of [OcptScheduleCandidatePickerDialog]: owns the search field and re-filters
/// [OcptScheduleCandidatePickerDialog.roleCandidates] on every keystroke.
class _OcptScheduleCandidatePickerDialogState extends State<OcptScheduleCandidatePickerDialog> {
  /// The search field's own controller.
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onQueryChanged)
      ..dispose();
    super.dispose();
  }

  void _onQueryChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final filteredSections = _filteredSections(tr);

    return AlertDialog(
      title: Text(tr.scheduleCandidatePickerDialogTitle),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                hintText: tr.scheduleCandidatePickerSearchHint,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: _ocptScheduleCandidatePickerMaxListHeight,
              ),
              child: widget.roleCandidates.isEmpty
                  ? _buildHint(context, tr.scheduleCandidatePickerEmptyHint)
                  : (filteredSections.isEmpty
                        ? _buildHint(context, tr.scheduleCandidatePickerNoResultsHint)
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final section in filteredSections)
                                  _buildRoleSection(context, tr, section),
                              ],
                            ),
                          )),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(tr.scheduleCandidatePickerCancelAction),
        ),
      ],
    );
  }

  /// Every part with at least one candidacy still matching the search field's own text, each
  /// group's own candidacies in display-name order and the groups themselves in part-name order —
  /// a part left with no matching candidate simply disappears, exactly as a sequence left with no
  /// matching shot does in the shot picker.
  List<_OcptScheduleCandidatePickerSection> _filteredSections(Tr tr) {
    final query = _searchController.text;
    final candidatesByRoleName = <String, List<OcptRoleCandidate>>{};

    for (final candidate in widget.roleCandidates) {
      final roleName = _roleNameOf(tr, candidate.roleId);
      if (!ocptResourcesSearchMatches(
        query: query,
        fields: [candidate.person.displayName, roleName],
      )) {
        continue;
      }

      candidatesByRoleName.putIfAbsent(roleName, () => []).add(candidate);
    }

    final roleNames = candidatesByRoleName.keys.toList()..sort();

    return [
      for (final roleName in roleNames)
        _OcptScheduleCandidatePickerSection(
          roleName: roleName,
          candidates: candidatesByRoleName[roleName]!
            ..sort((left, right) => left.person.displayName.compareTo(right.person.displayName)),
        ),
    ];
  }

  /// The name of the part [roleId] names, or the cast's own fallback for a role this dialog's
  /// [OcptScheduleCandidatePickerDialog.roleById] no longer holds.
  String _roleNameOf(Tr tr, String roleId) {
    final role = widget.roleById[roleId];
    return role == null || role.name.isEmpty ? tr.resourcesRoleUnnamed : role.name;
  }

  /// One part's own section: its name as a heading, over its candidacies, each a clickable row.
  Widget _buildRoleSection(
    BuildContext context,
    Tr tr,
    _OcptScheduleCandidatePickerSection section,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.roleName,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          for (final candidate in section.candidates)
            _buildCandidateRow(context, tr, theme, candidate),
        ],
      ),
    );
  }

  /// One candidacy's own row: the candidate's name, where they stand in the casting of the part,
  /// and — while this day already plans to see them for it — a muted mark saying so. The mark is
  /// information, never a bar: the row stays clickable either way, a production regularly seeing
  /// somebody twice in one session.
  Widget _buildCandidateRow(
    BuildContext context,
    Tr tr,
    ThemeData theme,
    OcptRoleCandidate candidate,
  ) {
    final mutedStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return InkWell(
      onTap: () => globalGetIt().get<OcptRouterManager>().pop<String>(candidate.id),
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                candidate.person.displayName.isEmpty
                    ? tr.resourcesUnnamedPerson
                    : candidate.person.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            Text(ocptRoleCandidateStatusLabel(tr, candidate.status), style: mutedStyle),
            if (widget.plannedCandidacyIds.contains(candidate.id)) ...[
              const SizedBox(width: 10),
              Tooltip(
                message: tr.scheduleCandidatePickerAlreadyPlannedTooltip,
                child: Icon(
                  Icons.event_available_outlined,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// A hint filling the list's own area, for either empty state (no candidacy at all, or a search
  /// matching nothing).
  Widget _buildHint(BuildContext context, String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(
      message,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

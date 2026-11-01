// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_crew_positions.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_crew_position_ref.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_crew_position_search.dart';
import 'package:open_cine_prod_tools/types/ocpt_crew_department.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_crew_position_pick_result.dart';

/// The tallest [OcptCrewPositionPickerDialog]'s own scrollable list is ever drawn before it starts
/// scrolling, in logical pixels — the catalogue's own thirteen departments still have to fit on one
/// screen. Mirrors `OcptScheduleShotPickerDialog`'s own figure.
const double _ocptCrewPositionPickerMaxListHeight = 420;

/// The single searchable dialog every crew position picker of the app opens — the person sheet's
/// positions card and the schedule's own crew rows alike: `ocptCrewPositions` (`lib/constants/`)
/// is well past what a menu can lay out at a glance, and a search field scales where scrolling a
/// hundred-odd entries does not.
///
/// A search field at the top, autofocused, filters every section by
/// [ocptCrewPositionSearchMatches] — case- and accent-insensitive, blind to the inclusive writing
/// mark (`·`) a French label carries, and matching its masculine and feminine readings alike
/// (`directrice` finds `Directeur·rice`). Below it: [promoted] first, under its own heading,
/// when the caller has any left to offer (the schedule's own crew row promotes a person's declared
/// positions this way); then the catalogue, grouped under a muted department heading in
/// [OcptCrewDepartment]'s own declaration order; then, when [allowCustomLabel] asks for it, the
/// shared "Custom label…" entry, always shown last and never filtered out by the search — a
/// caller reaches for it precisely when the catalogue has nothing that fits, so hiding it behind a
/// query would defeat its own purpose. [excluded] is left out of both the promoted section and the
/// catalogue, wherever it names one.
///
/// Purely presentational, modelled on `OcptScheduleShotPickerDialog`: [show] opens it and returns
/// an [OcptCrewPositionPickResult], or null if the user dismissed it. The router manager
/// (`OcptRouterManager`, never `Navigator`) is what actually pops it, both on a row click and on
/// `Cancel`.
class OcptCrewPositionPickerDialog extends StatefulWidget {
  /// The positions to show first, under their own heading, ahead of the catalogue — typically a
  /// person's own declared positions not already held on the slot being edited
  /// (`ocptCrewPositionPrefillOf`). Empty when the caller has nothing to promote.
  final List<OcptCrewPositionRef> promoted;

  /// Every position to leave out of both [promoted] and the catalogue — typically the positions
  /// already held on the row being edited.
  final Set<OcptCrewPositionRef> excluded;

  /// Whether the shared "Custom label…" entry is offered at the bottom of the list.
  final bool allowCustomLabel;

  /// Class constructor
  const OcptCrewPositionPickerDialog({
    super.key,
    this.promoted = const [],
    this.excluded = const {},
    this.allowCustomLabel = false,
  });

  @override
  State<OcptCrewPositionPickerDialog> createState() => _OcptCrewPositionPickerDialogState();

  /// Shows the dialog and returns what was picked, or null if the user dismissed it.
  static Future<OcptCrewPositionPickResult?> show(
    BuildContext context, {
    List<OcptCrewPositionRef> promoted = const [],
    Set<OcptCrewPositionRef> excluded = const {},
    bool allowCustomLabel = false,
  }) => showDialog<OcptCrewPositionPickResult>(
    context: context,
    builder: (context) => OcptCrewPositionPickerDialog(
      promoted: promoted,
      excluded: excluded,
      allowCustomLabel: allowCustomLabel,
    ),
  );
}

/// The state of [OcptCrewPositionPickerDialog]: owns the search field and re-filters the promoted
/// list and the catalogue on every keystroke.
class _OcptCrewPositionPickerDialogState extends State<OcptCrewPositionPickerDialog> {
  /// The search field's own controller.
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final query = _searchController.text;
    final filteredPromoted = [
      for (final ref in widget.promoted)
        if (!widget.excluded.contains(ref) &&
            ocptCrewPositionSearchMatches(query: query, label: _labelOf(tr, ref)))
          ref,
    ];
    final byDepartment = <OcptCrewDepartment, List<OcptCrewPosition>>{};
    for (final position in ocptCrewPositions) {
      final ref = OcptCrewPositionRef(positionId: position.id, customLabel: "");
      final label = ocptCrewPositionLabel(tr, position.id);
      if (widget.excluded.contains(ref) ||
          !ocptCrewPositionSearchMatches(query: query, label: label)) {
        continue;
      }
      byDepartment.putIfAbsent(position.department, () => []).add(position);
    }
    final hasResults = filteredPromoted.isNotEmpty || byDepartment.isNotEmpty;

    return AlertDialog(
      title: Text(tr.resourcesCrewPositionPickerTitle),
      content: SizedBox(
        width: 420,
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
                hintText: tr.resourcesCrewPositionPickerSearchHint,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _ocptCrewPositionPickerMaxListHeight),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!hasResults)
                      _OcptCrewPositionPickerHint(
                        message: tr.resourcesCrewPositionPickerNoResultsHint,
                      )
                    else ...[
                      if (filteredPromoted.isNotEmpty)
                        _OcptCrewPositionPickerSection(
                          heading: tr.resourcesCrewPositionPickerPromotedHeading,
                          uppercase: false,
                          children: [
                            for (final ref in filteredPromoted)
                              _OcptCrewPositionPickerRow(label: _labelOf(tr, ref), ref: ref),
                          ],
                        ),
                      for (final department in OcptCrewDepartment.values)
                        if (byDepartment[department] case final positions?)
                          _OcptCrewPositionPickerSection(
                            heading: ocptCrewDepartmentLabel(tr, department),
                            children: [
                              for (final position in positions)
                                _OcptCrewPositionPickerRow(
                                  label: ocptCrewPositionLabel(tr, position.id),
                                  ref: OcptCrewPositionRef(
                                    positionId: position.id,
                                    customLabel: "",
                                  ),
                                ),
                            ],
                          ),
                    ],
                    if (widget.allowCustomLabel) const _OcptCrewPositionPickerCustomRow(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop(),
          child: Text(tr.resourcesCrewPositionPickerCancelAction),
        ),
      ],
    );
  }

  void _onQueryChanged() => setState(() {});

  /// [ref]'s own label: the catalogue's when it names one, [ref].customLabel otherwise — a
  /// promoted ref may itself be a free label, `ocptCrewPositionPrefillOf` promoting whatever a
  /// person declared.
  String _labelOf(Tr tr, OcptCrewPositionRef ref) =>
      ref.positionId.isEmpty ? ref.customLabel : ocptCrewPositionLabel(tr, ref.positionId);

  @override
  void dispose() {
    _searchController
      ..removeListener(_onQueryChanged)
      ..dispose();
    super.dispose();
  }
}

/// One heading, in a muted, bold caption — upper-case for [uppercase] (a department heading), left
/// as written for the promoted section's own heading instead — over its own [children].
class _OcptCrewPositionPickerSection extends StatelessWidget {
  /// The section's heading.
  final String heading;

  /// The rows under the heading.
  final List<Widget> children;

  /// Whether the heading is shown upper-case.
  final bool uppercase;

  /// Class constructor
  const _OcptCrewPositionPickerSection({
    required this.heading,
    required this.children,
    this.uppercase = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              uppercase ? heading.toUpperCase() : heading,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// One clickable row, naming [label] — picking it pops the dialog with [ref].
class _OcptCrewPositionPickerRow extends StatelessWidget {
  /// The row's text.
  final String label;

  /// The position the row picks.
  final OcptCrewPositionRef ref;

  /// Class constructor
  const _OcptCrewPositionPickerRow({required this.label, required this.ref});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => globalGetIt().get<OcptRouterManager>().pop<OcptCrewPositionPickResult>(
      OcptCrewPositionPickResult.position(ref),
    ),
    mouseCursor: ocpt_theme.ocptClickableCursor,
    borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    ),
  );
}

/// The shared "Custom label…" row, always last and never filtered by the search — picking it pops
/// the dialog with [OcptCrewPositionPickResult.custom].
class _OcptCrewPositionPickerCustomRow extends StatelessWidget {
  /// Class constructor
  const _OcptCrewPositionPickerCustomRow();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: InkWell(
      onTap: () => globalGetIt().get<OcptRouterManager>().pop<OcptCrewPositionPickResult>(
        const OcptCrewPositionPickResult.custom(),
      ),
      mouseCursor: ocpt_theme.ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          Tr.of(context).resourcesPositionCustomOptionLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    ),
  );
}

/// A hint filling the list's own area while the search matches nothing.
class _OcptCrewPositionPickerHint extends StatelessWidget {
  /// The hint's text.
  final String message;

  /// Class constructor
  const _OcptCrewPositionPickerHint({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(
      message,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
    ),
  );
}

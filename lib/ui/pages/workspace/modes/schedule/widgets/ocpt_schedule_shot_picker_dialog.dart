// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_sequence.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_resources_search.dart';

/// The tallest the dialog's own scrollable shot list is ever drawn before it starts scrolling, in
/// logical pixels — a découpage of hundreds of shots still has to fit inside one screen.
const double _ocptScheduleShotPickerMaxListHeight = 420;

/// The dialog opened by a slot's own `+ Block` menu's `Shot` entry: every shot of the shot list,
/// grouped by sequence exactly as the left dock's own unplaced-shots list heads them, searchable,
/// each row clickable — picking one places that shot on the slot that opened this dialog.
///
/// **Every shot of the shot list is listed, not only the ones still unplaced**: a shot may be
/// placed more than once (interrupted by the meal break and resumed after it), so an
/// already-placed row stays clickable. It only carries, at the end of its own row, the day tags it
/// is already placed on ([placedDayNumbersByShotId]), muted, so a second placement reads as a
/// deliberate choice rather than an accident nobody warned about.
///
/// Purely presentational, modelled on `OcptScenarioCoverageExportDialog`: [show] opens it and
/// returns the id of the shot picked, or null if the user dismissed it. The router manager
/// (`OcptRouterManager`, never `Navigator`) is what actually pops it, both on a row click and on
/// `Cancel`.
class OcptScheduleShotPickerDialog extends StatefulWidget {
  /// The shot list's own sequences (real scenes, then the orphan group), each with its shots in
  /// their own order — `OcptScheduleState.shotListSnapshot`'s own, unfiltered by placement.
  final List<OcptShotSequence> sequences;

  /// For every shot already placed somewhere in the schedule, the day numbers it is placed on,
  /// deduplicated and in ascending order — `OcptScheduleState.placedDayNumbersByShotId`. A shot
  /// with no entry here is unplaced.
  final Map<String, List<int>> placedDayNumbersByShotId;

  /// Class constructor
  const OcptScheduleShotPickerDialog({
    super.key,
    required this.sequences,
    required this.placedDayNumbersByShotId,
  });

  /// Shows the dialog and returns the id of the shot picked, or null if the user dismissed it.
  static Future<String?> show(
    BuildContext context, {
    required List<OcptShotSequence> sequences,
    required Map<String, List<int>> placedDayNumbersByShotId,
  }) => showDialog<String>(
    context: context,
    builder: (context) => OcptScheduleShotPickerDialog(
      sequences: sequences,
      placedDayNumbersByShotId: placedDayNumbersByShotId,
    ),
  );

  @override
  State<OcptScheduleShotPickerDialog> createState() => _OcptScheduleShotPickerDialogState();
}

/// The state of [OcptScheduleShotPickerDialog]: owns the search field and re-filters
/// [OcptScheduleShotPickerDialog.sequences] on every keystroke.
class _OcptScheduleShotPickerDialogState extends State<OcptScheduleShotPickerDialog> {
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
    final hasAnyShot = widget.sequences.any((sequence) => sequence.shots.isNotEmpty);
    final filteredSequences = _filteredSequences();

    return AlertDialog(
      title: Text(tr.scheduleShotPickerDialogTitle),
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
                hintText: tr.scheduleShotPickerSearchHint,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _ocptScheduleShotPickerMaxListHeight),
              child: !hasAnyShot
                  ? _buildHint(context, tr.scheduleShotPickerEmptyHint)
                  : (filteredSequences.isEmpty
                        ? _buildHint(context, tr.scheduleShotPickerNoResultsHint)
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final sequence in filteredSequences)
                                  _buildSequenceSection(context, tr, sequence),
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
          child: Text(tr.scheduleShotPickerCancelAction),
        ),
      ],
    );
  }

  /// Every sequence of [OcptScheduleShotPickerDialog.sequences] with at least one shot still
  /// matching the search field's own text, each sequence's own shots already narrowed to the
  /// matching ones — a sequence left with nothing simply disappears from the result.
  List<OcptShotSequence> _filteredSequences() {
    final query = _searchController.text;
    final filtered = <OcptShotSequence>[];

    for (final sequence in widget.sequences) {
      final matchingShots = [
        for (final shot in sequence.shots)
          if (ocptResourcesSearchMatches(query: query, fields: _searchFieldsOf(sequence, shot))) shot,
      ];
      if (matchingShots.isEmpty) {
        continue;
      }

      filtered.add(_narrowedTo(sequence, matchingShots));
    }

    return filtered;
  }

  /// The fields a shot of [sequence] is matched against: its own code and shot size, plus — for a
  /// real scene — its heading and display number, so `ins cuisine` finds every shot of `INT.
  /// KITCHEN - DAY` even though neither word names the shot itself.
  List<String> _searchFieldsOf(OcptShotSequence sequence, OcptShot shot) => [
    shot.code,
    shot.shotSize,
    if (sequence is OcptSceneShotSequence) sequence.heading,
    if (sequence is OcptSceneShotSequence) sequence.displaySceneNumber,
  ];

  /// [sequence] with its own shots replaced by [shots] — narrows a sequence down to its matching
  /// shots without losing which subclass (a real scene or the orphan group) it is, which is what
  /// [_buildSequenceSection] reads its own heading off.
  OcptShotSequence _narrowedTo(OcptShotSequence sequence, List<OcptShot> shots) => switch (sequence) {
    OcptSceneShotSequence() => OcptSceneShotSequence(
      sceneId: sequence.sceneId,
      heading: sequence.heading,
      sceneNumber: sequence.sceneNumber,
      displaySceneNumber: sequence.displaySceneNumber,
      charStart: sequence.charStart,
      charEnd: sequence.charEnd,
      shots: shots,
    ),
    OcptOrphanShotSequence() => OcptOrphanShotSequence(shots: shots),
  };

  /// One sequence's own section: its heading — the same reading the left dock's own unplaced-shots
  /// list gives a sequence — over its shots, each a clickable row.
  Widget _buildSequenceSection(BuildContext context, Tr tr, OcptShotSequence sequence) {
    final theme = Theme.of(context);
    final displaySceneNumber = sequence is OcptSceneShotSequence ? sequence.displaySceneNumber : null;
    final heading = sequence is OcptSceneShotSequence ? sequence.heading : null;
    final tag = displaySceneNumber == null
        ? tr.scheduleUnplacedOrphanGroupLabel
        : tr.scheduleUnplacedSequenceLabel(displaySceneNumber);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                tag,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (heading != null) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    heading,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          for (final shot in sequence.shots) _buildShotRow(context, tr, theme, shot),
        ],
      ),
    );
  }

  /// One shot's own row: its code, its shot size, its duration and — while already placed — its
  /// day tags, muted, with a tooltip saying so. The mark is information, never a bar: the row stays
  /// clickable either way.
  Widget _buildShotRow(BuildContext context, Tr tr, ThemeData theme, OcptShot shot) {
    final dayNumbers = widget.placedDayNumbersByShotId[shot.id];
    final isPlaced = dayNumbers != null && dayNumbers.isNotEmpty;
    final mutedStyle = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return InkWell(
      onTap: () => globalGetIt().get<OcptRouterManager>().pop<String>(shot.id),
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(shot.code, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: Text(
                shot.shotSize,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ),
            Text(ocptFormatShotDuration(shot.estimatedDurationMs), style: mutedStyle),
            if (isPlaced) ...[
              const SizedBox(width: 10),
              Tooltip(
                message: tr.scheduleShotPickerAlreadyPlacedTooltip,
                child: Text(
                  dayNumbers.map((n) => ocptScheduleDayTagLabel(tr, n)).join(", "),
                  style: mutedStyle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// A hint filling the list's own area, for either empty state (no shot at all, or a search
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

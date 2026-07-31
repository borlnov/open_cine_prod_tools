// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_layout.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_coverage_range.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_field_suggestions.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_check_reason.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_difficulty_axis.dart';
import 'package:open_cine_prod_tools/types/ocpt_shot_list_editable_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_character_chips.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_coverage_summary.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_difficulty_rating.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_inspector_field.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_status_pill.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';

/// The shot list's right dock inspector tab: every field of the selected shot, editable in place.
///
/// Purely presentational, like the screenplay editor's own `OcptEditorInspectorPanel`: the shot
/// list mode is the only caller, wiring every callback to `OcptShotListBloc` events and computing
/// [fieldValueOf] from the bloc's own pending-edit map so a field shows what was just typed while
/// its 2 s autosave debounce is still running.
///
/// Everything a shot's *scheduling* decides is deliberately absent, because the shooting schedule
/// mode is what will own it: the header's status pill is a read-out rather than a control, and the
/// Production section has no shooting day and no planned takes. The metadata tab still reads those
/// two out, once they exist.
///
/// A shot needing checking shows a `Needs checking` callout right under the header, before the
/// character chips: the localised [OcptShotCheckReason], and a `Mark as checked` button
/// ([onMarkAsChecked]). Scenario coverage is its own section, [OcptShotCoverageSummary], between
/// the character chips and the Image section: a read-only list of the extracts the shot covers,
/// the selecting itself happening in the dialog [onSelectCoverageRequested] opens.
class OcptShotInspectorPanel extends StatelessWidget {
  /// The selected shot, or null while none is (the empty state).
  final OcptShot? shot;

  /// [shot]'s sequence heading (a real scene's own heading, or an orphaned shot's
  /// `OcptShot.orphanedHeading`), shown under the header and in the Production section. Ignored
  /// while [shot] is null.
  final String sequenceHeading;

  /// [shot]'s sequence display number (a real scene's `displaySceneNumber`, or the orphan
  /// placeholder), shown in the Production section. Ignored while [shot] is null.
  final String sequenceDisplayNumber;

  /// Every character the whole screenplay names, for the characters chips.
  final List<String> screenplayCharacters;

  /// The project-wide suggestion lists for the fields that have one.
  final OcptShotFieldSuggestions suggestions;

  /// [shot]'s scene, laid out into the scenario coverage editor's blocks and words, or null for
  /// an orphaned shot (its scene's text is gone). Ignored while [shot] is null.
  final OcptShotCoverageLayout? coverageLayout;

  /// Every other shot's coverage ranges of [coverageLayout]'s scene, keyed by that shot's code.
  /// Ignored while [shot] is null.
  final Map<String, List<OcptShotCoverageRange>> otherShotsCoverageRanges;

  /// The ids of [shot]'s own coverage ranges currently disagreeing with the scene's text. Ignored
  /// while [shot] is null.
  final Set<String> staleCoverageRangeIds;

  /// [shot]'s current value for the given `field`: a pending edit still in the bloc's debounce,
  /// or the shot's own stored value, formatted for an editable field (an empty string for a
  /// missing value, never [ocptShotListEmptyValue]).
  final String Function(OcptShotListEditableField field) fieldValueOf;

  /// Called when a difficulty dot is clicked.
  final void Function(OcptShotDifficultyAxis axis, int value) onDifficultyChanged;

  /// Called with a character's name when its chip is toggled.
  final ValueChanged<String> onCharacterToggled;

  /// Called with a field's raw text on every keystroke.
  final void Function(OcptShotListEditableField field, String rawValue) onFieldChanged;

  /// Called when the coverage section's `Select…` button is clicked, to open the dialog a shot's
  /// coverage is selected in.
  final VoidCallback onSelectCoverageRequested;

  /// Called when the coverage editor's `Clear all` action is clicked.
  final VoidCallback onCoverageClearAll;

  /// Called when the `Needs checking` callout's `Mark as checked` button is clicked.
  final VoidCallback onMarkAsChecked;

  /// Called when the "Delete shot" action is clicked, or null while it should be disabled (no
  /// shot selected).
  final VoidCallback? onDeleteRequested;

  /// Class constructor
  const OcptShotInspectorPanel({
    super.key,
    required this.shot,
    required this.sequenceHeading,
    required this.sequenceDisplayNumber,
    required this.screenplayCharacters,
    required this.suggestions,
    required this.coverageLayout,
    required this.otherShotsCoverageRanges,
    required this.staleCoverageRangeIds,
    required this.fieldValueOf,
    required this.onDifficultyChanged,
    required this.onCharacterToggled,
    required this.onFieldChanged,
    required this.onSelectCoverageRequested,
    required this.onCoverageClearAll,
    required this.onMarkAsChecked,
    required this.onDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final shot = this.shot;

    if (shot == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          tr.shotListNoShotSelectedHint,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              tr.shotListInspectorHeaderTitle(shot.code),
              style: theme.textTheme.titleSmall?.copyWith(
                fontFamily: ocptMonospaceFontFamily,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            OcptShotStatusPill(status: shot.status),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          sequenceHeading,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),

        if (shot.needsCheck && shot.checkReason != null) ...[
          _OcptShotNeedsCheckCallout(reason: shot.checkReason!, onMarkAsChecked: onMarkAsChecked),
          const SizedBox(height: 16),
        ],

        _sectionTitle(context, tr.shotListInspectorCharactersSectionTitle),
        const SizedBox(height: 8),
        OcptShotCharacterChips(
          screenplayCharacters: screenplayCharacters,
          attachedCharacters: shot.characters,
          onToggled: onCharacterToggled,
        ),
        const SizedBox(height: 16),

        _sectionTitle(context, tr.shotListInspectorCoverageSectionTitle),
        const SizedBox(height: 8),
        OcptShotCoverageSummary(
          layout: coverageLayout,
          ownRanges: shot.coverageRanges,
          otherShotsRanges: otherShotsCoverageRanges,
          staleRangeIds: staleCoverageRangeIds,
          onSelectRequested: onSelectCoverageRequested,
          onClearAll: onCoverageClearAll,
        ),
        const SizedBox(height: 16),

        _sectionTitle(context, tr.shotListInspectorImageSectionTitle),
        const SizedBox(height: 8),
        OcptShotInspectorField(
          shotId: shot.id,
          label: tr.shotListColumnShotSize,
          value: fieldValueOf(OcptShotListEditableField.shotSize),
          suggestions: suggestions.shotSizes,
          onChanged: (value) => onFieldChanged(OcptShotListEditableField.shotSize, value),
        ),
        OcptShotInspectorField(
          shotId: shot.id,
          label: tr.shotListColumnFraming,
          value: fieldValueOf(OcptShotListEditableField.framing),
          suggestions: suggestions.framings,
          multiline: true,
          onChanged: (value) => onFieldChanged(OcptShotListEditableField.framing, value),
        ),
        OcptShotInspectorField(
          shotId: shot.id,
          label: tr.shotListColumnCameraMove,
          value: fieldValueOf(OcptShotListEditableField.cameraMove),
          suggestions: suggestions.cameraMoves,
          multiline: true,
          onChanged: (value) => onFieldChanged(OcptShotListEditableField.cameraMove, value),
        ),
        OcptShotInspectorField(
          shotId: shot.id,
          label: tr.shotListColumnLens,
          value: fieldValueOf(OcptShotListEditableField.lens),
          suggestions: suggestions.lenses,
          onChanged: (value) => onFieldChanged(OcptShotListEditableField.lens, value),
        ),
        OcptShotInspectorField(
          shotId: shot.id,
          label: tr.shotListColumnFormat,
          value: fieldValueOf(OcptShotListEditableField.recordingFormat),
          suggestions: suggestions.recordingFormats,
          onChanged: (value) => onFieldChanged(OcptShotListEditableField.recordingFormat, value),
        ),
        const SizedBox(height: 8),

        _sectionTitle(
          context,
          tr.shotListInspectorDifficultySectionTitle(
            ocptFormatShotDifficulty(context, shot.averageDifficulty),
          ),
        ),
        const SizedBox(height: 4),
        OcptShotDifficultyRating(
          label: tr.shotListColumnSet,
          value: shot.difficultySet,
          onChanged: (value) => onDifficultyChanged(OcptShotDifficultyAxis.set, value),
        ),
        OcptShotDifficultyRating(
          label: tr.shotListColumnCameraMove,
          value: shot.difficultyCamera,
          onChanged: (value) => onDifficultyChanged(OcptShotDifficultyAxis.camera, value),
        ),
        OcptShotDifficultyRating(
          label: tr.shotListDifficultyAxisActing,
          value: shot.difficultyActing,
          onChanged: (value) => onDifficultyChanged(OcptShotDifficultyAxis.acting, value),
        ),
        OcptShotDifficultyRating(
          label: tr.shotListColumnSound,
          value: shot.difficultySound,
          onChanged: (value) => onDifficultyChanged(OcptShotDifficultyAxis.sound, value),
        ),
        const SizedBox(height: 16),

        _sectionTitle(context, tr.shotListInspectorProductionSectionTitle),
        const SizedBox(height: 8),
        OcptShotInspectorField(
          shotId: shot.id,
          label: tr.shotListInspectorEstimatedDurationLabel,
          value: fieldValueOf(OcptShotListEditableField.estimatedDuration),
          onChanged: (value) => onFieldChanged(OcptShotListEditableField.estimatedDuration, value),
        ),
        OcptShotInspectorField(
          shotId: shot.id,
          label: tr.shotListColumnSound,
          value: fieldValueOf(OcptShotListEditableField.sound),
          suggestions: suggestions.sounds,
          multiline: true,
          onChanged: (value) => onFieldChanged(OcptShotListEditableField.sound, value),
        ),
        OcptShotInspectorReadOnlyField(
          label: tr.shotListInspectorSequenceLabel,
          value: "$sequenceDisplayNumber — $sequenceHeading",
        ),
        const SizedBox(height: 8),

        _sectionTitle(context, tr.shotListInspectorNotesSectionTitle),
        const SizedBox(height: 8),
        OcptShotInspectorField(
          shotId: shot.id,
          label: "",
          value: fieldValueOf(OcptShotListEditableField.notes),
          multiline: true,
          onChanged: (value) => onFieldChanged(OcptShotListEditableField.notes, value),
        ),
        const SizedBox(height: 8),

        _sectionTitle(context, tr.shotListInspectorLocationSectionTitle),
        const SizedBox(height: 8),
        OcptShotInspectorField(
          shotId: shot.id,
          label: "",
          value: fieldValueOf(OcptShotListEditableField.locationNotes),
          multiline: true,
          onChanged: (value) => onFieldChanged(OcptShotListEditableField.locationNotes, value),
        ),
        const SizedBox(height: 20),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onDeleteRequested,
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            child: Text(tr.shotListDeleteShotAction),
          ),
        ),
      ],
    );
  }

  /// One section title, the accent-coloured header the mock-up uses to separate the panel's
  /// sections (Image, Difficulty, Production, …).
  Widget _sectionTitle(BuildContext context, String title) => Text(
    title,
    style: Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
  );
}

/// The `Needs checking` callout shown at the top of [OcptShotInspectorPanel] whenever the selected
/// shot's `OcptShot.needsCheck` is set: [reason], localised, and a `Mark as checked` button.
/// Tinted with [ocptShotListWarningColor], the colour this mode marks everything needing
/// attention with.
class _OcptShotNeedsCheckCallout extends StatelessWidget {
  /// Why the shot needs checking.
  final OcptShotCheckReason reason;

  /// Called when the `Mark as checked` button is clicked.
  final VoidCallback onMarkAsChecked;

  /// Class constructor
  const _OcptShotNeedsCheckCallout({required this.reason, required this.onMarkAsChecked});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final color = ocptShotListWarningColor(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ocptSelectedStateAlpha),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_reasonLabel(tr), style: theme.textTheme.bodySmall?.copyWith(color: color)),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: onMarkAsChecked,
                    // Filled with the callout's own warning colour rather than the accent, so it
                    // reads as the answer to the warning it sits in; the label takes the theme's
                    // `surface` because the two warning colours are built to carry against it —
                    // near-black under the light amber of the dark theme, near-white under the
                    // darkened amber of the light one.
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: theme.colorScheme.surface,
                    ),
                    child: Text(tr.shotListNeedsCheckMarkAsCheckedAction),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The localised label of [reason].
  String _reasonLabel(Tr tr) => switch (reason) {
    OcptShotCheckReason.coveredTextChanged => tr.shotListNeedsCheckReasonCoveredTextChanged,
    OcptShotCheckReason.coverageOutOfBounds => tr.shotListNeedsCheckReasonCoverageOutOfBounds,
    OcptShotCheckReason.sceneDeleted => tr.shotListNeedsCheckReasonSceneDeleted,
  };
}

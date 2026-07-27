// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_dock_field.dart';

/// A missing value's display, shared by every field of the right dock's inspector and metadata
/// panels. A plain punctuation glyph rather than a localized string: it carries no language-
/// specific meaning.
const String _dash = '—';

/// The right dock's inspector tab: the scene under the editor caret — its heading, its explicit
/// number when it has one, its speaking characters, its estimated duration and its length in
/// page-eighths (the unit assistant directors use). Shows an empty state instead when the caret
/// precedes every scene (or nothing is parsed yet).
///
/// Purely presentational: `EditorPage` is the only caller, and it already recomputes [statistics]
/// on `OcptEditorBloc`'s parse debounce, never on every keystroke (see
/// `OcptEditorState.sceneStatistics`).
class OcptEditorInspectorPanel extends StatelessWidget {
  /// The scene under the caret, or null while there is none (the empty state).
  final FountainSceneHeading? scene;

  /// The 1-based position of [scene] among the document's scenes, shown in the panel's title. Null
  /// exactly when [scene] is.
  final int? sceneOrdinal;

  /// [scene]'s statistics, or null exactly when [scene] is.
  final FountainSceneStatistics? statistics;

  /// Class constructor
  const OcptEditorInspectorPanel({
    super.key,
    required this.scene,
    required this.sceneOrdinal,
    required this.statistics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final scene = this.scene;
    final sceneOrdinal = this.sceneOrdinal;
    final statistics = this.statistics;

    if (scene == null || sceneOrdinal == null || statistics == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          tr.editorInspectorEmptyHint,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    final sceneNumber = scene.sceneNumber;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(tr.editorInspectorSceneTitle(sceneOrdinal), style: theme.textTheme.titleSmall),
        ),
        if (sceneNumber != null)
          OcptEditorDockField(label: tr.editorInspectorNumberLabel, value: sceneNumber),
        OcptEditorDockField(label: tr.editorInspectorHeadingLabel, value: scene.headingText),
        OcptEditorDockField(
          label: tr.editorInspectorCharactersLabel,
          value: statistics.speakingCharacters.isEmpty ? _dash : statistics.speakingCharacters.join(', '),
        ),
        OcptEditorDockField(
          label: tr.editorInspectorDurationLabel,
          value: _durationText(tr, statistics.pageEighths),
        ),
        OcptEditorDockField(
          label: tr.editorInspectorLengthLabel,
          value: _pageLengthText(tr, statistics.pageEighths),
        ),
      ],
    );
  }

  /// The estimated duration of [pageEighths] worth of screenplay, on the industry rule of one page
  /// ≈ one minute, rounded to the nearest minute (never displayed as zero for a non-empty scene).
  static String _durationText(Tr tr, int pageEighths) {
    if (pageEighths <= 0) {
      return tr.editorInspectorDurationEstimate(0);
    }
    final minutes = (pageEighths / 8).round();
    return tr.editorInspectorDurationEstimate(minutes < 1 ? 1 : minutes);
  }

  /// The mixed-number page-eighths display assistant directors use: a whole page count, its
  /// eighths remainder, or both, whichever [pageEighths] actually has.
  static String _pageLengthText(Tr tr, int pageEighths) {
    final whole = pageEighths ~/ 8;
    final eighths = pageEighths % 8;

    if (eighths == 0) {
      return tr.editorInspectorPageEstimateWhole(whole);
    }
    if (whole == 0) {
      return tr.editorInspectorPageEstimateEighthsOnly(eighths);
    }
    return tr.editorInspectorPageEstimateMixed(whole, eighths);
  }
}

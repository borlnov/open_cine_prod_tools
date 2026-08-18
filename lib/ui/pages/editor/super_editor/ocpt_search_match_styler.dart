// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search.dart';
import 'package:open_cine_prod_tools/utils/ocpt_text_search.dart';
import 'package:super_editor/super_editor.dart';

/// The attribution [OcptSearchMatchStyler] adds over every find/replace match's own range, painted
/// as [ocptEditorSearchMatchColor] by the styler's wrapped `textStyleBuilder`.
///
/// Never written to the live document — see [OcptSearchMatchStyler]'s own doc comment — so this
/// only ever exists on the throwaway `AttributedText` copy a style pass builds, and is never
/// encoded back to Fountain source.
const NamedAttribution ocptSearchMatchAttribution = NamedAttribution("ocptSearchMatch");

/// The stronger variant of [ocptSearchMatchAttribution] marking the *current* match, painted as
/// [ocptEditorSearchCurrentMatchColor].
const NamedAttribution ocptSearchCurrentMatchAttribution = NamedAttribution("ocptSearchCurrentMatch");

/// The styled mode's own half of the find/replace bar's highlight (the plan's M4 decision, §6):
/// raw mode paints its matches by overriding `TextEditingController.buildTextSpan`
/// (`OcptEditorSearchTextController`); the styled block editor has no such single field to
/// override, so this is a `SingleColumnLayoutStylePhase` handed to `SuperEditor`'s
/// `customStylePhases` instead, which run after the stylesheet phase (see `SuperEditor`'s own doc
/// comment on that parameter).
///
/// [updateMatches] is `OcptStyledScreenplayEditor`'s only way to feed this styler the current
/// matches, keyed by node id (a node's own display text is what its matches are computed
/// against — see `OcptEditorSearchQuery.matchesIn`'s own doc comment on why the raw and styled
/// counts can legitimately differ). [style] then, for every node carrying at least one match:
///
/// 1. copies the node's `SingleColumnLayoutComponentViewModel` (`previousViewModel.copy()`, which
///    deep-copies the underlying `AttributedText` — verified against the pinned `0.3.0-dev.52`,
///    see `TextComponentViewModel.internalCopy`), so nothing here ever touches the live document
///    or the node it belongs to;
/// 2. adds [ocptSearchMatchAttribution] (or [ocptSearchCurrentMatchAttribution] for the current
///    match) over that copy's text, at each match's own range;
/// 3. wraps the copy's existing `textStyleBuilder` so a run carrying either attribution resolves
///    to the matching background colour, leaving every other attribution — bold, italic, the
///    authoring-note dim, all of it — to resolve through the previous builder exactly as before.
///
/// `markDirty()` (inherited from `SingleColumnLayoutStylePhase`) is what makes a re-style actually
/// happen once [updateMatches] changes what's held; a plain field write wouldn't reach the
/// presenter pipeline on its own.
class OcptSearchMatchStyler extends SingleColumnLayoutStylePhase {
  /// The matches currently painted, keyed by the id of the node they were found in.
  Map<String, List<OcptTextMatch>> _matchesByNodeId = const {};

  /// The id of the node holding the current match, or null while there is none.
  String? _currentMatchNodeId;

  /// The current match itself (only meaningful together with [_currentMatchNodeId], since two
  /// different nodes can hold an equal `OcptTextMatch` by pure coincidence of offsets).
  OcptTextMatch? _currentMatch;

  /// Replaces the matches this styler paints and marks the phase dirty so `SuperEditor`
  /// re-runs it — unconditionally: `OcptStyledScreenplayEditor` only calls this when it has
  /// something new to report (a fresh recompute after an edit, or an explicit navigation), so
  /// there is no stale-call case worth guarding against here.
  void updateMatches({
    required Map<String, List<OcptTextMatch>> matchesByNodeId,
    required String? currentMatchNodeId,
    required OcptTextMatch? currentMatch,
  }) {
    _matchesByNodeId = matchesByNodeId;
    _currentMatchNodeId = currentMatchNodeId;
    _currentMatch = currentMatch;
    markDirty();
  }

  /// Styles [viewModel] by replacing every component that carries at least one match with a
  /// highlighted copy, through [_applyMatches]; every other component is left untouched (not even
  /// copied), matching `SpellingAndGrammarStyler`'s own pattern.
  @override
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel) {
    if (_matchesByNodeId.isEmpty) {
      return viewModel;
    }

    return SingleColumnLayoutViewModel(
      padding: viewModel.padding,
      componentViewModels: [
        for (final previousViewModel in viewModel.componentViewModels) _applyMatches(previousViewModel),
      ],
    );
  }

  /// Returns [previousViewModel] unchanged when it carries no match or isn't a text component
  /// (e.g. the title page's own field components, which do mix in [TextComponentViewModel], are
  /// still handled the same way as every other text block); otherwise returns a highlighted copy.
  SingleColumnLayoutComponentViewModel _applyMatches(SingleColumnLayoutComponentViewModel previousViewModel) {
    final matches = _matchesByNodeId[previousViewModel.nodeId];
    if (matches == null || matches.isEmpty || previousViewModel is! TextComponentViewModel) {
      return previousViewModel;
    }

    final copiedViewModel = previousViewModel.copy();
    if (copiedViewModel is! TextComponentViewModel) {
      // Defensive: every concrete view model mixing in `TextComponentViewModel` also implements
      // it on its own `copy()` return value, so this never actually happens against the pinned
      // super_editor version — but returning the (already deep-copied) instance is still strictly
      // safer than returning `previousViewModel` here, which `style()`'s caller would otherwise
      // hand straight back into the live pipeline.
      return copiedViewModel;
    }

    final isCurrentNode = previousViewModel.nodeId == _currentMatchNodeId;
    final text = copiedViewModel.text;
    for (final match in matches) {
      if (match.start >= match.end || match.end > text.toPlainText().length) {
        // Defensive, mirrors `OcptEditorSearchTextController`'s own clamp: a match computed
        // against a text version that has since changed underneath it must never reach
        // `AttributedText.addAttribution` with an out-of-range span.
        continue;
      }

      final isCurrent = isCurrentNode && match == _currentMatch;
      text.addAttribution(
        isCurrent ? ocptSearchCurrentMatchAttribution : ocptSearchMatchAttribution,
        SpanRange(match.start, match.end - 1),
      );
    }

    final previousBuilder = copiedViewModel.textStyleBuilder;
    copiedViewModel.textStyleBuilder = (attributions) {
      final style = previousBuilder(attributions);
      if (attributions.contains(ocptSearchCurrentMatchAttribution)) {
        return style.copyWith(backgroundColor: ocptEditorSearchCurrentMatchColor);
      }
      if (attributions.contains(ocptSearchMatchAttribution)) {
        return style.copyWith(backgroundColor: ocptEditorSearchMatchColor);
      }
      return style;
    };

    return copiedViewModel;
  }
}

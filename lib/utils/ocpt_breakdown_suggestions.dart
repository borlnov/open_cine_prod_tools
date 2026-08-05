// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:equatable/equatable.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/utils/ocpt_resources_search.dart';

/// A passage that reads like one of a target's own tags but is not tagged itself — what
/// [ocptBreakdownSuggestionsOf] offers, and what the caller needs to both show the row and write
/// the tag if the offer is accepted (§3.4 of the plan this ships under: a repeated occurrence is
/// offered, never applied).
class OcptBreakdownSuggestion extends Equatable {
  /// The kind of the target this passage is suggested for.
  final OcptBreakdownTargetKind targetKind;

  /// The id of the target this passage is suggested for.
  final String targetId;

  /// The id of the scene this passage falls in.
  final String sceneId;

  /// The scene-relative offset, exactly as `OcptBreakdownTag.startOffset` is, at which this
  /// passage starts.
  final int startOffset;

  /// The scene-relative offset, exactly as `OcptBreakdownTag.endOffset` is, one past this
  /// passage's last character.
  final int endOffset;

  /// This passage, sliced verbatim out of the scene's own text — never the folded text
  /// [ocptBreakdownSuggestionsOf] matches on — what an accepted suggestion writes as the new tag's
  /// own `taggedText`.
  final String text;

  /// Class constructor
  const OcptBreakdownSuggestion({
    required this.targetKind,
    required this.targetId,
    required this.sceneId,
    required this.startOffset,
    required this.endOffset,
    required this.text,
  });

  /// Object properties
  @override
  List<Object?> get props => [targetKind, targetId, sceneId, startOffset, endOffset, text];
}

/// A character that counts as a letter or a digit for [ocptBreakdownSuggestionsOf]'s own purposes:
/// whether a tag is worth searching for at all (a tag made only of punctuation would match nearly
/// everywhere), and where a match's word boundary falls. Built with `unicode: true` so the
/// property classes `\p{L}`/`\p{N}` resolve for the accented Latin letters `en_GB`/`fr` need, not
/// just plain ASCII.
final RegExp _letterOrDigit = RegExp(r"[\p{L}\p{N}]", unicode: true);

/// A scene's own text, folded through [ocptResourcesSearchFoldedRune] one rune at a time, together
/// with the map back from every folded index to the original offset it came from — what lets
/// [ocptBreakdownSuggestionsOf] search the folded text (so an accented or differently-cased
/// occurrence is still found) while still reporting offsets into the real, unfolded scene text.
class _OcptFoldedSceneText {
  /// The scene's own text, folded rune by rune.
  final String folded;

  /// `foldedToOriginalOffset[i]` is the offset, in the original scene text, that [folded]'s own
  /// character at index `i` came from. One entry longer than [folded] itself, its last entry
  /// holding the original text's own length, so a match ending at the very end of the folded text
  /// still maps to a valid original offset.
  final List<int> foldedToOriginalOffset;

  /// Class constructor
  const _OcptFoldedSceneText({required this.folded, required this.foldedToOriginalOffset});

  /// Folds [sceneText] rune by rune, building the index map alongside it.
  factory _OcptFoldedSceneText.of(String sceneText) {
    final foldedBuffer = StringBuffer();
    final foldedToOriginalOffset = <int>[];

    var originalOffset = 0;
    for (final rune in sceneText.runes) {
      final originalRuneLength = String.fromCharCode(rune).length;
      final foldedRune = ocptResourcesSearchFoldedRune(rune);

      foldedBuffer.write(foldedRune);
      for (var i = 0; i < foldedRune.length; i++) {
        foldedToOriginalOffset.add(originalOffset);
      }

      originalOffset += originalRuneLength;
    }
    // The sentinel a match ending at the very end of the folded text maps through.
    foldedToOriginalOffset.add(originalOffset);

    return _OcptFoldedSceneText(
      folded: foldedBuffer.toString(),
      foldedToOriginalOffset: foldedToOriginalOffset,
    );
  }
}

/// Every passage of [scenes] that reads like one of its own live tags' `taggedText` and is not
/// itself tagged — what the target inspector's own "Suggested occurrences" section offers, one
/// entry per (target, scene, range), the user confirming each one before it becomes a tag of its
/// own (§3.4/§5.4 of the plan this ships under: a repeated occurrence is offered, never applied).
///
/// For every live tag of every scene whose `taggedText` holds at least one letter or digit (a tag
/// made only of punctuation is skipped: matching it would mean nearly everywhere), every scene of
/// [scenes] — including the tag's own — is searched for it, diacritic- and case-folded through
/// [ocptResourcesSearchFoldedRune] (the same fold [ocptResourcesSearchNormalized] uses, reused
/// rather than re-implemented) and bounded to whole words: a match may not be preceded or followed,
/// on the **folded** text, by a letter or a digit, so `clé` does not match inside `clés`. A match
/// that overlaps any live tag of its own scene — the searched tag's own passage among them — is
/// dropped: it is already tagged, or tagged as something else.
///
/// Folding is done once per scene, through [_OcptFoldedSceneText], and reused for every tag's own
/// search of it — an accented or multi-character fold (`œ` folding to `oe`) still yields offsets
/// that address the original scene text correctly, because [_OcptFoldedSceneText] tracks exactly
/// which original offset each folded character came from.
///
/// Results are deduplicated by (target, scene, range): two tags of the same target sharing the same
/// `taggedText` must not offer the same passage twice. Ordered by scene position (the order
/// [scenes] itself is given in — `OcptBreakdownScene`'s own doc comment says it is source order),
/// then by offset within the scene.
///
/// [OcptBreakdownScene.charStart]/[OcptBreakdownScene.charEnd] are clamped against
/// [screenplayText]'s own length before slicing, rather than risking a `RangeError`, mirroring
/// `OcptBreakdownBloc._onWordClicked`'s own guard.
List<OcptBreakdownSuggestion> ocptBreakdownSuggestionsOf({
  required List<OcptBreakdownScene> scenes,
  required String screenplayText,
}) {
  final liveTags = [for (final scene in scenes) ...scene.tags];
  if (liveTags.isEmpty) {
    return const [];
  }

  final suggestions = <OcptBreakdownSuggestion>[];

  for (final scene in scenes) {
    final sceneText = _sceneTextOf(scene, screenplayText);
    final foldedScene = _OcptFoldedSceneText.of(sceneText);

    final sceneSuggestions = <OcptBreakdownSuggestion>[];
    final seenRanges = <(OcptBreakdownTargetKind, String, int, int)>{};

    for (final tag in liveTags) {
      if (!_letterOrDigit.hasMatch(tag.taggedText)) {
        continue;
      }
      final needle = ocptResourcesSearchNormalized(tag.taggedText);
      if (needle.isEmpty) {
        continue;
      }

      var searchStart = 0;
      while (true) {
        final foldedStart = foldedScene.folded.indexOf(needle, searchStart);
        if (foldedStart == -1) {
          break;
        }
        final foldedEnd = foldedStart + needle.length;
        searchStart = foldedStart + 1;

        if (!_isWholeWordMatch(foldedScene.folded, foldedStart, foldedEnd)) {
          continue;
        }

        final startOffset = foldedScene.foldedToOriginalOffset[foldedStart];
        final endOffset = foldedScene.foldedToOriginalOffset[foldedEnd];

        final overlapsLiveTag = scene.tags.any(
          (liveTag) => startOffset < liveTag.endOffset && liveTag.startOffset < endOffset,
        );
        if (overlapsLiveTag) {
          continue;
        }

        final rangeKey = (tag.targetKind, tag.targetId, startOffset, endOffset);
        if (!seenRanges.add(rangeKey)) {
          continue;
        }

        sceneSuggestions.add(
          OcptBreakdownSuggestion(
            targetKind: tag.targetKind,
            targetId: tag.targetId,
            sceneId: scene.id,
            startOffset: startOffset,
            endOffset: endOffset,
            text: sceneText.substring(startOffset, endOffset),
          ),
        );
      }
    }

    sceneSuggestions.sort((a, b) => a.startOffset.compareTo(b.startOffset));
    suggestions.addAll(sceneSuggestions);
  }

  return suggestions;
}

/// [scene]'s own slice of [screenplayText], its `charStart`/`charEnd` clamped to
/// [screenplayText]'s own length first so a scene whose offsets no longer fit it (a stale read
/// racing an edit) is truncated rather than crashing the search.
String _sceneTextOf(OcptBreakdownScene scene, String screenplayText) {
  final start = scene.charStart.clamp(0, screenplayText.length);
  final end = scene.charEnd.clamp(start, screenplayText.length);
  return screenplayText.substring(start, end);
}

/// Whether the match `[start, end)` of [folded] is bounded by whole words: neither the character
/// right before [start] nor the one right at [end] may be a letter or a digit, checked with
/// [_letterOrDigit] against the **folded** text — a folded letter still folds to a letter.
bool _isWholeWordMatch(String folded, int start, int end) {
  if (start > 0 && _letterOrDigit.hasMatch(folded[start - 1])) {
    return false;
  }
  if (end < folded.length && _letterOrDigit.hasMatch(folded[end])) {
    return false;
  }

  return true;
}

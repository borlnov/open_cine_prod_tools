// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_scene_numbers.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';

/// Settle a styled editor's document after an edit, the pass its text sync and its flush both
/// need before the text can safely be encoded.
final class OcptStyledDocumentSettle {
  /// Private constructor: this class only exposes static members.
  const OcptStyledDocumentSettle._();

  /// Bring every node of [document] (executed through [editor]) to the same settled state
  /// `_syncAfterEdit` and `_flushPendingSync` both need before their text can be safely encoded:
  /// live `#N#` tags absorbed, every `blockType` reclassified from current text, note/uppercase
  /// spans refreshed, and scene numbers renumbered — in that order, each its own `execute` call so
  /// every later pass only ever sees the previous one's already-settled result.
  static void settle(MutableDocument document, Editor editor) {
    // The document laid out as lines of plain text, once for every pass that reads it: only a
    // pass that changes a node's text makes it stale, and it is laid out again after that one.
    var layout = OcptWysiwygCodec.layoutOf(document);
    // A node an input method is composing in is left alone by every pass that rewrites a text:
    // the composing region indexes that text, and the pass acts at the first settle after the
    // composition ends.
    final composingNodeIds = _composingNodeIds(editor);

    // The notes come first, in an `execute` of their own, since they rewrite the texts the passes
    // after them read and address: a note typed as text is absorbed into a placeholder, and one
    // that no longer is a note goes back to text. Only then do the other passes see the offsets
    // the nodes now have.
    final noteRequests = OcptWysiwygCodec.noteRequests(
      document,
      documentLayout: layout,
      composingNodeIds: composingNodeIds,
    );
    if (noteRequests.isNotEmpty) {
      editor.execute(noteRequests);
      layout = OcptWysiwygCodec.layoutOf(document);
    }

    // Run before every other pass and in its own `execute` call: a `#N#`
    // tag typed live still sits in the node's plain text at this point, and both this pass and
    // `uppercaseRequests` would otherwise compute their replacement text from that same pre-strip
    // snapshot, so whichever request executed last would silently undo the other's effect on the
    // same node.
    final sceneNumberRequests = OcptWysiwygCodec.sceneNumberRequests(
      document,
      documentLayout: layout,
      composingNodeIds: composingNodeIds,
    );
    // The dual-dialogue `^` typed at the end of a cue is absorbed in the same pass, for the same
    // reason: both read the pre-strip text, and touch nodes of different types.
    final tagRequests = [
      ...sceneNumberRequests,
      ...OcptWysiwygDualDialogue.requests(
        document,
        documentLayout: layout,
        composingNodeIds: composingNodeIds,
      ),
    ];
    if (tagRequests.isNotEmpty) {
      editor.execute(tagRequests);
      layout = OcptWysiwygCodec.layoutOf(document);
    }

    // Reclassifies every node's `blockType` (and refreshes note attributions/uppercasing) BEFORE
    // scene numbers are counted or the text is reported upstream: a node whose type just changed
    // as a side effect of this same edit (e.g. an Enter split leaving a fragment that no longer
    // reads as a scene heading) must never be counted as a scene, or reported in the encoded text
    // as one, even for the single tick before the next debounce would otherwise have caught it —
    // and, critically, must never be encoded under its stale type either: `FountainLineWriter`
    // would then have no choice but to bake a literal forcing-marker character into the output for
    // a node whose stored type doesn't match its own text, and that character comes back on the
    // very next decode as a genuine, sticky, user-typed forcing marker.
    final requests = [
      ...OcptWysiwygCodec.reclassifyRequests(document, documentLayout: layout),
      ...OcptWysiwygCodec.noteAttributionRequests(document),
      ...OcptWysiwygCodec.commentAttributionRequests(document, documentLayout: layout),
      ...OcptWysiwygCodec.uppercaseRequests(
        document,
        documentLayout: layout,
        composingNodeIds: composingNodeIds,
      ),
    ];
    if (requests.isNotEmpty) {
      editor.execute(requests);
    }

    // Renumbers every scene heading (see `sceneNumberNormalizationRequests`'s own doc comment),
    // in its own `execute` call so it always runs against final, already-reclassified block types:
    // inserting, deleting or retyping a heading anywhere can shift every number after it, not just
    // the one being edited.
    final normalizationRequests = sceneNumberNormalizationRequests(
      document,
      documentLayout: layout,
    );
    // A cue just reclassified as anything else drops its dual-dialogue marker.
    final dualDialogueRequests = OcptWysiwygDualDialogue.requests(
      document,
      documentLayout: layout,
      composingNodeIds: composingNodeIds,
    );
    final finalRequests = [...normalizationRequests, ...dualDialogueRequests];
    if (finalRequests.isNotEmpty) {
      editor.execute(finalRequests);
    }
  }

  /// Get the ids of the nodes holding the composing region of [editor]'s composer, empty when no
  /// composition is in progress.
  static Set<String> _composingNodeIds(Editor editor) {
    final composer = editor.context.findMaybe<MutableDocumentComposer>(Editor.composerKey);
    final region = composer?.composingRegion.value;
    return region == null ? const {} : {region.start.nodeId, region.end.nodeId};
  }
}

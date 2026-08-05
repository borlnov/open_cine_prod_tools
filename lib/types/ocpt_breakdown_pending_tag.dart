// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The first word clicked of a script-view range not yet closed: `OcptBreakdownState`'s own
/// anchor, and the script view's cue to mark that word as pending.
///
/// A tag belongs to one scene, whose `startOffset`/`endOffset` are relative to it — so `sceneId`
/// is what tells a second click in another scene to replace the anchor outright rather than close
/// a range spanning two scenes (see `OcptBreakdownBloc`'s own word-click handler).
typedef OcptBreakdownPendingTagAnchor = ({
  String sceneId,
  int wordStartOffset,
  int wordEndOffset,
});

/// A range just closed by a second click, scene-relative, awaiting the popover's own answer:
/// linking it to an existing target, creating an element for it, or being cancelled outright.
///
/// `startOffset`/`endOffset` are the merged, order-insensitive span the tag would be written
/// with — what `OcptBreakdownService.createTag`/`createElementAndTag` take — while
/// `closingWordStartOffset`/`closingWordEndOffset` are the *exact* offsets of the word the second
/// click actually landed on, which may differ from `startOffset`/`endOffset` when that click fell
/// before the anchor: the popover always anchors under that word, not under wherever the merged
/// range happens to start.
typedef OcptBreakdownPendingTagRange = ({
  String sceneId,
  int startOffset,
  int endOffset,
  String taggedText,
  int closingWordStartOffset,
  int closingWordEndOffset,
});

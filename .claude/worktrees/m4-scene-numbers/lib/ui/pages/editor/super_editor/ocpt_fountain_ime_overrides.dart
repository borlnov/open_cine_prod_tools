// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

/// Wired as `SuperEditor.imeOverrides`: intercepts a plain-Tab keystroke before it reaches
/// super_editor's own document IME client, and calls [onTabPressed] instead of letting it insert a
/// literal tab character.
///
/// **Why this is needed.** On desktop, `SuperEditor` always runs on [TextInputSource.ime]. Unlike
/// Shift+Tab — which the OS keyboard layer delivers to Flutter as a hardware `KeyEvent`, reaching
/// this app's `ocptTabToCycleBlockType` normally — a *plain* Tab (U+0009) is committed by the
/// platform IME before Flutter ever synthesizes a hardware event for it: it instead arrives as a
/// [TextEditingDeltaInsertion] whose `textInserted` is exactly `"\t"`, delivered through the IME
/// delta channel super_editor's `DocumentImeInputClient` normally applies straight to the document.
/// `SuperEditorImeInteractorState._configureImeClientDecorators` wires `imeOverrides` (when
/// non-null) as the real `TextInputConnection` client and points super_editor's own document IME
/// client behind it — so this decorator, and only this decorator, sees every delta before
/// super_editor does, and can swallow the plain-Tab one instead of forwarding it.
///
/// **Why the match is this narrow.** [_isPureTabInsertion] only matches a delta list of exactly one
/// [TextEditingDeltaInsertion] whose entire inserted text is the single character `"\t"`. Regular
/// typing — including composed/dead-key sequences for accented French input (`é`, `à`, `ê`...) —
/// never produces that exact shape: a dead-key composition arrives as its own
/// [TextEditingDeltaReplacement]/[TextEditingDeltaNonTextUpdate] deltas as the platform revises the
/// composing region, and even an ordinary single-character insertion always inserts a *different*
/// character. A real tab pasted as part of a longer string doesn't match either, since it wouldn't
/// be the delta's entire inserted text on its own. This keeps the interception limited to exactly
/// the one gesture it exists for.
class OcptFountainTabInterceptor extends DeltaTextInputClientDecorator {
  /// Class constructor.
  OcptFountainTabInterceptor({required this.onTabPressed});

  /// Called, instead of forwarding the delta, whenever a pure `"\t"` insertion is intercepted.
  final VoidCallback onTabPressed;

  /// Forwards every delta list to super_editor's own document IME client unchanged, except a pure
  /// `"\t"` insertion (see [_isPureTabInsertion]), which triggers [onTabPressed] and is never
  /// forwarded.
  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    if (_isPureTabInsertion(textEditingDeltas)) {
      onTabPressed();
      return;
    }

    super.updateEditingValueWithDeltas(textEditingDeltas);
  }

  /// Whether [deltas] is exactly one [TextEditingDeltaInsertion] whose entire
  /// [TextEditingDeltaInsertion.textInserted] is the single character `"\t"`.
  bool _isPureTabInsertion(List<TextEditingDelta> deltas) {
    if (deltas.length != 1) {
      return false;
    }

    final delta = deltas.single;
    return delta is TextEditingDeltaInsertion && delta.textInserted == '\t';
  }
}

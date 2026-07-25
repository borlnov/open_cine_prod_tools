// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_inline_style.dart';

/// Internal wiring contract between [OcptStyledEditorController] and whichever widget state
/// currently owns a live styled editor: **not** a public extension point, just the interface that
/// lets the controller live in this page-level file (no `package:super_editor` import) while the
/// widget state that actually knows how to apply a change lives in the `super_editor/` directory.
///
/// Dart's privacy is per-file, so this can't be a leading-underscore name if the implementing
/// class lives in a different file; only [OcptStyledEditorController] is meant to call these
/// methods, and only the styled editor's own state is meant to implement them.
abstract class OcptStyledEditorControllerDelegate {
  /// Applies a manual block-type change (dropdown selection) to the currently selected block.
  void applyBlockType(FountainLineType type);

  /// Toggles [style] on the current selection (or the composer's pending style, if collapsed).
  void applyToggleInlineStyle(OcptInlineStyle style);
}

/// The app-level bridge between the editor toolbar and the live styled screenplay editor: the
/// toolbar only ever talks to this controller (read the caret's block type / active inline
/// styles, request a block-type change or an inline-style toggle), never to `package:super_editor`
/// directly, which keeps the toolbar widget engine-agnostic.
///
/// A single instance is owned by the editor page and handed to both the toolbar and the styled
/// editor widget. It is [isAttached] only while a live styled editor exists to
/// [attach]/[updateReadState] it — in particular, never while the editor is in raw mode — which is
/// what lets the toolbar hide its format controls exactly when there is nothing to apply them to.
class OcptStyledEditorController extends ChangeNotifier {
  /// The delegate currently attached (the styled editor's own state), or null while detached (raw
  /// mode, or before the very first attach).
  OcptStyledEditorControllerDelegate? _delegate;

  /// The block type of the caret's current node, mirrored from the live styled editor by
  /// [updateReadState].
  FountainLineType _currentBlockType = FountainLineType.action;

  /// The inline styles active at the caret (or across the whole selection), mirrored from the live
  /// styled editor by [updateReadState].
  Set<OcptInlineStyle> _activeInlineStyles = const {};

  /// Whether [dispose] was already called, checked by a pending [_notifySafely] deferral before it
  /// finally calls `notifyListeners()`: a post-frame callback can otherwise easily outlive this
  /// controller (for example in a widget test that tears its tree down, disposing this controller,
  /// before the next frame that would have run the callback ever gets pumped), and
  /// `ChangeNotifier.notifyListeners()` asserts when called after [dispose].
  bool _disposed = false;

  /// Whether a live styled editor is currently attached; false in raw mode.
  bool get isAttached => _delegate != null;

  /// The block type the toolbar's dropdown should currently show.
  FountainLineType get currentBlockType => _currentBlockType;

  /// The inline styles the toolbar's B/I/U toggles should currently show as selected.
  Set<OcptInlineStyle> get activeInlineStyles => _activeInlineStyles;

  /// Requests that the caret's current block become [type], forwarded to the attached delegate; a
  /// no-op while detached (raw mode).
  void setBlockType(FountainLineType type) {
    _delegate?.applyBlockType(type);
  }

  /// Requests that [style] be toggled on the current selection, forwarded to the attached
  /// delegate; a no-op while detached (raw mode).
  void toggleInlineStyle(OcptInlineStyle style) {
    _delegate?.applyToggleInlineStyle(style);
  }

  /// Attaches [delegate] as the live styled editor backing this controller, making [isAttached]
  /// true and letting the toolbar's format controls appear.
  void attach(OcptStyledEditorControllerDelegate delegate) {
    _delegate = delegate;
    _notifySafely();
  }

  /// Detaches [delegate], making [isAttached] false again (the toolbar's format controls hide) —
  /// a no-op if [delegate] isn't the currently attached one, guarding against a stale detach call
  /// after a rebuild already swapped in a different delegate.
  void detach(OcptStyledEditorControllerDelegate delegate) {
    if (!identical(_delegate, delegate)) {
      return;
    }
    _delegate = null;
    _notifySafely();
  }

  /// Pushes a fresh read-side snapshot from the attached delegate: the caret's current block type
  /// and the set of inline styles active at the caret/selection. Listeners are only notified when
  /// [currentBlockType] or [activeInlineStyles] actually changed, avoiding redundant toolbar
  /// rebuilds on every keystroke that doesn't move the caret across a style boundary.
  void updateReadState({
    required FountainLineType currentBlockType,
    required Set<OcptInlineStyle> activeInlineStyles,
  }) {
    if (_currentBlockType == currentBlockType && setEquals(_activeInlineStyles, activeInlineStyles)) {
      return;
    }
    _currentBlockType = currentBlockType;
    _activeInlineStyles = activeInlineStyles;
    _notifySafely();
  }

  /// Notifies listeners immediately, unless the framework is currently in the middle of building
  /// the widget tree, in which case the notification is deferred to right after the current frame.
  ///
  /// [attach]/[detach]/[updateReadState] can all be triggered from the styled editor's
  /// `initState`/`didUpdateWidget`/`dispose`, which run synchronously as part of an ancestor's own
  /// build (for example, right after a mode toggle mounts the styled editor for the first time, in
  /// the very same frame the toolbar's `ListenableBuilder` for this same controller already
  /// rebuilt, earlier in that frame, showing the still-detached state). Calling
  /// `notifyListeners()` straight away in that situation reaches back into that already-built
  /// listener and trips Flutter's "setState()/markNeedsBuild() called during build" guard;
  /// deferring it there keeps every notification safely outside any build phase, at the cost of a
  /// harmless single-frame delay. Every other caller of [attach]/[detach]/[updateReadState] (user
  /// interaction callbacks: a keyboard shortcut, a toolbar button press) runs outside a build
  /// phase already, so it notifies immediately, with no delay at all.
  void _notifySafely() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) {
          notifyListeners();
        }
      });
    } else {
      notifyListeners();
    }
  }

  /// Marks this controller disposed (see [_disposed]) before the inherited `ChangeNotifier`
  /// teardown, so a [_notifySafely] deferral still pending at that point knows not to call
  /// `notifyListeners()` once it finally runs.
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

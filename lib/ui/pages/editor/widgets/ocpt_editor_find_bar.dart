// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The editor's find/replace bar: a docked band at the top of the centre column only (never over
/// the docks), under the workspace toolbar, pushing the editing surface down.
///
/// Two stacked rows, the second one foldable by the leading chevron: find (query, the match-case
/// and whole-word toggles inside the field's own `suffixIcon`, the `n / total` counter,
/// previous/next, close) always shown, replace (the replacement field, `Replace`, `Replace all`)
/// only while [isReplaceRowOpen]. Every decision is reported out through a callback — this widget
/// knows nothing about the bloc it is wired to, or about which editing mode is mounted behind it.
///
/// No radius, no padding, no font size of its own beyond plain layout spacing: every `TextField`
/// and `IconButton` inherits the studio look whole from `lib/constants/ocpt_theme.dart`'s component
/// themes. The match-case/whole-word toggles are the one exception, `Aa`/`ab` glyphs rather than
/// `Icon`s — the Material icon set this app draws from has no dedicated symbol for either — reusing
/// `IconButtonThemeData`'s own selected/unselected colours by hand, since a `Text` child isn't
/// resolved by the `IconTheme` an `IconButton` wraps an `Icon` child in.
class OcptEditorFindBar extends StatefulWidget {
  /// The find field's current authoritative value.
  final String query;

  /// The replace field's current authoritative value.
  final String replacement;

  /// Whether the search is case-sensitive (the `Aa` toggle's selected state).
  final bool isCaseSensitive;

  /// Whether the search only matches whole words (the `ab` toggle's selected state).
  final bool isWholeWord;

  /// Whether the replace row is unfolded.
  final bool isReplaceRowOpen;

  /// The current match count, driving the counter and enabling/disabling the previous/next/replace
  /// controls.
  final int matchCount;

  /// The 0-based index, among [matchCount] matches, of the current one; null while there is none.
  final int? currentMatchIndex;

  /// Bumped every time the find field must be (re)focused and its content selected, even when
  /// [OcptEditorFindBar] itself doesn't get rebuilt with a different [key] — the same idiom
  /// `OcptEditorJumpRequest.id` uses.
  final int focusRequestId;

  /// Called with the find field's raw text on every keystroke.
  final ValueChanged<String> onQueryChanged;

  /// Called with the replace field's raw text on every keystroke.
  final ValueChanged<String> onReplacementChanged;

  /// Called when the `Aa` toggle is pressed.
  final VoidCallback onCaseSensitivityToggled;

  /// Called when the `ab` toggle is pressed.
  final VoidCallback onWholeWordToggled;

  /// Called when the `›` button is pressed.
  final VoidCallback onNextRequested;

  /// Called when the `‹` button is pressed.
  final VoidCallback onPreviousRequested;

  /// Called when the leading chevron is pressed.
  final VoidCallback onReplaceRowToggled;

  /// Called when the `Replace` button is pressed, or null while the mounted editing surface offers
  /// no way to act on a replace yet — withheld (the button disabled) rather than acted on, exactly
  /// like every other affordance that writes and finds itself with nothing to write to.
  final VoidCallback? onReplaceRequested;

  /// Called when the `Replace all` button is pressed, or null for the same reason
  /// [onReplaceRequested] can be.
  final VoidCallback? onReplaceAllRequested;

  /// Called when the `×` button is pressed.
  final VoidCallback onCloseRequested;

  /// Class constructor
  const OcptEditorFindBar({
    super.key,
    required this.query,
    required this.replacement,
    required this.isCaseSensitive,
    required this.isWholeWord,
    required this.isReplaceRowOpen,
    required this.matchCount,
    required this.currentMatchIndex,
    required this.focusRequestId,
    required this.onQueryChanged,
    required this.onReplacementChanged,
    required this.onCaseSensitivityToggled,
    required this.onWholeWordToggled,
    required this.onNextRequested,
    required this.onPreviousRequested,
    required this.onReplaceRowToggled,
    required this.onReplaceRequested,
    required this.onReplaceAllRequested,
    required this.onCloseRequested,
  });

  @override
  State<OcptEditorFindBar> createState() => _OcptEditorFindBarState();
}

/// The state of [OcptEditorFindBar]: owns the two text controllers and the find field's own
/// [FocusNode].
class _OcptEditorFindBarState extends State<OcptEditorFindBar> {
  /// The width of row 1's own leading chevron (`iconButtonTheme`'s 28 px minimum tap target) plus
  /// its 18 px search icon and the 6 px gap after it — the space row 2's leading icon must clear so
  /// the replace field lines up under the find field above it.
  static const double _leadingRowWidth = 28 + 18 + 6;

  /// The find field's own controller, seeded from the widget's initial value and kept in sync with
  /// it afterward — the same idiom `OcptResourcesSearchField` already uses for its one field.
  late final TextEditingController _findController = TextEditingController(text: widget.query);

  /// The replace field's own controller, kept in sync the same way [_findController] is.
  late final TextEditingController _replaceController = TextEditingController(
    text: widget.replacement,
  );

  /// The find field's own focus node, (re)focused whenever [OcptEditorFindBar.focusRequestId]
  /// bumps.
  final FocusNode _findFocusNode = FocusNode();

  /// The last [OcptEditorFindBar.focusRequestId] applied, so a request is only applied once.
  int? _lastAppliedFocusRequestId;

  @override
  void initState() {
    super.initState();
    _applyFocusRequestIfNeeded();
  }

  @override
  void didUpdateWidget(covariant OcptEditorFindBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.query != _findController.text) {
      _findController.text = widget.query;
    }
    if (widget.replacement != _replaceController.text) {
      _replaceController.text = widget.replacement;
    }
    _applyFocusRequestIfNeeded();
  }

  /// Focuses [_findFocusNode] and selects the find field's whole content, once, the frame after
  /// [OcptEditorFindBar.focusRequestId] changes to a value not yet applied.
  void _applyFocusRequestIfNeeded() {
    if (widget.focusRequestId == _lastAppliedFocusRequestId) {
      return;
    }
    _lastAppliedFocusRequestId = widget.focusRequestId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _findFocusNode.requestFocus();
      _findController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _findController.text.length,
      );
    });
  }

  @override
  void dispose() {
    _findController.dispose();
    _replaceController.dispose();
    _findFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final hasMatches = widget.matchCount > 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  // The VS Code idiom (a disclosure chevron, not an up/down arrow): previous/next
                  // already use `keyboard_arrow_up`/`_down` further along this same row, and this
                  // toggle means something else entirely.
                  icon: Icon(
                    widget.isReplaceRowOpen ? Icons.expand_more : Icons.chevron_right,
                    size: 18,
                  ),
                  tooltip: tr.editorFindToggleReplaceRowTooltip,
                  onPressed: widget.onReplaceRowToggled,
                ),
                const Icon(Icons.search, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _findController,
                    focusNode: _findFocusNode,
                    onChanged: widget.onQueryChanged,
                    onSubmitted: (_) => widget.onNextRequested(),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: tr.editorFindHint,
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _OcptSearchOptionToggle(
                            label: "Aa",
                            tooltip: tr.editorFindMatchCaseTooltip,
                            isSelected: widget.isCaseSensitive,
                            onPressed: widget.onCaseSensitivityToggled,
                          ),
                          _OcptSearchOptionToggle(
                            label: "ab",
                            tooltip: tr.editorFindWholeWordTooltip,
                            isSelected: widget.isWholeWord,
                            onPressed: widget.onWholeWordToggled,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.query.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    hasMatches
                        ? tr.editorFindMatchCounter(
                            (widget.currentMatchIndex ?? 0) + 1,
                            widget.matchCount,
                          )
                        : tr.editorFindNoMatches,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                  tooltip: tr.editorFindPreviousTooltip,
                  onPressed: hasMatches ? widget.onPreviousRequested : null,
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                  tooltip: tr.editorFindNextTooltip,
                  onPressed: hasMatches ? widget.onNextRequested : null,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: tr.editorFindCloseTooltip,
                  onPressed: widget.onCloseRequested,
                ),
              ],
            ),
            if (widget.isReplaceRowOpen) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const SizedBox(width: _leadingRowWidth),
                  const Icon(Icons.sync_alt, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _replaceController,
                      onChanged: widget.onReplacementChanged,
                      onSubmitted: (_) => widget.onReplaceRequested?.call(),
                      decoration: InputDecoration(isDense: true, hintText: tr.editorReplaceHint),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: hasMatches ? widget.onReplaceRequested : null,
                    child: Text(tr.editorReplaceAction),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: hasMatches ? widget.onReplaceAllRequested : null,
                    child: Text(tr.editorReplaceAllAction),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The find field's `Aa` (match case) and `ab` (whole word) toggles: an [IconButton] so the
/// selected/unselected background wash, shape and sizing all come from `iconButtonTheme`, with a
/// short text label standing in for an `Icon` — the Material icon set this app draws from has
/// neither glyph, and a `Text` child needs its colour set by hand since `IconButton` only resolves
/// its foreground colour through the `IconTheme` it wraps an `Icon` child in.
class _OcptSearchOptionToggle extends StatelessWidget {
  /// The short glyph shown in place of an icon (`Aa` or `ab`).
  final String label;

  /// The button's tooltip.
  final String tooltip;

  /// Whether the option is currently on.
  final bool isSelected;

  /// Called when the toggle is pressed.
  final VoidCallback onPressed;

  /// Class constructor
  const _OcptSearchOptionToggle({
    required this.label,
    required this.tooltip,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      isSelected: isSelected,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

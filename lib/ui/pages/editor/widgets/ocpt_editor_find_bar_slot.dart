// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_search_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_search_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search_sync.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_find_bar.dart';

/// The find/replace bar, the first row of `OcptEditorCentre`'s column, or the empty box that holds
/// its place while the bar is closed.
///
/// The slot is never removed: see `OcptEditorCentre` on why the editing surface must not move
/// between two positions of its column. Only the search's own state rebuilds it, so a keystroke in
/// the screenplay does not.
class OcptEditorFindBarSlot extends StatelessWidget {
  /// Whether the raw source field, rather than the styled editor, is the live editing surface.
  final bool isRawMode;

  /// Applies the bar to the live surface and carries out its replacements.
  final OcptEditorSearchSync searchSync;

  /// Called with the search state when `Replace all` is pressed, to ask and carry it out.
  ///
  /// The page answers it with a context of its own: the slot is moved by the shell when the window
  /// crosses the compact breakpoint, and a confirmation resolved afterwards must not be left with
  /// the context of a slot that is gone.
  final ValueChanged<OcptEditorSearchState> onReplaceAllRequested;

  /// Class constructor
  const OcptEditorFindBarSlot({
    required this.isRawMode,
    required this.searchSync,
    required this.onReplaceAllRequested,
    super.key,
  });

  /// Build the editor find bar slot as a [BlocBuilder].
  @override
  Widget build(BuildContext context) => BlocBuilder<OcptEditorSearchBloc, OcptEditorSearchState>(
    builder: (context, search) {
      if (!search.isOpen) {
        return const SizedBox.shrink();
      }

      final searchBloc = context.read<OcptEditorSearchBloc>();

      return OcptEditorFindBar(
        query: search.query,
        replacement: search.replacement,
        isCaseSensitive: search.isCaseSensitive,
        isWholeWord: search.isWholeWord,
        isReplaceRowOpen: search.isReplaceRowOpen,
        matchCount: search.matchCount,
        currentMatchIndex: search.currentMatchIndex,
        focusRequestId: search.focusRequestId,
        onQueryChanged: (query) => searchBloc.add(OcptEditorSearchQueryChangedEvent(query: query)),
        onReplacementChanged: (replacement) =>
            searchBloc.add(OcptEditorSearchReplacementChangedEvent(replacement: replacement)),
        onCaseSensitivityToggled: () =>
            searchBloc.add(const OcptEditorSearchCaseSensitivityToggledEvent()),
        onWholeWordToggled: () => searchBloc.add(const OcptEditorSearchWholeWordToggledEvent()),
        onNextRequested: () => searchBloc.add(const OcptEditorSearchNextRequestedEvent()),
        onPreviousRequested: () => searchBloc.add(const OcptEditorSearchPreviousRequestedEvent()),
        onReplaceRowToggled: () => searchBloc.add(const OcptEditorSearchReplaceRowToggledEvent()),
        // Raw mode acts straight on `_textController`; styled mode goes through
        // `OcptStyledEditorController`, the styled editor's own bridge — either way the button
        // stays enabled the moment there's at least one match (`OcptEditorFindBar` itself gates
        // that on `matchCount`), which the repository rule admits no second, mode-specific path.
        onReplaceRequested: () => isRawMode
            ? searchSync.requestRawReplace(search, searchBloc)
            : searchSync.requestStyledReplace(search, searchBloc),
        onReplaceAllRequested: () => onReplaceAllRequested(search),
        onCloseRequested: () => searchBloc.add(const OcptEditorSearchClosedEvent()),
      );
    },
  );
}

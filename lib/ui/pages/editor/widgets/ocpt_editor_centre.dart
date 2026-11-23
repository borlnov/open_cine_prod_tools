// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_search_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_spell_check_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search_sync.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_editor_search_text_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/ocpt_styled_editor_controller.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_screenplay_editor.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_find_bar_slot.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_preview.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_source_field.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_zoom_area.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_zoom_wheel.dart';

/// The editor itself (raw source field or styled block editor), the shell's `centre`, or the
/// read-only formatted preview while a project version is being previewed.
///
/// That substitution is deliberate: the preview renders the version exactly as it
/// would print, and reusing it costs nothing, whereas making the styled editor read-only would
/// mean a second super_editor rendering path (`SuperReader`, its own stylesheet, its own
/// title-page components) to maintain forever. It applies in both editing modes, since neither of
/// them may be typed into.
///
/// [isRawMode] is already the page's live mode by the time it reaches here, so on a
/// phone the raw source field is never the one built here even when [OcptEditorState.mode] itself
/// still says raw — the styled editor is, with page simulation forced off
/// ([isPageSimulationLive]) and [OcptStyledScreenplayEditor.isCompact] set whenever the window
/// is merely compact (a tablet too, not only a phone — see [isCompact]), which is the phone
/// default: raw source and this same read-only preview (its own version-preview branch above)
/// have no room to be usable there either.
///
/// The page zoom ([OcptEditorState.styledPageZoom]) is handed to the styled editor and to the
/// preview, so the sheet is typeset at it; the raw source keeps its size. While it is the "fit to
/// width" mode, the sheet is sized to the width of this area (a styled editor or a version
/// preview: the raw mode's preview lives in a dock of its own and keeps the last measure), and the
/// factor is reported back to the bloc, which is where a step starts from. A compact window has no
/// zoom ([isZoomAvailable]): the page is at 100 % and the wheel is left alone.
///
/// The find/replace bar is a *slot* that is always there — an empty box while it is closed —
/// rather than a child that comes and goes. A collection-`if` would move the editing surface
/// between two different positions in this column every time the bar opened or closed, and a
/// widget that changes position in the element tree is remounted whole rather than rebuilt: a
/// fresh `OcptStyledScreenplayEditor` state re-decodes the document, loses the caret, and
/// re-applies the pending scene-jump request — whose own `requestFocus()` then took the keyboard
/// focus straight back from the find field the bar had just opened, so the query being typed
/// landed in the screenplay instead of in the search.
class OcptEditorCentre extends StatelessWidget {
  /// The mode's state.
  final OcptEditorState state;

  /// Whether the raw source field, rather than the styled editor, is the live editing surface.
  final bool isRawMode;

  /// Whether page simulation is actually applied to the live editing surface.
  final bool isPageSimulationLive;

  /// Whether the window is narrow enough that the styled editor carries its block hierarchy by
  /// style rather than by the real screenplay indents.
  final bool isCompact;

  /// Whether the window is a phone, which has the styled editor use paper colours while fluid.
  final bool isPhoneWidth;

  /// Whether the page can be zoomed: false on a compact window, which has no zoom at all.
  final bool isZoomAvailable;

  /// The controller holding the live raw source text and selection.
  final OcptEditorSearchTextController textController;

  /// The controller of the raw editor's vertical scroll.
  final ScrollController scrollController;

  /// The raw editor's focus node.
  final FocusNode focusNode;

  /// The handle on the raw field's undo history.
  final UndoHistoryController undoController;

  /// The controller bridging the toolbar to the live styled editor.
  final OcptStyledEditorController styledController;

  /// Applies the find/replace bar to the live surface and carries out its replacements.
  final OcptEditorSearchSync searchSync;

  /// Called with the search state when the find bar's `Replace all` is pressed.
  final ValueChanged<OcptEditorSearchState> onReplaceAllRequested;

  /// Class constructor
  const OcptEditorCentre({
    required this.state,
    required this.isRawMode,
    required this.isPageSimulationLive,
    required this.isCompact,
    required this.isPhoneWidth,
    required this.isZoomAvailable,
    required this.textController,
    required this.scrollController,
    required this.focusNode,
    required this.undoController,
    required this.styledController,
    required this.searchSync,
    required this.onReplaceAllRequested,
    super.key,
  });

  /// Build the editor centre as a [Column].
  @override
  Widget build(BuildContext context) {
    final editorBloc = context.read<OcptEditorBloc>();
    void onStep(int direction) =>
        editorBloc.add(OcptEditorPageZoomSteppedEvent(direction: direction));
    void onFit(double factor) => editorBloc.add(OcptEditorFitPageZoomMeasuredEvent(factor: factor));

    if (state.isPreviewingVersion) {
      return OcptEditorZoomArea(
        zoom: state.styledPageZoom,
        pageSetup: state.pageSetup,
        isZoomAvailable: isZoomAvailable,
        onFitFactorMeasured: onFit,
        onZoomStepRequested: onStep,
        builder: (factor, onZoomStepRequested) => OcptEditorPreview(
          document: state.document,
          pageSetup: state.pageSetup,
          currentLine: state.currentLine,
          isPageSimulationEnabled: state.isPageSimulationEnabled,
          zoom: factor,
          onZoomStepRequested: onZoomStepRequested,
        ),
      );
    }

    // Read here, and closed over: the styled editor flushes its pending edit from its own
    // `deactivate`, which runs after this widget was itself deactivated (the shell moves its centre
    // between the row and the drawers, and leaving the page does the same), so a `context.read`
    // made when the callback runs would look up an inactive element and lose the edit.
    final spellCheckBloc = context.read<OcptEditorSpellCheckBloc>();

    // The raw source keeps its size: a Ctrl + wheel over it zooms the preview in its dock.
    final editingSurface = isRawMode
        ? OcptEditorZoomWheel(
            onZoomStepRequested: isZoomAvailable ? (direction, _) => onStep(direction) : null,
            child: OcptEditorSourceField(
              controller: textController,
              scrollController: scrollController,
              focusNode: focusNode,
              undoController: undoController,
            ),
          )
        : OcptEditorZoomArea(
            zoom: state.styledPageZoom,
            pageSetup: state.pageSetup,
            isZoomAvailable: isZoomAvailable,
            onFitFactorMeasured: onFit,
            onZoomStepRequested: onStep,
            builder: (factor, onZoomStepRequested) => OcptStyledScreenplayEditor(
              text: state.text,
              pageSetup: state.pageSetup,
              isPageSimulationEnabled: isPageSimulationLive,
              isCompact: isCompact,
              usesPaperColorsWhileFluid: isPhoneWidth,
              zoom: factor,
              onZoomStepRequested: onZoomStepRequested,
              areSceneNumbersVisible: state.areStyledSceneNumbersVisible,
              isSpellCheckVisible: state.isSpellCheckVisible,
              onTextChanged: (text) => editorBloc.add(OcptEditorTextChangedEvent(text: text)),
              onCaretLineChanged: (line) => editorBloc.add(OcptEditorCaretMovedEvent(line: line)),
              jumpRequest: state.jumpRequest,
              styledController: styledController,
              onSpellingSuggestionsRequested: spellCheckBloc.spellingSuggestionsFor,
              onWordIgnored: (word) => spellCheckBloc.add(OcptEditorWordIgnoredEvent(word: word)),
              onWordLearned: (word) => spellCheckBloc.add(OcptEditorWordLearnedEvent(word: word)),
            ),
          );

    return Column(
      children: [
        OcptEditorFindBarSlot(
          isRawMode: isRawMode,
          searchSync: searchSync,
          onReplaceAllRequested: onReplaceAllRequested,
        ),
        Expanded(child: editingSurface),
      ],
    );
  }
}

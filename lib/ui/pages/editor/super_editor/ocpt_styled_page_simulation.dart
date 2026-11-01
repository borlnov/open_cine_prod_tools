// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_change_node_metadata_request.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_styled_page_pagination.dart';
import 'package:super_editor/super_editor.dart';

/// The styled editor's page simulation bookkeeping: which nodes start a fresh simulated page, how
/// many pages the document spans, how many of them the title page takes, and the bottom padding
/// the last page needs.
///
/// The document and the editor are resolved through callbacks at call time, since the styled
/// editor replaces both whenever its text is rebuilt from outside.
final class OcptStyledPageSimulation {
  /// The number of simulated pages the document currently spans while page simulation is on
  /// (always 0 while it's off), set by [recompute].
  int pageCount;

  /// How many of those [pageCount] pages the title page takes up before the script itself starts
  /// (always 0 while page simulation is off), set by [recompute]: the offset a painted sheet's
  /// index needs before it means a **script** page number (see
  /// [OcptStyledPagination.titlePageSheetCount]).
  int titlePageSheetCount;

  /// The extra bottom padding the stylesheet's `documentPadding` needs so the document's
  /// scrollable content reaches all the way down to the last simulated page's own bottom margin
  /// (always 0 while page simulation is off), set by [recompute].
  double trailingBottomPadding;

  /// Resolves the document the pagination is computed over.
  final MutableDocument Function() _documentOf;

  /// Resolves the editor executing the page-start requests.
  final Editor Function() _editorOf;

  /// Runs a pass derived from the document rather than typed, merged onto the writer's gesture.
  final void Function(VoidCallback derivedPass) _runDerivedPass;

  /// Whether page simulation is on.
  final bool Function() _isEnabled;

  /// Resolves the page setup driving the layout metrics.
  final OcptPageSetup Function() _pageSetupOf;

  /// The document the pagination is computed over.
  MutableDocument get _document => _documentOf();

  /// The editor executing the page-start requests.
  Editor get _editor => _editorOf();

  /// Creates an [OcptStyledPageSimulation].
  OcptStyledPageSimulation({
    required MutableDocument Function() documentOf,
    required Editor Function() editorOf,
    required void Function(VoidCallback derivedPass) runDerivedPass,
    required bool Function() isEnabled,
    required OcptPageSetup Function() pageSetupOf,
  }) : pageCount = 0,
       titlePageSheetCount = 0,
       trailingBottomPadding = 0,
       _documentOf = documentOf,
       _editorOf = editorOf,
       _runDerivedPass = runDerivedPass,
       _isEnabled = isEnabled,
       _pageSetupOf = pageSetupOf;

  /// Recomputes which nodes start a fresh simulated page (their exact top padding stored as
  /// [ocptStartsNewPageMetadataKey] metadata, read by `OcptFountainEditorStylesheet`'s
  /// page-boundary spacing), [pageCount] and [trailingBottomPadding], for the current document,
  /// `OcptStyledScreenplayEditor.isPageSimulationEnabled` and `OcptStyledScreenplayEditor.pageSetup`.
  ///
  /// While page simulation is off, this only clears any padding left over from before it was
  /// turned off (so turning it back on later starts pagination from a clean slate) and resets
  /// [pageCount]/[trailingBottomPadding] to 0. Only mutates those fields and executes editor
  /// requests, neither of which needs `setState` from `initState`; every other caller wraps this
  /// in its own `setState`.
  ///
  /// Its requests go through [_runDerivedPass] for the same reason `OcptStyledDocumentSettle.settle`'s do: where a
  /// page break falls is derived from the document, never typed, so it belongs to the gesture that
  /// moved it rather than being an undo step of its own. Keeping it *in* history (merged) rather
  /// than out of it is what makes an undo land on a correctly paginated document straight away:
  /// `Editor.undo()` rebuilds the document by resetting it to the snapshot `MutableDocument`'s own
  /// constructor took — which carries no page padding at all — and replaying history, so a
  /// non-historical padding would simply vanish on every Ctrl+Z until the next debounce put it
  /// back.
  void recompute() {
    if (!_isEnabled()) {
      final clearRequests = <EditRequest>[
        for (final node in _document)
          if (node is ParagraphNode && _pageStartPaddingOf(node) != 0)
            OcptChangeNodeMetadataRequest(
              nodeId: node.id,
              metadata: {ocptStartsNewPageMetadataKey: 0.0},
            ),
      ];
      if (clearRequests.isNotEmpty) {
        _runDerivedPass(() => _editor.execute(clearRequests));
      }
      pageCount = 0;
      titlePageSheetCount = 0;
      trailingBottomPadding = 0;
      return;
    }

    final metrics = _pageSetupOf().toMetrics();
    final pagination = computeOcptStyledPagination(document: _document, metrics: metrics);

    final requests = <EditRequest>[
      for (final node in _document)
        if (node is ParagraphNode)
          if (_pageStartPaddingOf(node) != (pagination.pageStartTopPaddings[node.id] ?? 0.0))
            OcptChangeNodeMetadataRequest(
              nodeId: node.id,
              metadata: {
                ocptStartsNewPageMetadataKey: pagination.pageStartTopPaddings[node.id] ?? 0.0,
              },
            ),
    ];
    if (requests.isNotEmpty) {
      _runDerivedPass(() => _editor.execute(requests));
    }
    pageCount = pagination.pageCount;
    titlePageSheetCount = pagination.titlePageSheetCount;
    trailingBottomPadding = pagination.trailingBottomPadding;
  }

  /// The exact top padding (in logical pixels) [node] currently carries in
  /// [ocptStartsNewPageMetadataKey] metadata, or 0 if it doesn't start a page.
  static double _pageStartPaddingOf(ParagraphNode node) {
    final value = node.getMetadataValue(ocptStartsNewPageMetadataKey);
    return value is double ? value : 0;
  }
}

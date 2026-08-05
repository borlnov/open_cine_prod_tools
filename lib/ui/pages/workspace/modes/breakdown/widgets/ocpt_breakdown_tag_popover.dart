// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_cine_prod_tools/constants/ocpt_breakdown_palette.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_search.dart';

/// The widest the tag popover's own panel is ever drawn, in logical pixels — the mock-up's own
/// figure.
const double _ocptBreakdownTagPopoverWidth = 340;

/// The tallest the tag popover's own panel is ever drawn before its middle (the matches and the
/// creation grid) starts scrolling, in logical pixels.
const double _ocptBreakdownTagPopoverMaxHeight = 480;

/// The gap kept between the anchoring word and the popover, in logical pixels.
const double _ocptBreakdownTagPopoverGap = 6;

/// The margin kept between the popover and the overlay's own edges, in logical pixels.
const double _ocptBreakdownTagPopoverOverlayMargin = 12;

/// The room the popover wants under the word before it is drawn above it instead, in logical
/// pixels: enough for the header, the field and the first rows of the matches — under that, the
/// panel is worth flipping rather than squeezing.
const double _ocptBreakdownTagPopoverPreferredHeight = 260;

/// The shortest the popover is ever drawn, in logical pixels, whichever side of the word it ends up
/// on: a window too short for even this leaves nothing worth flipping to, and the panel keeps a
/// usable height rather than collapsing to a sliver.
const double _ocptBreakdownTagPopoverMinHeight = 160;

/// Anchors [popover] to [child] using an [OverlayPortal] and a [LayerLink]/
/// [CompositedTransformFollower] pair, so the popover paints into the app's own [Overlay] — above the
/// script sheet's `SingleChildScrollView`, which would otherwise clip it — rather than being measured
/// by hand.
///
/// **It is drawn under the word only while the overlay has the room for it**: a word near the bottom
/// of the window would otherwise hang the panel off the edge, its category grid and its footer out of
/// reach. The side is picked from the room actually left on each side of the word
/// ([_ocptBreakdownTagPopoverPreferredHeight]), and the panel is then capped to that room, its own
/// middle scrolling for the rest — the popover's height is a maximum, never a fixed size, so capping
/// it is enough. The anchoring word rides the script sheet's own scroll view, so the decision is
/// taken again whenever that scroll offset moves.
///
/// A fresh instance is what opens the popover: `OcptBreakdownScriptView` only ever builds this
/// wrapper around the one word `OcptBreakdownState.pendingTagRange` closed on, replacing the plain
/// word widget for as long as that range stays open. The moment it is cleared — linked, an element
/// created from it, or cancelled — that branch of the sheet stops being built and this widget, its
/// `LayerLink`, its controller and its overlay entry together, is torn down with it: there is no
/// `hide()` path to maintain, only the one show.
class OcptBreakdownTagPopoverAnchor extends StatefulWidget {
  /// The word this popover is anchored under.
  final Widget child;

  /// The popover's own content.
  final Widget popover;

  /// Class constructor
  const OcptBreakdownTagPopoverAnchor({super.key, required this.child, required this.popover});

  @override
  State<OcptBreakdownTagPopoverAnchor> createState() => _OcptBreakdownTagPopoverAnchorState();
}

class _OcptBreakdownTagPopoverAnchorState extends State<OcptBreakdownTagPopoverAnchor> {
  /// Owns whether the overlay entry is currently inserted.
  final OverlayPortalController _controller = OverlayPortalController();

  /// Links this word's own geometry to the popover's `CompositedTransformFollower`.
  final LayerLink _link = LayerLink();

  /// The scroll position the anchoring word rides on — the script sheet's own — or null while this
  /// widget is used outside a scroll view. Scrolling moves the word within the overlay, so the side
  /// the popover is drawn on has to be decided again: the link keeps the panel *on* the word by
  /// itself, it knows nothing of the edge it may be pushed past.
  ScrollPosition? _scrollPosition;

  @override
  void initState() {
    super.initState();
    // `OverlayPortalController.show()` must not be called while the tree is being built, so the
    // very first reveal is deferred to right after this frame — the one frame of lag is not worth
    // measuring anything by hand to avoid, and the word is laid out by then, which is what the
    // placement below is measured from.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.show();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final position = Scrollable.maybeOf(context)?.position;
    if (position != _scrollPosition) {
      _scrollPosition?.removeListener(_handleGeometryChanged);
      _scrollPosition = position;
      position?.addListener(_handleGeometryChanged);
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_handleGeometryChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _link,
    child: OverlayPortal(
      controller: _controller,
      overlayChildBuilder: _buildOverlayChild,
      child: widget.child,
    ),
  );

  /// The popover, followed onto the word and placed on whichever side of it the overlay has the
  /// room for, capped to that very room — see [OcptBreakdownTagPopoverAnchor]'s own doc comment.
  Widget _buildOverlayChild(BuildContext overlayContext) {
    final placement = _placementIn(overlayContext);

    return CompositedTransformFollower(
      link: _link,
      targetAnchor: placement.isAbove ? Alignment.topCenter : Alignment.bottomCenter,
      followerAnchor: placement.isAbove ? Alignment.bottomCenter : Alignment.topCenter,
      offset: Offset(
        0,
        placement.isAbove ? -_ocptBreakdownTagPopoverGap : _ocptBreakdownTagPopoverGap,
      ),
      child: Align(
        alignment: placement.isAbove ? Alignment.bottomCenter : Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: placement.maxHeight),
          child: widget.popover,
        ),
      ),
    );
  }

  /// Where the popover is drawn: under the word while the overlay leaves
  /// [_ocptBreakdownTagPopoverPreferredHeight] under it, above it while the room there is both
  /// short of that and worse than what is left above, and capped either way to the room that side
  /// actually has.
  ///
  /// Falls back to the panel's own default (under the word, its full height) while either box is
  /// missing — a frame in which nothing has been laid out yet is not a frame to measure.
  _OcptBreakdownTagPopoverPlacement _placementIn(BuildContext overlayContext) {
    final anchorBox = context.findRenderObject() as RenderBox?;
    final overlayBox = Overlay.of(overlayContext).context.findRenderObject() as RenderBox?;
    if (anchorBox == null ||
        !anchorBox.attached ||
        !anchorBox.hasSize ||
        overlayBox == null ||
        !overlayBox.attached ||
        !overlayBox.hasSize) {
      return const _OcptBreakdownTagPopoverPlacement(
        isAbove: false,
        maxHeight: _ocptBreakdownTagPopoverMaxHeight,
      );
    }

    final overlayTop = overlayBox.localToGlobal(Offset.zero).dy;
    final overlayBottom = overlayTop + overlayBox.size.height;
    final anchorTop = anchorBox.localToGlobal(Offset.zero).dy;
    final anchorBottom = anchorTop + anchorBox.size.height;

    const inset = _ocptBreakdownTagPopoverGap + _ocptBreakdownTagPopoverOverlayMargin;
    final roomBelow = overlayBottom - anchorBottom - inset;
    final roomAbove = anchorTop - overlayTop - inset;
    final isAbove = roomBelow < _ocptBreakdownTagPopoverPreferredHeight && roomAbove > roomBelow;
    final room = isAbove ? roomAbove : roomBelow;

    return _OcptBreakdownTagPopoverPlacement(
      isAbove: isAbove,
      maxHeight: room.clamp(_ocptBreakdownTagPopoverMinHeight, _ocptBreakdownTagPopoverMaxHeight),
    );
  }

  /// Rebuilds the overlay child so [_placementIn] is measured again, the word having moved.
  void _handleGeometryChanged() {
    if (mounted) {
      setState(() {});
    }
  }
}

/// Where [_OcptBreakdownTagPopoverAnchorState] draws the popover, once measured: the side of the
/// word it goes on, and the height it may not exceed there.
class _OcptBreakdownTagPopoverPlacement {
  /// Whether the popover is drawn above the word rather than under it.
  final bool isAbove;

  /// The tallest the popover may be drawn on that side, its own middle scrolling past that.
  final double maxHeight;

  /// Class constructor
  const _OcptBreakdownTagPopoverPlacement({required this.isAbove, required this.maxHeight});
}

/// The popover a range closes on: the passage in quotes, a search field pre-filled with it and
/// focused, the matches from [candidates] grouped `Roles`/`Sets`/`Elements`, the `Create an element`
/// category grid, an `Open in Resources` action shown when the search names no role and no set, and a
/// trailing hint.
///
/// The field's own text is both the query [candidates] are filtered against
/// (`ocptBreakdownSearchCatalogues`) and the name a category chip's creation would use — there is no
/// separate name field: correcting the name and picking the category are the same one gesture.
/// Purely presentational: every write goes upward through [onCandidateSelected] (linking) or
/// [onCategorySelected] (creating), the mode itself resolving each into
/// `OcptBreakdownService.createTag`/`createElementAndTag`.
///
/// Closed by [onClose] on its own × button, on `Escape`, or on a tap outside it
/// ([TapRegion.onTapOutside]) — the range interaction's own cancel, clearing the pending range **and**
/// the anchor.
class OcptBreakdownTagPopover extends StatefulWidget {
  /// The passage this popover is about, quoted in its header and used as the search field's initial
  /// text.
  final String taggedText;

  /// The whole catalogue this popover searches, built once by the mode from the loaded snapshot.
  final List<OcptBreakdownSearchCandidate> candidates;

  /// Called with a match when one of its rows is clicked, linking the passage to it.
  final ValueChanged<OcptBreakdownSearchCandidate> onCandidateSelected;

  /// Called with a category and the field's own current text when one of the category chips is
  /// clicked, creating a new element in that category and tagging the passage with it.
  final void Function(OcptElementCategory category, String name) onCategorySelected;

  /// Called when `Open in Resources` is clicked (shown only while the search names no role and no
  /// set).
  final VoidCallback onOpenInResourcesRequested;

  /// Called when the popover should close without writing anything: its own × button, `Escape`, or a
  /// tap outside it.
  final VoidCallback onClose;

  /// Class constructor
  const OcptBreakdownTagPopover({
    super.key,
    required this.taggedText,
    required this.candidates,
    required this.onCandidateSelected,
    required this.onCategorySelected,
    required this.onOpenInResourcesRequested,
    required this.onClose,
  });

  @override
  State<OcptBreakdownTagPopover> createState() => _OcptBreakdownTagPopoverState();
}

class _OcptBreakdownTagPopoverState extends State<OcptBreakdownTagPopover> {
  /// The query field, pre-filled with the passage — also the name a creation would use.
  late final TextEditingController _controller = TextEditingController(text: widget.taggedText);

  /// The query field's own focus, requested as soon as the popover appears.
  final FocusNode _fieldFocusNode = FocusNode();

  /// The last computed results, refreshed on every keystroke.
  late OcptBreakdownSearchResults _results = ocptBreakdownSearchCatalogues(
    query: _controller.text,
    candidates: widget.candidates,
  );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onQueryChanged)
      ..dispose();
    _fieldFocusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    setState(() {
      _results = ocptBreakdownSearchCatalogues(query: _controller.text, candidates: widget.candidates);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return TapRegion(
      onTapOutside: (_) => widget.onClose(),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onClose();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Material(
          elevation: 8,
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(ocptRadiusMedium),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: _ocptBreakdownTagPopoverWidth,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _ocptBreakdownTagPopoverMaxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, theme, tr),
                  Divider(height: 1, color: theme.colorScheme.outlineVariant),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: TextField(
                              controller: _controller,
                              focusNode: _fieldFocusNode,
                              autofocus: true,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: tr.breakdownPopoverFieldHint,
                              ),
                            ),
                          ),
                          if (!_results.isEmpty) _buildMatches(context, theme, tr),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                            child: Text(
                              tr.breakdownPopoverCreateElementTitle.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                            child: _buildCategoryGrid(context, tr),
                          ),
                          if (_results.roles.isEmpty && _results.sets.isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                              child: OutlinedButton(
                                onPressed: widget.onOpenInResourcesRequested,
                                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(34)),
                                child: Text(tr.breakdownOpenInResourcesAction),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
                    ),
                    child: Text(
                      tr.breakdownPopoverFooterHint,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The quoted passage and the × close button.
  Widget _buildHeader(BuildContext context, ThemeData theme, Tr tr) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            '"${widget.taggedText}"',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
        ),
        InkWell(
          onTap: widget.onClose,
          mouseCursor: ocptClickableCursor,
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(Icons.close, size: 16, color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    ),
  );

  /// The matches, grouped `Roles`/`Sets`/`Elements` — a group with no match of its own kind is left
  /// out entirely.
  Widget _buildMatches(BuildContext context, ThemeData theme, Tr tr) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (_results.roles.isNotEmpty)
        _buildGroup(context, theme, tr.breakdownPopoverRolesGroupTitle, _results.roles),
      if (_results.sets.isNotEmpty)
        _buildGroup(context, theme, tr.breakdownPopoverSetsGroupTitle, _results.sets),
      if (_results.elements.isNotEmpty)
        _buildGroup(context, theme, tr.breakdownPopoverElementsGroupTitle, _results.elements),
    ],
  );

  /// One group of the matches section: [title], then a clickable row per candidate of [candidates].
  Widget _buildGroup(
    BuildContext context,
    ThemeData theme,
    String title,
    List<OcptBreakdownSearchCandidate> candidates,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
        child: Text(
          title.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
      for (final candidate in candidates) _buildMatchRow(context, theme, candidate),
    ],
  );

  /// One clickable match row: its own swatch, its name and — while already tagged somewhere — the
  /// number of scenes it is tagged in.
  Widget _buildMatchRow(BuildContext context, ThemeData theme, OcptBreakdownSearchCandidate candidate) =>
      InkWell(
        onTap: () => widget.onCandidateSelected(candidate),
        mouseCursor: ocptClickableCursor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: Color(ocptBreakdownColorOf(kind: candidate.kind, category: candidate.category)),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  candidate.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (candidate.taggedSceneCount > 0) ...[
                const SizedBox(width: 8),
                Text(
                  Tr.of(context).breakdownInspectorSceneCountLabel(candidate.taggedSceneCount),
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      );

  /// The two-column category grid: a click creates the element in that category, named from the
  /// field's own current text.
  Widget _buildCategoryGrid(BuildContext context, Tr tr) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 6,
    crossAxisSpacing: 6,
    childAspectRatio: 3.4,
    children: [
      for (final category in OcptElementCategory.values)
        _OcptBreakdownPopoverCategoryChip(
          label: ocptElementCategoryLabel(tr, category),
          swatchColor: Color(
            ocptBreakdownColorOf(kind: OcptBreakdownTargetKind.element, category: category),
          ),
          onTap: () => widget.onCategorySelected(category, _nameFromField()),
        ),
    ],
  );

  /// The name a creation would use: the field's own trimmed text, falling back to the untouched
  /// passage when the user cleared it — a click on a category chip must never create a nameless
  /// element.
  String _nameFromField() {
    final trimmed = _controller.text.trim();
    return trimmed.isEmpty ? widget.taggedText : trimmed;
  }
}

/// One entry of the popover's category grid: a swatch and a label, mirroring
/// `OcptBreakdownTargetInspector`'s own category chip minus the "currently selected" state, which has
/// no meaning here — nothing is selected before a category is clicked, clicking one *is* the
/// creation.
class _OcptBreakdownPopoverCategoryChip extends StatelessWidget {
  /// The chip's own label.
  final String label;

  /// The category's own palette colour, shown as a small swatch.
  final Color swatchColor;

  /// Called when the chip is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptBreakdownPopoverCategoryChip({
    required this.label,
    required this.swatchColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: swatchColor, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// The tallest the tag popover's own panel is ever drawn before its middle (the matches and the
/// creation grid) starts scrolling, in logical pixels. Shared with the popover itself, which caps
/// its own column to it.
const double ocptBreakdownTagPopoverMaxHeight = 480;

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

/// Anchor [popover] to [child] using an [OverlayPortal] and a [LayerLink]/
/// [CompositedTransformFollower] pair, so the popover paints into the app's own [Overlay] — above
/// the script sheet's `SingleChildScrollView`, which would otherwise clip it — rather than being
/// measured by hand.
///
/// **It is drawn under the word only while the overlay has the room for it**: a word near the
/// bottom of the window would otherwise hang the panel off the edge, its category grid and its
/// footer out of reach. The side is picked from the room actually left on each side of the word
/// ([_ocptBreakdownTagPopoverPreferredHeight]), and the panel is then capped to that room, its own
/// middle scrolling for the rest — the popover's height is a maximum, never a fixed size, so
/// capping it is enough. The anchoring word rides the script sheet's own scroll view, so the
/// decision is taken again whenever that scroll offset moves.
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

  /// Create the [_OcptBreakdownTagPopoverAnchorState] holding the state of the breakdown tag
  /// popover anchor.
  @override
  State<OcptBreakdownTagPopoverAnchor> createState() => _OcptBreakdownTagPopoverAnchorState();
}

/// The state of [OcptBreakdownTagPopoverAnchor]: owns the overlay entry, the link and the scroll
/// listener that keeps the placement measured.
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

  /// Show the popover right after the first frame, since it cannot be shown while the tree builds.
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

  /// Follow the scroll position of the enclosing scrollable, so the popover is placed again when it
  /// scrolls.
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

  /// Build the breakdown tag popover anchor as a [CompositedTransformTarget].
  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _link,
    child: OverlayPortal(
      controller: _controller,
      overlayChildBuilder: (overlayContext) {
        final placement = _placementIn(overlayContext);

        return _PopoverFollower(
          link: _link,
          isAbove: placement.isAbove,
          maxHeight: placement.maxHeight,
          popover: widget.popover,
        );
      },
      child: widget.child,
    ),
  );

  /// Tell where the popover is drawn: under the word while the overlay leaves
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
        maxHeight: ocptBreakdownTagPopoverMaxHeight,
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
      maxHeight: room.clamp(_ocptBreakdownTagPopoverMinHeight, ocptBreakdownTagPopoverMaxHeight),
    );
  }

  /// Rebuild the overlay child so [_placementIn] is measured again, the word having moved.
  void _handleGeometryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Detach [_handleGeometryChanged] from [_scrollPosition].
  @override
  void dispose() {
    _scrollPosition?.removeListener(_handleGeometryChanged);
    super.dispose();
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

/// The popover, followed onto the word and placed on whichever side of it the overlay has the room
/// for, capped to that very room — see [OcptBreakdownTagPopoverAnchor]'s own doc comment.
class _PopoverFollower extends StatelessWidget {
  /// The link tying the popover to the anchoring word.
  final LayerLink link;

  /// Whether the popover is drawn above the word rather than under it.
  final bool isAbove;

  /// The tallest the popover may be drawn on that side.
  final double maxHeight;

  /// The popover's own content.
  final Widget popover;

  /// Class constructor
  const _PopoverFollower({
    required this.link,
    required this.isAbove,
    required this.maxHeight,
    required this.popover,
  });

  /// Build the popover follower as a [CompositedTransformFollower].
  @override
  Widget build(BuildContext context) => CompositedTransformFollower(
    link: link,
    targetAnchor: isAbove ? Alignment.topCenter : Alignment.bottomCenter,
    followerAnchor: isAbove ? Alignment.bottomCenter : Alignment.topCenter,
    offset: Offset(0, isAbove ? -_ocptBreakdownTagPopoverGap : _ocptBreakdownTagPopoverGap),
    child: Align(
      alignment: isAbove ? Alignment.bottomCenter : Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: popover,
      ),
    ),
  );
}

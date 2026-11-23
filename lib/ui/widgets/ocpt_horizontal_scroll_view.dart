// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// How thin the always-visible bar is drawn, in logical pixels — deliberately under the app theme's
/// own `ScrollbarThemeData` thickness (which every *interactive*, fade-in-on-hover scrollbar
/// keeps), because a bar that is on screen the whole time has to sit quieter than one that only
/// appears while the reader is actually scrolling.
const double _ocptHorizontalScrollbarThickness = 5;

/// A horizontal [SingleChildScrollView] drawn under an **always-visible** [Scrollbar], so a view
/// wide enough to overflow its frame says so with a bar the reader can see, rather than leaving the
/// horizontal scroll to be discovered by accident. Without it a wide table (the budget mode's cost
/// tracking, cash journal, financing plan and logistics matrices) scrolls silently — nothing on
/// screen tells the reader there are columns off the right edge.
///
/// It owns its own [ScrollController] because a [Scrollbar] with `thumbVisibility` needs one it can
/// attach to. Its colour and radius are the app theme's own `ScrollbarThemeData`, inherited like
/// every other surface; only its **thickness** is overridden, thinner
/// ([_ocptHorizontalScrollbarThickness]), because this bar is persistent rather than shown only
/// while scrolling — see that constant's own doc comment.
class OcptHorizontalScrollView extends StatefulWidget {
  /// The content laid out to its own intrinsic width and scrolled horizontally under the bar —
  /// typically a `SizedBox` widened past the viewport when the columns do not fit.
  final Widget child;

  /// Padding inside the scroll view, around [child] — forwarded to the [SingleChildScrollView].
  final EdgeInsetsGeometry? padding;

  /// The controller of the scrolling, for a caller that has to move it; null for one of its own.
  final ScrollController? controller;

  /// Whether the bar is there, which a content that may or may not overflow turns on only while it
  /// does; true by default, the bar then being persistent.
  final bool showsBar;

  /// Class constructor
  const OcptHorizontalScrollView({
    super.key,
    required this.child,
    this.padding,
    this.controller,
    this.showsBar = true,
  });

  /// Create the [_OcptHorizontalScrollViewState] holding the state of the horizontal scroll view.
  @override
  State<OcptHorizontalScrollView> createState() => _OcptHorizontalScrollViewState();
}

/// The state of [OcptHorizontalScrollView].
class _OcptHorizontalScrollViewState extends State<OcptHorizontalScrollView> {
  /// The controller the [Scrollbar] and its [SingleChildScrollView] share — a `thumbVisibility` bar
  /// must be handed the very controller its scroll view reads.
  late final ScrollController _controller = widget.controller ?? ScrollController();

  /// Build the horizontal scroll view as a [Scrollbar].
  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: _controller,
    thumbVisibility: widget.showsBar,
    thickness: _ocptHorizontalScrollbarThickness,
    child: SingleChildScrollView(
      controller: _controller,
      scrollDirection: Axis.horizontal,
      padding: widget.padding,
      child: widget.child,
    ),
  );

  /// Dispose [_controller], unless the caller owns it.
  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }
}

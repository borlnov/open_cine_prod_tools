// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter/material.dart';

/// Draws the image file at [path], or whatever [fallbackBuilder] returns when there is no file
/// there to draw.
///
/// **The single place the app decides what a referenced image looks like.** Three surfaces show
/// one — the person sheet's photo slot, the element sheet's, and the small avatars of the lists —
/// and all three answer a missing file the same way: they fall back, silently, to what they showed
/// before photos existed. A path resolving to nothing is a **normal state** rather than an error
/// (`docs/adr/0013-binary-assets-referenced-by-path.md`): the `.ocpt` travelled to another machine,
/// or the file moved, and the reference is kept so it can be pointed at the file's new home.
///
/// A caller that wants a missing file *said out loud* rather than fallen back from wants
/// `OcptAssetFileLine` (a document, read by its name) or the scouting-photo tile
/// (`OcptLocationSheetPhotosCard`), which both report it: a location's fourteen photos are a list,
/// and a list silently one item short is a bug the user cannot see. A person has **one** photo, and
/// their initials are a perfectly good thing to see in its place.
///
/// A [StatefulWidget] (the documented RFL1 exception) for the reason `OcptAssetFileLine` is one:
/// whether the file is there is asked once, with a single `stat`, when the widget is built or given
/// another path — never from `build`, which would run it on every frame an unrelated rebuild
/// produces. [Image.file]'s own `errorBuilder` is the second guard, for the file that *is* there
/// and still cannot be decoded.
class OcptReferencedImage extends StatefulWidget {
  /// The absolute path of the image to draw, or null while nothing is referenced — [fallbackBuilder]
  /// then answers without a `stat` ever running.
  final String? path;

  /// How the image fills the space it is given.
  final BoxFit fit;

  /// What to draw instead when [path] is null or names no file.
  final WidgetBuilder fallbackBuilder;

  /// Class constructor
  const OcptReferencedImage({
    super.key,
    required this.path,
    required this.fallbackBuilder,
    this.fit = BoxFit.cover,
  });

  @override
  State<OcptReferencedImage> createState() => _OcptReferencedImageState();
}

/// The state of [OcptReferencedImage]: whether the referenced file was found, once asked.
class _OcptReferencedImageState extends State<OcptReferencedImage> {
  /// Whether the referenced file was there when it was last asked about. False whenever no file is
  /// referenced at all, which is the same thing to draw and one `stat` fewer to run.
  late bool _exists = _fileExists(widget.path);

  @override
  void didUpdateWidget(covariant OcptReferencedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != oldWidget.path) {
      _exists = _fileExists(widget.path);
    }
  }

  /// Whether [path] names a file that is there right now.
  static bool _fileExists(String? path) =>
      path != null && path.isNotEmpty && File(path).existsSync();

  @override
  Widget build(BuildContext context) {
    final path = widget.path;

    if (!_exists || path == null) {
      return widget.fallbackBuilder(context);
    }

    return Image.file(
      File(path),
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) => widget.fallbackBuilder(context),
    );
  }
}

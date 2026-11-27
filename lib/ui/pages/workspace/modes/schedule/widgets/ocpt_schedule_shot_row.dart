// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:material_ui/material_ui.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_schedule_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_shot_list_labels.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_referenced_image.dart';

/// The width of a shot row's thumbnail, in logical pixels.
const double _ocptScheduleShotRowThumbnailWidth = 80;

/// The height of a shot row's thumbnail, in logical pixels — a 16:9 frame.
const double _ocptScheduleShotRowThumbnailHeight = 45;

/// The width of a shot row's content below which the thumbnail is dropped, in logical pixels, so
/// that the text is never squeezed by an image.
const double _ocptScheduleShotRowThumbnailMinContentWidth = 220;

/// The horizontal space a framed row takes around its content: its padding and its border.
const double _ocptScheduleShotRowFramedInset = 18;

/// One shot of the schedule's shot lists, drawn on up to three lines next to its storyboard
/// thumbnail — shared by the left dock's unplaced-shots list and the shot picker dialog.
///
/// The first line holds the code, the shot size, the abbreviation as a small badge, then the
/// duration and the day tags pushed to the right; the second line holds the framing, on two lines
/// at most; the third line holds the camera move and the lens on the left and the characters on
/// the right. A line with nothing to say is left out. A text cut short by the width carries a
/// tooltip with its full content.
///
/// The thumbnail is the first storyboard panel's image alone, or a dashed frame of the same size
/// while there is none; it is dropped when the row is too narrow to keep its text readable.
///
/// The row knows nothing about the router: [onTap] does whatever picking the shot means. The mark
/// of a shot already placed is information, never a bar: the row stays clickable either way.
class OcptScheduleShotRow extends StatelessWidget {
  /// The shot the row shows.
  final OcptShot shot;

  /// The absolute path of [shot]'s first storyboard image, or null while it has none.
  final String? thumbnailPath;

  /// The day numbers [shot] is already placed on, or null while it is placed nowhere (or when the
  /// caller has no use for the mark).
  final List<int>? dayNumbers;

  /// Whether this shot is the one currently selected — only drawn when [isFramed].
  final bool isSelected;

  /// Called when the row is clicked.
  final VoidCallback onTap;

  /// Whether the row is drawn as a bordered card, as the left dock does, rather than as a flat
  /// row, as the picker dialog does.
  final bool isFramed;

  /// Class constructor
  const OcptScheduleShotRow({
    super.key,
    required this.shot,
    required this.thumbnailPath,
    required this.dayNumbers,
    required this.onTap,
    required this.isFramed,
    this.isSelected = false,
  });

  /// Build the schedule shot row as an [InkWell].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(ocpt_theme.ocptRadiusSmall);

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth =
            constraints.maxWidth - (isFramed ? _ocptScheduleShotRowFramedInset : 0);
        final content = _OcptScheduleShotRowContent(
          shot: shot,
          thumbnailPath: thumbnailPath,
          dayNumbers: dayNumbers,
          hasThumbnail: contentWidth >= _ocptScheduleShotRowThumbnailMinContentWidth,
        );

        if (!isFramed) {
          return InkWell(
            onTap: onTap,
            mouseCursor: ocpt_theme.ocptClickableCursor,
            borderRadius: radius,
            child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: content),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: InkWell(
            onTap: onTap,
            mouseCursor: ocpt_theme.ocptClickableCursor,
            borderRadius: radius,
            child: Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: ocpt_theme.ocptSelectedStateAlpha)
                    : theme.colorScheme.surfaceContainerHigh,
                border: Border.all(
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                ),
                borderRadius: radius,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: content,
            ),
          ),
        );
      },
    );
  }
}

/// The inside of an [OcptScheduleShotRow]: the thumbnail beside the three lines of text.
class _OcptScheduleShotRowContent extends StatelessWidget {
  /// The shot the row shows.
  final OcptShot shot;

  /// The absolute path of the shot's first storyboard image, or null while it has none.
  final String? thumbnailPath;

  /// The day numbers the shot is already placed on, or null.
  final List<int>? dayNumbers;

  /// Whether the row is wide enough to keep its thumbnail.
  final bool hasThumbnail;

  /// Class constructor
  const _OcptScheduleShotRowContent({
    required this.shot,
    required this.thumbnailPath,
    required this.dayNumbers,
    required this.hasThumbnail,
  });

  /// Build the shot row content as a [Row].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final cameraLens = [shot.cameraMove, shot.lens].where((text) => text.isNotEmpty).join(" · ");
    final characters = shot.characters.join(", ");

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasThumbnail) ...[
          _OcptScheduleShotRowThumbnail(path: thumbnailPath),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OcptScheduleShotRowTitleLine(shot: shot, dayNumbers: dayNumbers),
              if (shot.framing.isNotEmpty) ...[
                const SizedBox(height: 2),
                _OcptScheduleShotRowText(text: shot.framing, style: mutedStyle, maxLines: 2),
              ],
              if (cameraLens.isNotEmpty || characters.isNotEmpty) ...[
                const SizedBox(height: 2),
                _OcptScheduleShotRowDetailsLine(
                  cameraLens: cameraLens,
                  characters: characters,
                  style: mutedStyle,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The first line of an [OcptScheduleShotRow]: code, shot size and abbreviation on the left,
/// duration and day tags on the right.
class _OcptScheduleShotRowTitleLine extends StatelessWidget {
  /// The shot the line shows.
  final OcptShot shot;

  /// The day numbers the shot is already placed on, or null.
  final List<int>? dayNumbers;

  /// Class constructor
  const _OcptScheduleShotRowTitleLine({required this.shot, required this.dayNumbers});

  /// Build the shot row title line as a [Row].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final dayNumbers = this.dayNumbers;
    final isPlaced = dayNumbers != null && dayNumbers.isNotEmpty;
    final mutedStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                shot.code,
                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: _OcptScheduleShotRowText(
                  text: shot.shotSize,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                ),
              ),
              if (shot.abbreviation.isNotEmpty) ...[
                const SizedBox(width: 6),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(
                      alpha: ocpt_theme.ocptSelectedStateAlpha,
                    ),
                    borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    child: Text(
                      shot.abbreviation,
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(ocptFormatShotDuration(shot.estimatedDurationMs), style: mutedStyle),
        if (isPlaced) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: tr.scheduleShotPickerAlreadyPlacedTooltip,
            child: Text(
              dayNumbers.map((n) => ocptScheduleDayTagLabel(tr, n)).join(", "),
              style: mutedStyle,
            ),
          ),
        ],
      ],
    );
  }
}

/// The third line of an [OcptScheduleShotRow]: the camera move and the lens on the left, the
/// characters on the right.
class _OcptScheduleShotRowDetailsLine extends StatelessWidget {
  /// The space kept between the two texts, in logical pixels.
  static const double _gap = 8;

  /// The camera move and the lens, already joined, or empty.
  final String cameraLens;

  /// The characters, already joined, or empty.
  final String characters;

  /// The style both texts are drawn in.
  final TextStyle? style;

  /// Class constructor
  const _OcptScheduleShotRowDetailsLine({
    required this.cameraLens,
    required this.characters,
    required this.style,
  });

  /// Build the shot row details line as a [Row].
  ///
  /// The two texts share the width by what they need rather than by halves: a short one keeps its
  /// natural width and the other takes the rest, and only when both are longer than half the line
  /// does each get one half.
  @override
  Widget build(BuildContext context) {
    final cameraLensText = _OcptScheduleShotRowText(text: cameraLens, style: style, maxLines: 1);
    final charactersText = _OcptScheduleShotRowText(
      text: characters,
      style: style,
      maxLines: 1,
      textAlign: TextAlign.end,
    );

    if (characters.isEmpty) {
      return Align(alignment: Alignment.centerLeft, child: cameraLensText);
    }

    if (cameraLens.isEmpty) {
      return Align(alignment: Alignment.centerRight, child: charactersText);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final half = (constraints.maxWidth - _gap) / 2;
        final cameraLensWidth = _naturalWidthOf(context, cameraLens);
        final charactersWidth = _naturalWidthOf(context, characters);

        if (cameraLensWidth <= half) {
          return Row(
            children: [
              cameraLensText,
              const SizedBox(width: _gap),
              Expanded(child: charactersText),
            ],
          );
        }

        if (charactersWidth <= half) {
          return Row(
            children: [
              Expanded(child: cameraLensText),
              const SizedBox(width: _gap),
              charactersText,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cameraLensText),
            const SizedBox(width: _gap),
            Expanded(child: charactersText),
          ],
        );
      },
    );
  }

  /// Get the width [text] takes on one line in [style], unconstrained.
  double _naturalWidthOf(BuildContext context, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();

    return width;
  }
}

/// A text of an [OcptScheduleShotRow] cut at [maxLines] with an ellipsis, wrapped in a [Tooltip]
/// carrying its full content only when the width actually cuts it.
class _OcptScheduleShotRowText extends StatelessWidget {
  /// The full text.
  final String text;

  /// The style the text is drawn in.
  final TextStyle? style;

  /// The number of lines after which the text is cut.
  final int maxLines;

  /// How the text is aligned in its width.
  final TextAlign? textAlign;

  /// Class constructor
  const _OcptScheduleShotRowText({
    required this.text,
    required this.style,
    required this.maxLines,
    this.textAlign,
  });

  /// Build the text as a [Text], inside a [Tooltip] when it is truncated.
  @override
  Widget build(BuildContext context) {
    final child = Text(
      text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: style,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
          maxLines: maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final isTruncated = painter.didExceedMaxLines;
        painter.dispose();

        return isTruncated ? Tooltip(message: text, child: child) : child;
      },
    );
  }
}

/// The thumbnail of an [OcptScheduleShotRow]: the shot's first storyboard image, or a dashed frame
/// of the same size while there is none.
class _OcptScheduleShotRowThumbnail extends StatelessWidget {
  /// The absolute path of the image, or null.
  final String? path;

  /// Class constructor
  const _OcptScheduleShotRowThumbnail({required this.path});

  /// Build the thumbnail as a [SizedBox].
  @override
  Widget build(BuildContext context) => SizedBox(
    width: _ocptScheduleShotRowThumbnailWidth,
    height: _ocptScheduleShotRowThumbnailHeight,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
      child: OcptReferencedImage(
        path: path,
        fallbackBuilder: (context) => const _OcptScheduleShotRowPlaceholder(),
      ),
    ),
  );
}

/// The dashed frame drawn in place of a missing thumbnail, with an image glyph in its middle.
class _OcptScheduleShotRowPlaceholder extends StatelessWidget {
  /// Class constructor
  const _OcptScheduleShotRowPlaceholder();

  /// Build the placeholder as a [Semantics] around a [CustomPaint].
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: Tr.of(context).scheduleShotRowNoStoryboardLabel,
      image: true,
      child: CustomPaint(
        painter: _OcptScheduleDashedFramePainter(
          color: colorScheme.outlineVariant,
          radius: ocpt_theme.ocptRadiusSmall,
        ),
        child: Center(
          child: Icon(Icons.image_outlined, size: 18, color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Paint a dashed rounded rectangle along the border of the box it is given.
class _OcptScheduleDashedFramePainter extends CustomPainter {
  /// The length of a dash, in logical pixels.
  static const double _dashLength = 4;

  /// The length of a gap between two dashes, in logical pixels.
  static const double _gapLength = 3;

  /// The colour of the dashes.
  final Color color;

  /// The radius of the frame's corners.
  final double radius;

  /// Class constructor
  const _OcptScheduleDashedFramePainter({required this.color, required this.radius});

  /// Paint the dashed frame on [canvas].
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius((Offset.zero & size).deflate(0.5), Radius.circular(radius)),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = distance + _dashLength;
        canvas.drawPath(metric.extractPath(distance, end.clamp(0, metric.length)), paint);
        distance = end + _gapLength;
      }
    }
  }

  /// Tell whether the frame must be painted again for [oldDelegate].
  @override
  bool shouldRepaint(_OcptScheduleDashedFramePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

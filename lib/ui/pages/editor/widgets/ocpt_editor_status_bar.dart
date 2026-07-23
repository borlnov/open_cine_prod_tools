// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_relative_time.dart';

/// The editor's thin, discreet status bar: page/scene/speaking-character/word/sign counters
/// followed by the last-saved state, shown under the editing area in both styled and raw modes.
///
/// On a narrow window the counter row degrades from the right: the sign count drops first, then
/// the word count, while the pages/scenes/characters counters and the saved-state segment are
/// always kept.
class OcptEditorStatusBar extends StatelessWidget {
  /// The at-a-glance counters to show.
  final FountainScriptStatistics statistics;

  /// The time of the last successful save, or null if nothing was saved yet.
  final DateTime? lastSavedAt;

  /// Class constructor
  const OcptEditorStatusBar({required this.statistics, required this.lastSavedAt, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final style = theme.textTheme.labelSmall;
    final direction = Directionality.of(context);

    final pages = tr.editorStatsPages(statistics.pageCount);
    final scenes = tr.editorStatsScenes(statistics.sceneCount);
    final characters = tr.editorStatsCharacters(statistics.speakingCharacterCount);
    final words = tr.editorStatsWords(statistics.wordCount);
    final signs = tr.editorStatsSigns(statistics.signCount);
    final saved = _savedText(context, tr);

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            var counters = [pages, scenes, characters, words, signs];
            if (_joinedWidth(counters, saved, style, direction) > constraints.maxWidth) {
              counters = [pages, scenes, characters, words];
              if (_joinedWidth(counters, saved, style, direction) > constraints.maxWidth) {
                counters = [pages, scenes, characters];
              }
            }

            return Row(
              children: [
                Expanded(
                  child: Text(
                    counters.join(" · "),
                    style: style,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(" · ", style: style),
                _OcptSavedTimeSegment(lastSavedAt: lastSavedAt, style: style),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The saved-state text shown right now, used purely to size the counters against the
  /// available width; the actual on-screen segment is [_OcptSavedTimeSegment], which keeps
  /// itself current on its own 30 s timer.
  String _savedText(BuildContext context, Tr tr) {
    final lastSavedAt = this.lastSavedAt;
    return lastSavedAt == null
        ? tr.editorStatsNeverSaved
        : tr.editorStatsSavedRelative(formatRelativeTime(context, lastSavedAt));
  }

  /// The pixel width of [counters] joined by " · " plus the [saved] segment, as it would render
  /// with [style] in [direction] — used to decide which counters still fit.
  static double _joinedWidth(
    List<String> counters,
    String saved,
    TextStyle? style,
    TextDirection direction,
  ) {
    final text = "${counters.join(" · ")} · $saved";
    final painter = TextPainter(text: TextSpan(text: text, style: style), textDirection: direction)
      ..layout();
    return painter.width;
  }
}

/// The status bar's only stateful part: keeps the last-saved relative time current by
/// re-rendering every 30 s, without the parent [OcptEditorStatusBar] itself needing to rebuild.
class _OcptSavedTimeSegment extends StatefulWidget {
  /// The time of the last successful save, or null if nothing was saved yet.
  final DateTime? lastSavedAt;

  /// The text style to render with, matching the rest of the status bar.
  final TextStyle? style;

  /// Class constructor
  const _OcptSavedTimeSegment({required this.lastSavedAt, required this.style});

  @override
  State<_OcptSavedTimeSegment> createState() => _OcptSavedTimeSegmentState();
}

class _OcptSavedTimeSegmentState extends State<_OcptSavedTimeSegment> {
  /// Ticks every 30 s so the relative time stays current while this segment is on screen.
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final lastSavedAt = widget.lastSavedAt;
    final text = lastSavedAt == null
        ? tr.editorStatsNeverSaved
        : tr.editorStatsSavedRelative(formatRelativeTime(context, lastSavedAt));

    return Text(text, style: widget.style, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}

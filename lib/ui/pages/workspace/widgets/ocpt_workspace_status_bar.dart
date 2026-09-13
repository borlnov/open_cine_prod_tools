// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_sync_status_indicator.dart';

/// The workspace shell's thin, discreet status bar: an ordered summary line on the left, a
/// [trailing] widget, then the sync indicator, shown under a mode's centre area.
///
/// On a narrow window the summary degrades from the right: [counters] entries are dropped one at
/// a time, starting from the end, until what remains fits or only the leading [nonDroppableCount]
/// entries are left (those are never dropped, however narrow the bar gets). This generalises the
/// screenplay status bar's own "sign count drops first, then word count, pages/scenes/characters
/// always stay" behaviour to any ordered counter list.
///
/// [OcptSyncStatusIndicator] is built here, once, rather than by each mode's own status bar
/// wrapper: every mode reaches this same widget (the screenplay editor included, straight off
/// `OcptWorkspaceStatusBar` rather than through a wrapper of its own), so this is the one place
/// that reaches every mode without any of them having to wire it in by hand. It renders nothing at
/// all for a project with no sync session running (unpaired, or not yet started), so a mode with
/// nothing to say about sync simply shows the same status bar it always has.
class OcptWorkspaceStatusBar extends StatelessWidget {
  /// The at-a-glance counters to show, in the order they should be dropped from (last first).
  final List<String> counters;

  /// How many leading entries of [counters] are never dropped, however narrow the bar gets.
  final int nonDroppableCount;

  /// A plain-text stand-in for [trailing], used only to size the summary against the available
  /// width before degrading it.
  ///
  /// [trailing] is often a self-refreshing widget (e.g. a "saved x ago" segment) whose exact
  /// on-screen text can't be read back synchronously during this widget's own build; the caller
  /// computes the same text through whichever pure function backs [trailing] and passes it here
  /// purely for sizing purposes.
  final String trailingText;

  /// The widget shown to the right of the summary.
  final Widget trailing;

  /// Class constructor
  const OcptWorkspaceStatusBar({
    super.key,
    required this.counters,
    required this.nonDroppableCount,
    required this.trailingText,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall;
    final direction = Directionality.of(context);

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final summary = _fittingSummary(constraints.maxWidth, style, direction);

            return Row(
              children: [
                Expanded(
                  child: Text(
                    summary,
                    style: style,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(" · ", style: style),
                trailing,
                const OcptSyncStatusIndicator(),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The joined summary of as many trailing [counters] as still fit [maxWidth] alongside
  /// [trailingText], dropping the last one repeatedly until it does (or only [nonDroppableCount]
  /// entries remain).
  String _fittingSummary(double maxWidth, TextStyle? style, TextDirection direction) {
    var visibleCount = counters.length;
    while (visibleCount > nonDroppableCount &&
        _joinedWidth(counters.take(visibleCount).toList(), style, direction) > maxWidth) {
      visibleCount--;
    }
    return counters.take(visibleCount).join(" · ");
  }

  /// The pixel width of [visibleCounters] joined by " · " plus [trailingText], as it would render
  /// with [style] in [direction] — used to decide how many counters still fit.
  double _joinedWidth(List<String> visibleCounters, TextStyle? style, TextDirection direction) {
    final text = "${visibleCounters.join(" · ")} · $trailingText";
    final painter = TextPainter(text: TextSpan(text: text, style: style), textDirection: direction)
      ..layout();
    return painter.width;
  }
}

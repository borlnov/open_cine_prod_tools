// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_relative_time.dart';

/// The screenplay status bar's self-refreshing "saved x ago" segment: keeps the last-saved
/// relative time current by re-rendering every 30 s, without the surrounding status bar itself
/// needing to rebuild.
///
/// "Saved" is a screenplay-specific concept (autosave, manual save), unlike the generic counters
/// and the width-driven degradation `OcptWorkspaceStatusBar` owns; this is why it stays in the
/// editor and is handed to the shared status bar as its `trailing` slot.
class OcptEditorSavedTimeSegment extends StatefulWidget {
  /// The time of the last successful save, or null if nothing was saved yet.
  final DateTime? lastSavedAt;

  /// Class constructor
  const OcptEditorSavedTimeSegment({super.key, required this.lastSavedAt});

  /// The saved-state text [lastSavedAt] renders right now, computed without building this widget.
  ///
  /// `OcptWorkspaceStatusBar`'s width-driven degradation needs a plain-text stand-in for this
  /// self-refreshing segment to size the rest of the summary against, before this widget is
  /// actually laid out; this is the pure function backing both that stand-in and this widget's own
  /// `build`, so the two never drift apart.
  static String textFor(BuildContext context, DateTime? lastSavedAt) {
    final tr = Tr.of(context);
    return lastSavedAt == null
        ? tr.editorStatsNeverSaved
        : tr.editorStatsSavedRelative(formatRelativeTime(context, lastSavedAt));
  }

  @override
  State<OcptEditorSavedTimeSegment> createState() => _OcptEditorSavedTimeSegmentState();
}

/// The state of [OcptEditorSavedTimeSegment]: ticks a 30 s timer so the relative time stays
/// current while this segment is on screen.
class _OcptEditorSavedTimeSegmentState extends State<OcptEditorSavedTimeSegment> {
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
    final text = OcptEditorSavedTimeSegment.textFor(context, widget.lastSavedAt);
    final style = Theme.of(context).textTheme.labelSmall;

    return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}

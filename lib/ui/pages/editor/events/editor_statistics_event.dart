// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/events/editor_base_event.dart';

/// The events about the at-a-glance counters.
sealed class OcptEditorStatisticsEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorStatisticsEvent();
}

/// Request recomputing `OcptEditorStatisticsState.statistics` from the mode's current document and
/// page setup.
///
/// This is dispatched by the bloc's own statistics debounce timer, kept separate from the parse
/// debounce because pagination is too heavy to run on every parse tick while typing continuously;
/// it isn't meant to be sent by widgets.
class OcptEditorStatisticsRecomputeRequestedEvent extends OcptEditorStatisticsEvent {
  /// Class constructor
  const OcptEditorStatisticsRecomputeRequestedEvent();
}

/// Request recomputing `OcptEditorStatisticsState.sceneStatistics` from the mode's current
/// document,
/// caret and page setup, right away.
///
/// Dispatched by the bloc to itself when it sees a new document (the parse debounce) or the caret
/// land on another scene; it isn't meant to be sent by widgets. Composing the whole document to read
/// one scene's slice of it is too heavy for every keystroke, but a parse tick and a caret change of
/// scene are rare enough.
class OcptEditorStatisticsSceneRefreshRequestedEvent extends OcptEditorStatisticsEvent {
  /// Class constructor
  const OcptEditorStatisticsSceneRefreshRequestedEvent();
}

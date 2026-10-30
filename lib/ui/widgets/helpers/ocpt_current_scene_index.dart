// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';

/// The index, in [scenes] (in source order), of the scene containing [currentLine] (the last
/// scene starting at or before it), or null if [currentLine] precedes every scene (or [scenes] is
/// empty).
///
/// Shared by `OcptEditorScenePanel` (to highlight the current scene) and `OcptEditorState` (whose
/// `currentSceneIndex` getter feeds the right dock's inspector tab).
int? currentSceneIndexFor(List<FountainSceneHeading> scenes, int currentLine) {
  int? candidate;
  for (var index = 0; index < scenes.length; index++) {
    if (scenes[index].sourceRange.startLine <= currentLine) {
      candidate = index;
    } else {
      break;
    }
  }

  return candidate;
}

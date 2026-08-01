// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/models/ocpt_shot.dart';

/// One of the four axes a shot's difficulty is rated on, each 0-5. [OcptShot.averageDifficulty]
/// is their mean.
///
/// Kept as an enum, rather than reading `OcptShot.difficultySet` and its three siblings by name
/// at every call site that needs to iterate all four, so the shot list bloc and the inspector's
/// difficulty rows can both loop over [values] once instead of repeating the same four-way switch.
enum OcptShotDifficultyAxis {
  /// The difficulty of the set/location.
  set,

  /// The difficulty of the camera move.
  camera,

  /// The difficulty of the acting.
  acting,

  /// The difficulty of the sound recording.
  sound;

  /// This axis's current value on [shot], on the 0-5 scale.
  int valueOf(OcptShot shot) => switch (this) {
    OcptShotDifficultyAxis.set => shot.difficultySet,
    OcptShotDifficultyAxis.camera => shot.difficultyCamera,
    OcptShotDifficultyAxis.acting => shot.difficultyActing,
    OcptShotDifficultyAxis.sound => shot.difficultySound,
  };
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_themes_manager/act_themes_manager.dart';
import 'package:flutter/material.dart';

/// This class is used to define the specific colors of the app that are not defined in the color
/// scheme.
///
/// [previewBackdrop]: the raw-mode preview panel must always read as white paper, in both themes,
/// which the shared dock background it would otherwise inherit (also used by the scene panel and
/// the syntax guide, which do stay themed) cannot express.
///
/// [projectPosterTints]: the home page's project cards pick a poster tint from this list by a
/// stable hash of the project path, so a project keeps the same colour across launches and
/// machines; a `ColorScheme` role would give every card the same colour instead.
class OcptSpecificColors extends AbsAppSpecificColors<OcptSpecificColors> {
  /// The raw-mode preview panel's own backdrop, painted by `OcptEditorPreview` itself.
  final Color previewBackdrop;

  /// The project poster tint family, indexed by a stable hash of `OcptRecentProjectModel.path`.
  final List<Color> projectPosterTints;

  /// Class constructor
  const OcptSpecificColors({required this.previewBackdrop, required this.projectPosterTints});

  /// Implement the copyWith method required by [ThemeExtension]
  @override
  ThemeExtension<OcptSpecificColors> copyWith({
    Color? previewBackdrop,
    List<Color>? projectPosterTints,
  }) => OcptSpecificColors(
    previewBackdrop: previewBackdrop ?? this.previewBackdrop,
    projectPosterTints: projectPosterTints ?? this.projectPosterTints,
  );

  /// Implement the lerp method required by [ThemeExtension]
  @override
  ThemeExtension<OcptSpecificColors> lerp(OcptSpecificColors? other, double t) {
    if (other is! OcptSpecificColors) {
      return this;
    }
    return OcptSpecificColors(
      previewBackdrop: Color.lerp(previewBackdrop, other.previewBackdrop, t) ?? previewBackdrop,
      projectPosterTints: _lerpColorList(projectPosterTints, other.projectPosterTints, t),
    );
  }
}

/// Interpolates two colour lists element-wise. The two lists are expected to have the same
/// length (both brightnesses of [OcptSpecificColors.projectPosterTints] share one palette size),
/// but a differing length is tolerated defensively by holding the shorter list's last colour for
/// the extra entries rather than throwing.
List<Color> _lerpColorList(List<Color> from, List<Color> to, double t) {
  final length = from.length > to.length ? from.length : to.length;
  return List<Color>.generate(length, (index) {
    final start = index < from.length ? from[index] : from.last;
    final end = index < to.length ? to[index] : to.last;
    return Color.lerp(start, end, t) ?? start;
  });
}

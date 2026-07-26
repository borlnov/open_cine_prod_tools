// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_themes_manager/act_themes_manager.dart';
import 'package:flutter/material.dart';

/// This class is used to define the specific colors of the app that are not defined in the color
/// scheme.
///
/// [previewBackdrop] is the only field: the raw-mode preview panel must always read as white paper,
/// in both themes, which the shared dock background it would otherwise inherit (also used by the
/// scene panel and the syntax guide, which do stay themed) cannot express.
class OcptSpecificColors extends AbsAppSpecificColors<OcptSpecificColors> {
  /// The raw-mode preview panel's own backdrop, painted by `OcptEditorPreview` itself.
  final Color previewBackdrop;

  /// Class constructor
  const OcptSpecificColors({required this.previewBackdrop});

  /// Implement the copyWith method required by [ThemeExtension]
  @override
  ThemeExtension<OcptSpecificColors> copyWith({Color? previewBackdrop}) =>
      OcptSpecificColors(previewBackdrop: previewBackdrop ?? this.previewBackdrop);

  /// Implement the lerp method required by [ThemeExtension]
  @override
  ThemeExtension<OcptSpecificColors> lerp(OcptSpecificColors? other, double t) {
    if (other is! OcptSpecificColors) {
      return this;
    }
    return OcptSpecificColors(
      previewBackdrop: Color.lerp(previewBackdrop, other.previewBackdrop, t) ?? previewBackdrop,
    );
  }
}

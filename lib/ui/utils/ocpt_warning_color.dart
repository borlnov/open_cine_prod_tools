// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';

/// The colour the workspace marks everything needing attention — but not broken — with: the shot
/// list's ⚠ and its difficulties at or above the warning threshold, the read-only preview of a
/// project version, and every callout the mock-up paints amber rather than red.
///
/// Comes from [OcptSpecificColors], where the app puts the colours Material 3 has no role for:
/// `error` is reserved for real errors, and `primary` is the app's one accent. Falls back to
/// `error` only when the theme carries no [OcptSpecificColors] at all (a bare `ThemeData` in a
/// test), so a caller never has to handle a missing colour itself.
Color ocptWarningColor(BuildContext context) {
  final theme = Theme.of(context);
  return theme.extension<OcptSpecificColors>()?.shotStatusRetake ?? theme.colorScheme.error;
}

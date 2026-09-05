// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';

/// The status [OcptJoiningScanFrame]'s own border colour reflects, driven by the Rejoindre page
/// off `OcptJoiningBloc`'s state and whether the last submission it reacted to came from the
/// scanner tab at all — a manual-entry failure must not paint the camera frame red.
enum OcptJoiningScanStatus {
  /// No scan has affected the frame yet, or its outcome isn't tied to it — the theme's own
  /// outline colour.
  idle,

  /// The last scanned code did not lead to a successful join — `theme.colorScheme.error`.
  error,

  /// The last scanned code was decoded and handed to the bloc — the same green
  /// `OcptSpecificColors.shotStatusShot` already marks a shot as done with, matching the app's own
  /// "no green/amber Material role, use the shared semantic colour" reasoning (see that class's
  /// own doc comment).
  success,
}

/// A thin coloured frame around the Rejoindre screen's own camera preview, reporting
/// [OcptJoiningScanStatus] as its border colour.
///
/// Kept as its own widget, entirely free of `MobileScanner`, so a widget test can pump it in
/// isolation: `MobileScanner` cannot be instantiated under `flutter test` at all
/// (`OcptJoiningScannerView`'s own doc comment), which is exactly why the coloured border was
/// pulled out of that widget rather than drawn inside it.
class OcptJoiningScanFrame extends StatelessWidget {
  /// The status driving the frame's own border colour.
  final OcptJoiningScanStatus status;

  /// The framed content — `OcptJoiningScannerView`'s own `MobileScanner`, in the real app.
  final Widget child;

  /// Class constructor
  const OcptJoiningScanFrame({required this.status, required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: _colorFor(theme), width: 3),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ocptRadiusMedium - 3),
        child: child,
      ),
    );
  }

  /// The border colour for [status], resolved against [theme].
  Color _colorFor(ThemeData theme) => switch (status) {
    OcptJoiningScanStatus.idle => theme.colorScheme.outline,
    OcptJoiningScanStatus.error => theme.colorScheme.error,
    OcptJoiningScanStatus.success =>
      theme.extension<OcptSpecificColors>()?.shotStatusShot ?? theme.colorScheme.primary,
  };
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;
import 'package:open_cine_prod_tools/models/ocpt_specific_colors.dart';
import 'package:open_cine_prod_tools/ui/pages/joining/widgets/ocpt_joining_scan_status.dart';

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

  /// Build the joining scan frame as an [AnimatedContainer].
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        border: Border.all(color: _colorFor(theme), width: 3),
        borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusMedium),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusMedium - 3),
        child: child,
      ),
    );
  }

  /// Get the border colour for [status], resolved against [theme].
  Color _colorFor(ThemeData theme) => switch (status) {
    OcptJoiningScanStatus.idle => theme.colorScheme.outline,
    OcptJoiningScanStatus.error => theme.colorScheme.error,
    OcptJoiningScanStatus.success =>
      theme.extension<OcptSpecificColors>()?.shotStatusShot ?? theme.colorScheme.primary,
  };
}

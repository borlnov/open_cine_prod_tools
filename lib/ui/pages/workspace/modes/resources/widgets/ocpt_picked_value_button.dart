// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart' as ocpt_theme;

/// One value a picker sits behind: the value itself, clickable while [onPressed] is given, plain
/// text otherwise.
class OcptPickedValueButton extends StatelessWidget {
  /// The value shown.
  final String label;

  /// Called when it is clicked, or null while it may not be changed.
  final VoidCallback? onPressed;

  /// Class constructor
  const OcptPickedValueButton({super.key, required this.label, required this.onPressed});

  /// Build the picked value button as an [InkWell].
  @override
  Widget build(BuildContext context) {
    final onPressed = this.onPressed;
    final text = Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
    );

    if (onPressed == null) {
      return text;
    }

    return InkWell(
      onTap: onPressed,
      mouseCursor: ocpt_theme.ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocpt_theme.ocptRadiusSmall),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), child: text),
    );
  }
}

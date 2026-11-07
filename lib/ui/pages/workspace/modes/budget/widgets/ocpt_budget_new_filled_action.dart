// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// One of the wizard's primary actions (`Continue`, `Save`, `Create lines`) — a [FilledButton]
/// whose key is handed to the button itself, so the action stays findable and inspectable by it.
class OcptBudgetNewFilledAction extends StatelessWidget {
  /// The key given to the underlying [FilledButton].
  final Key buttonKey;

  /// The button's own label.
  final String label;

  /// Called when the button is pressed, or null to disable it.
  final VoidCallback? onPressed;

  /// Class constructor
  const OcptBudgetNewFilledAction({
    super.key,
    required this.buttonKey,
    required this.label,
    required this.onPressed,
  });

  /// Build the budget new filled action as a [FilledButton].
  @override
  Widget build(BuildContext context) =>
      FilledButton(key: buttonKey, onPressed: onPressed, child: Text(label));
}

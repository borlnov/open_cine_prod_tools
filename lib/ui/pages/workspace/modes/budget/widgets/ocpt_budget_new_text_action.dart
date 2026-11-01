// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// One of the wizard's secondary actions (`Cancel`, `Back`) — a [TextButton] whose key is handed
/// to the button itself, so the action stays findable and inspectable by it.
class OcptBudgetNewTextAction extends StatelessWidget {
  /// The key given to the underlying [TextButton].
  final Key buttonKey;

  /// The button's own label.
  final String label;

  /// Called when the button is pressed.
  final VoidCallback onPressed;

  /// Class constructor
  const OcptBudgetNewTextAction({
    super.key,
    required this.buttonKey,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) =>
      TextButton(key: buttonKey, onPressed: onPressed, child: Text(label));
}

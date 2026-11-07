// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// One primary or secondary action the detail panel offers, resolved by whichever detail panel
/// variant drew the variant currently on screen.
class OcptBudgetDetailAction {
  /// The button's own label.
  final String label;

  /// Called when the button is pressed.
  final VoidCallback onTap;

  /// Class constructor
  const OcptBudgetDetailAction({required this.label, required this.onTap});
}

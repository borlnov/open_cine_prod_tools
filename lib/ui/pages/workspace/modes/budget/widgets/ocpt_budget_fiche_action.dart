// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// One primary or secondary action the fiche offers, resolved by whichever fiche variant drew
/// the variant currently on screen.
class OcptBudgetFicheAction {
  /// The button's own label.
  final String label;

  /// Called when the button is pressed.
  final VoidCallback onTap;

  /// Class constructor
  const OcptBudgetFicheAction({required this.label, required this.onTap});
}

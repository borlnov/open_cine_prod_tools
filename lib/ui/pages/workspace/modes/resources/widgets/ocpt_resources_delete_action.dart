// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// The destructive action every resources sheet carries at its very bottom — `Delete this person`,
/// `Delete this role`, `Delete this location`, `Delete this element`.
///
/// It only asks: the question itself is `OcptResourcesDeleteConfirmDialog`, shown by the mode, so
/// the four sheets stay unaware of how the answer is obtained and every deletion in the app is
/// confirmed the same way. The action only ever renders when the sheet may be written to, so it
/// takes a plain non-null callback rather than a nullable one.
class OcptResourcesDeleteAction extends StatelessWidget {
  /// The action's own label, e.g. `Delete this location`.
  final String label;

  /// Called when the action is clicked, before anything is deleted: the confirmation the caller
  /// opens is what decides.
  final VoidCallback onDeleteRequested;

  /// Class constructor
  const OcptResourcesDeleteAction({
    super.key,
    required this.label,
    required this.onDeleteRequested,
  });

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: TextButton(
      onPressed: onDeleteRequested,
      style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
      child: Text(label),
    ),
  );
}

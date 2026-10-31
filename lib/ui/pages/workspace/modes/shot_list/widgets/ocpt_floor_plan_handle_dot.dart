// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// A small filled circle marking a draggable handle.
class OcptFloorPlanHandleDot extends StatelessWidget {
  /// The handle's own colour.
  final Color color;

  /// Class constructor
  const OcptFloorPlanHandleDot({super.key, required this.color});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
    ),
  );
}

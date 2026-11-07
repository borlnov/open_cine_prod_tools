// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

/// The maximum width of the invite and enrolment QR columns, matching the mock-up's own ~620px
/// column.
const _maxContentWidth = 620.0;

/// The centred, scrollable column of cards the sharing page's ② Invite state and the repointing
/// page's ② QR code state both lay their [children] out in.
class OcptInviteColumn extends StatelessWidget {
  /// The cards and rows of the column, stretched to its width.
  final List<Widget> children;

  /// Class constructor
  const OcptInviteColumn({super.key, required this.children});

  /// Build the invite column as a [Center].
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _maxContentWidth),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    ),
  );
}

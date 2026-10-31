// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_coverage_palette.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';

/// The radius from which the initials are set in `titleSmall` rather than in `labelSmall`: a sheet
/// header's own avatar is large enough to carry the bigger of the two, a list row's is not.
const double ocptLargeAvatarRadius = 18;

/// The circle a person with no photo wears: their palette colour, carrying their initials.
///
/// Split out of `OcptPersonAvatar` rather than nested inside it because the person sheet's photo
/// slot needs **this half alone**: the slot already resolves the photo itself, so handing it the
/// full avatar would have it ask the file system the same question a second time to reach the same
/// answer.
class OcptPersonInitialsAvatar extends StatelessWidget {
  /// The person this avatar stands for.
  final OcptPerson person;

  /// The circle's radius.
  final double radius;

  /// Class constructor
  const OcptPersonInitialsAvatar({super.key, required this.person, required this.radius});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = radius >= ocptLargeAvatarRadius
        ? theme.textTheme.titleSmall
        : theme.textTheme.labelSmall;

    return CircleAvatar(
      radius: radius,
      backgroundColor: Color(ocptCoverageColorAt(person.colorIndex)),
      child: Text(
        person.initials,
        style: style?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}

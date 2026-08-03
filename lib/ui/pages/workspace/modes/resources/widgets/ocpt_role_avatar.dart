// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_coverage_palette.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';

/// The fraction of an avatar's radius the "uncast" icon is sized at, so the two states of the
/// widget read as the same circle whichever [OcptRoleAvatar.radius] the call site asks for.
const double _iconScale = 1.1;

/// The radius from which the initials are set in `titleSmall` rather than in `labelSmall`: the
/// sheet header's own avatar is large enough to carry the bigger of the two, a list row's is not.
const double _largeAvatarRadius = 18;

/// A role's circular avatar: the cast member's own palette colour and initials while the role is
/// cast, a hollow, muted circle while it isn't — the app's one way of saying "nobody plays this
/// part yet" without a line of text alone carrying it.
///
/// Shared by the cast list of the left dock and by `OcptRoleSheetHeader`, which only differ in the
/// [radius] they ask for: the rule for what an uncast role looks like is stated once here, so the
/// two can never drift apart.
///
/// A person's colour is theirs, not the role's ([OcptPerson.colorIndex] through
/// `ocptCoverageColorAt`): casting the same actor in two roles shows the same circle twice, which
/// is exactly the point.
class OcptRoleAvatar extends StatelessWidget {
  /// The person cast in the role this avatar stands for, or null while it is uncast.
  final OcptPerson? castMember;

  /// The circle's radius.
  final double radius;

  /// Class constructor
  const OcptRoleAvatar({super.key, required this.castMember, required this.radius});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final castMember = this.castMember;

    if (castMember != null) {
      final style = radius >= _largeAvatarRadius
          ? theme.textTheme.titleSmall
          : theme.textTheme.labelSmall;

      return CircleAvatar(
        radius: radius,
        backgroundColor: Color(ocptCoverageColorAt(castMember.colorIndex)),
        child: Text(
          castMember.initials,
          style: style?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      );
    }

    final outline = theme.colorScheme.outline;
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: outline)),
      child: Icon(Icons.person_outline, size: radius * _iconScale, color: outline),
    );
  }
}

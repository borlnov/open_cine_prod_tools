// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_initials_avatar.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_referenced_image.dart';

/// A person's circular avatar: **their photo when they reference one, [OcptPersonInitialsAvatar]
/// when they don't**.
///
/// The one place that rule is written. Three surfaces show a person as a circle — the address
/// book's list, a role's avatar (`OcptRoleAvatar`, which resolves the actor first) and the person
/// sheet's own photo slot — and a photo referenced on the sheet has to appear on all three, or the
/// list would keep showing initials for somebody whose face the project now holds.
///
/// A missing file falls back to the initials silently, which is [OcptReferencedImage]'s rule and
/// the truthful one here: a person has one photo, and their initials are a perfectly good thing to
/// see in its place (`docs/adr/0013-binary-assets-referenced-by-path.md`).
class OcptPersonAvatar extends StatelessWidget {
  /// The person this avatar stands for.
  final OcptPerson person;

  /// The circle's radius.
  final double radius;

  /// Class constructor
  const OcptPersonAvatar({super.key, required this.person, required this.radius});

  /// Build the person avatar as a [ClipOval].
  @override
  Widget build(BuildContext context) => ClipOval(
    child: SizedBox.square(
      dimension: radius * 2,
      child: OcptReferencedImage(
        path: person.photo?.path,
        fallbackBuilder: (context) => OcptPersonInitialsAvatar(person: person, radius: radius),
      ),
    ),
  );
}

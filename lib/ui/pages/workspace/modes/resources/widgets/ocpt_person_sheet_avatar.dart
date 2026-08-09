// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_person_avatar.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_photo_slot.dart';

/// The diameter of the colour avatar circle standing in for a person who references no photo.
const double _avatarDiameter = 42;

/// The person sheet's header photo slot: their photo, or the circular avatar carrying their
/// initials on their palette colour while they reference none.
///
/// It is [OcptResourcesPhotoSlot] with a person's own placeholder, and everything the slot does —
/// the menu referencing a photo, dropping it and picking the fallback colour, and what a missing
/// file falls back to — is stated there rather than repeated here. The element sheet's header uses
/// the very same slot with an icon in place of these initials.
class OcptPersonSheetAvatar extends StatelessWidget {
  /// The person whose photo and colour this slot shows.
  final OcptPerson person;

  /// Called when the menu's reference entry is picked, or null while the sheet may not be written
  /// to.
  final VoidCallback? onPhotoPickRequested;

  /// Called when the menu's remove entry is picked, or null while it may not be used.
  final VoidCallback? onPhotoCleared;

  /// Called with the palette index picked, or null while the colour may not be changed.
  final ValueChanged<int>? onColorChanged;

  /// Class constructor
  const OcptPersonSheetAvatar({
    super.key,
    required this.person,
    required this.onPhotoPickRequested,
    required this.onPhotoCleared,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) => OcptResourcesPhotoSlot(
    photo: person.photo,
    currentColorIndex: person.colorIndex,
    placeholderBuilder: (context) =>
        Center(child: OcptPersonInitialsAvatar(person: person, radius: _avatarDiameter / 2)),
    onPhotoPickRequested: onPhotoPickRequested,
    onPhotoCleared: onPhotoCleared,
    onColorChanged: onColorChanged,
  );
}

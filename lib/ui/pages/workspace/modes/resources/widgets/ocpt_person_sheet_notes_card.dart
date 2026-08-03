// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_card.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';

/// A card holding a single multi-line free-text field, with no label of its own row since the
/// card's own title already says what it is: shared by the HMC notes card and the notes card,
/// exactly as the shot inspector's own Notes section needs no field label either.
class OcptPersonSheetNotesCard extends StatelessWidget {
  /// The card's title.
  final String title;

  /// The id of the person this field belongs to.
  final String personId;

  /// The field's current authoritative value.
  final String value;

  /// Called with the field's raw text on every keystroke, or null while the sheet may not be
  /// written to.
  final ValueChanged<String>? onChanged;

  /// Class constructor
  const OcptPersonSheetNotesCard({
    super.key,
    required this.title,
    required this.personId,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => OcptResourcesSheetCard(
    title: title,
    child: OcptResourcesSheetField(
      ownerId: personId,
      label: "",
      value: value,
      multiline: true,
      onChanged: onChanged,
    ),
  );
}

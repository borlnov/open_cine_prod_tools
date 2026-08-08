// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot.dart';
import 'package:open_cine_prod_tools/models/ocpt_shot_placement.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/shot_list/widgets/ocpt_shot_inspector_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_shot_list_labels.dart';

/// The shot list's right dock metadata tab: a short, read-only summary of the selected shot —
/// its sequence, set, characters, shooting day and planned takes.
///
/// The reference mock-up also lists a "history" feed for this tab; there is no history model in
/// this application yet, so it is deliberately left out rather than built against nothing.
class OcptShotMetadataPanel extends StatelessWidget {
  /// The selected shot, or null while none is (the empty state).
  final OcptShot? shot;

  /// [shot]'s sequence display number. Ignored while [shot] is null.
  final String sequenceDisplayNumber;

  /// [shot]'s sequence heading. Ignored while [shot] is null.
  final String sequenceHeading;

  /// [shot]'s own placement(s) in the schedule, empty while it hasn't been placed on any day yet.
  /// Ignored while [shot] is null.
  final List<OcptShotPlacement> placements;

  /// Class constructor
  const OcptShotMetadataPanel({
    super.key,
    required this.shot,
    required this.sequenceDisplayNumber,
    required this.sequenceHeading,
    required this.placements,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final shot = this.shot;

    if (shot == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          tr.shotListNoShotSelectedHint,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OcptShotInspectorReadOnlyField(
          label: tr.shotListInspectorSequenceLabel,
          value: sequenceDisplayNumber,
        ),
        OcptShotInspectorReadOnlyField(label: tr.shotListColumnSet, value: sequenceHeading),
        OcptShotInspectorReadOnlyField(
          label: tr.shotListColumnCharacters,
          value: shot.characters.isEmpty ? ocptShotListEmptyValue : shot.characters.join(", "),
        ),
        OcptShotInspectorReadOnlyField(
          label: tr.shotListColumnShootingDay,
          value: ocptShotPlacementLabel(context, placements),
        ),
        OcptShotInspectorReadOnlyField(
          label: tr.shotListColumnTakes,
          value: shot.plannedTakes?.toString() ?? ocptShotListEmptyValue,
        ),
      ],
    );
  }
}

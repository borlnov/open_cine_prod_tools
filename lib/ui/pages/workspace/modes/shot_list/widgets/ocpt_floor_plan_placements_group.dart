// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';

/// One other case of the sequence, for [OcptFloorPlanPlacementsGroup]'s own trailing list — whether
/// the selected shot has a camera placed there too (`docs/plans/storyboard.md`, §4.3: `Hallway ·
/// no camera for this shot`).
class OcptFloorPlanPlacementsOtherCase {
  /// The other case's own name.
  final String caseName;

  /// How many of the shot's own cameras are placed on that case.
  final int cameraCount;

  /// Class constructor
  const OcptFloorPlanPlacementsOtherCase({required this.caseName, required this.cameraCount});
}

/// The shot inspector's floor-plans-only group (`OcptShotInspectorPanel.leadingGroup`): `On this
/// plan · Kitchen` — the selected shot's own placements on the selected case (its cameras with
/// their derived labels, the characters/lights/props placed for it, its arrows) and, under that,
/// one line per other case of the sequence naming whether the shot has a camera there too
/// (`docs/plans/storyboard.md`, §4.3).
///
/// Every symbol and arrow here is the shot's own — never a ghost, never a sequence layer, exactly
/// what `OcptFloorPlanCanvas` draws editable under this very shot's focus. Deleting a placement is
/// irreversible: this group only **asks** ([onSymbolDeleteRequested]/[onArrowDeleteRequested]), the
/// mode opens `OcptConfirmDialog` and dispatches the deletion itself, mirroring
/// `OcptStoryboardPanelsGroup`'s own `onDeleteRequested`.
class OcptFloorPlanPlacementsGroup extends StatelessWidget {
  /// The selected case's own name.
  final String caseName;

  /// The shot's own cameras on the selected case, each carrying its derived
  /// [OcptFloorPlanSymbolShape.cameraLabel].
  final List<OcptFloorPlanSymbolShape> cameras;

  /// The shot's own characters placed on the selected case.
  final List<OcptFloorPlanSymbolShape> characters;

  /// The shot's own lights placed on the selected case.
  final List<OcptFloorPlanSymbolShape> lights;

  /// The shot's own hand props placed on the selected case.
  final List<OcptFloorPlanSymbolShape> handProps;

  /// The shot's own arrows on the selected case.
  final List<OcptFloorPlanArrowShape> arrows;

  /// Every other case of the sequence, in tab order.
  final List<OcptFloorPlanPlacementsOtherCase> otherCases;

  /// Whether the mode shows a project version being previewed read-only, withholding every
  /// affordance this group offers.
  final bool isReadOnly;

  /// Called with a symbol's id when its own remove action is clicked — only asks — or null while
  /// withheld.
  final ValueChanged<String>? onSymbolDeleteRequested;

  /// Called with an arrow's id when its own remove action is clicked — only asks — or null while
  /// withheld.
  final ValueChanged<String>? onArrowDeleteRequested;

  /// Class constructor
  const OcptFloorPlanPlacementsGroup({
    super.key,
    required this.caseName,
    required this.cameras,
    required this.characters,
    required this.lights,
    required this.handProps,
    required this.arrows,
    required this.otherCases,
    required this.isReadOnly,
    required this.onSymbolDeleteRequested,
    required this.onArrowDeleteRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.shotListFloorPlanPlacementsGroupTitle(caseName),
          style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 8),
        _buildSection(
          context,
          title: tr.shotListFloorPlanPlacementsCamerasSectionTitle,
          symbols: cameras,
          emptyHint: tr.shotListFloorPlanPlacementsNoCameraHint,
          labelOf: (symbol) => symbol.cameraLabel ?? symbol.label,
        ),
        _buildSection(
          context,
          title: tr.shotListFloorPlanPlacementsCharactersSectionTitle,
          symbols: characters,
          emptyHint: tr.shotListFloorPlanPlacementsNoneHint,
          labelOf: (symbol) => symbol.label,
        ),
        _buildSection(
          context,
          title: tr.shotListFloorPlanPlacementsLightsSectionTitle,
          symbols: lights,
          emptyHint: tr.shotListFloorPlanPlacementsNoneHint,
          labelOf: (symbol) => symbol.label,
        ),
        _buildSection(
          context,
          title: tr.shotListFloorPlanPlacementsPropsSectionTitle,
          symbols: handProps,
          emptyHint: tr.shotListFloorPlanPlacementsNoneHint,
          labelOf: (symbol) => symbol.label,
        ),
        Text(
          tr.shotListFloorPlanPlacementsArrowsSectionTitle,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (arrows.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              tr.shotListFloorPlanPlacementsNoneHint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          for (final arrow in arrows)
            _buildRow(
              context,
              label: arrow.label.isEmpty
                  ? tr.shotListFloorPlanPlacementsArrowRowLabel
                  : arrow.label,
              onDeleteRequested: onArrowDeleteRequested == null
                  ? null
                  : () => onArrowDeleteRequested!(arrow.arrowId),
            ),
        const SizedBox(height: 8),
        if (otherCases.isNotEmpty) ...[
          Divider(color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 4),
          for (final otherCase in otherCases)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                otherCase.cameraCount > 0
                    ? tr.shotListFloorPlanPlacementsOtherCaseHasCameraHint(
                        otherCase.caseName,
                        otherCase.cameraCount,
                      )
                    : tr.shotListFloorPlanPlacementsOtherCaseNoCameraHint(otherCase.caseName),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ],
    );
  }

  /// One section of placed symbols (cameras, characters, lights or props): its title, then one row
  /// per symbol, or [emptyHint] while it holds none.
  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<OcptFloorPlanSymbolShape> symbols,
    required String emptyHint,
    required String Function(OcptFloorPlanSymbolShape symbol) labelOf,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (symbols.isEmpty)
            Text(
              emptyHint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          else
            for (final symbol in symbols)
              _buildRow(
                context,
                label: labelOf(symbol),
                color: Color(symbol.colorArgb),
                onDeleteRequested: onSymbolDeleteRequested == null
                    ? null
                    : () => onSymbolDeleteRequested!(symbol.symbolId),
              ),
        ],
      ),
    );
  }

  /// One placement's own row: a colour swatch (when given), its label, and a trailing remove
  /// action while [onDeleteRequested] isn't withheld.
  Widget _buildRow(
    BuildContext context, {
    required String label,
    Color? color,
    required VoidCallback? onDeleteRequested,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          if (color != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          if (onDeleteRequested != null)
            IconButton(
              iconSize: 14,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: onDeleteRequested,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}

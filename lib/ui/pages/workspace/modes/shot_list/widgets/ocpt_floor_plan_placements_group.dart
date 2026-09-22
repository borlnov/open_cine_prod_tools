// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_floor_plan_sheet.dart';
import 'package:open_cine_prod_tools/utils/ocpt_floor_plan_geometry.dart';

/// The step, in degrees, one click of the cameras section's own `−`/`+` field-of-view stepper
/// changes a camera's angle by.
const double _fovStepDeg = 5;

/// One other set of the sequence, for [OcptFloorPlanPlacementsGroup]'s own trailing list — whether
/// the selected shot has a camera placed there too (`docs/plans/storyboard.md`, §4.3: `Hallway ·
/// no camera for this shot`).
class OcptFloorPlanPlacementsOtherSet {
  /// The other set's own name.
  final String setName;

  /// How many of the shot's own cameras are placed on that set.
  final int cameraCount;

  /// Class constructor
  const OcptFloorPlanPlacementsOtherSet({required this.setName, required this.cameraCount});
}

/// The shot inspector's floor-plans-only group (`OcptShotInspectorPanel.leadingGroup`): `On this
/// plan · Kitchen`, regrouped (R3, `docs/plans/storyboard.md`, §9.4) into three headed sections —
/// **Selection** (the selected symbol or arrow's own read-out, [selectedSymbolId]/
/// [selectedArrowId]), **On this shot** (the selected shot's own placements on the selected set:
/// its cameras with their derived labels, the characters/lights/props placed for it, its arrows)
/// and **Set** (one line per other set of the sequence naming whether the shot has a camera there
/// too). Regrouping only — no field this group didn't already carry.
///
/// Every symbol and arrow here is the shot's own — never a ghost, never a sequence layer, exactly
/// what `OcptFloorPlanCanvas` draws editable under this very shot's focus. Deleting a placement is
/// irreversible: this group only **asks** ([onSymbolDeleteRequested]/[onArrowDeleteRequested]), the
/// mode opens `OcptConfirmDialog` and dispatches the deletion itself, mirroring
/// `OcptStoryboardPanelsGroup`'s own `onDeleteRequested`. Each camera row also carries a `−`/`+`
/// field-of-view stepper ([onCameraFovChanged]) — the one control here that writes directly, with
/// no confirmation: a lens angle is a value to dial in, not an irreversible act, and the same write
/// the canvas's own edge handles make (`OcptFloorPlanService.updateSymbol(fovDeg:)`).
class OcptFloorPlanPlacementsGroup extends StatelessWidget {
  /// The selected case's own name.
  final String setName;

  /// The id of the currently selected symbol on the canvas, or null while none is — the
  /// **Selection** section's own subject.
  final String? selectedSymbolId;

  /// The id of the currently selected arrow on the canvas, or null while none is. See
  /// [selectedSymbolId]; mutually exclusive with it.
  final String? selectedArrowId;

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

  /// Every other set of the sequence, in tab order.
  final List<OcptFloorPlanPlacementsOtherSet> otherSets;

  /// Whether the mode shows a project version being previewed read-only, withholding every
  /// affordance this group offers.
  final bool isReadOnly;

  /// Called with a symbol's id when its own remove action is clicked — only asks — or null while
  /// withheld.
  final ValueChanged<String>? onSymbolDeleteRequested;

  /// Called with an arrow's id when its own remove action is clicked — only asks — or null while
  /// withheld.
  final ValueChanged<String>? onArrowDeleteRequested;

  /// Called with a camera symbol's id and its new field-of-view angle (degrees) when the cameras
  /// section's own `−`/`+` stepper is clicked, or null while withheld.
  final void Function(String symbolId, double fovDeg)? onCameraFovChanged;

  /// Class constructor
  const OcptFloorPlanPlacementsGroup({
    super.key,
    required this.setName,
    required this.selectedSymbolId,
    required this.selectedArrowId,
    required this.cameras,
    required this.characters,
    required this.lights,
    required this.handProps,
    required this.arrows,
    required this.otherSets,
    required this.isReadOnly,
    required this.onSymbolDeleteRequested,
    required this.onArrowDeleteRequested,
    required this.onCameraFovChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr.shotListFloorPlanPlacementsGroupTitle(setName),
          style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
        ),
        const SizedBox(height: 8),
        _buildGroupHeader(context, tr.shotListFloorPlanSelectionGroupTitle),
        _buildSelectionSection(context, tr),
        const SizedBox(height: 8),
        _buildGroupHeader(context, tr.shotListFloorPlanOnThisShotGroupTitle),
        _buildCamerasSection(context, tr),
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
        if (otherSets.isNotEmpty) ...[
          Divider(color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 4),
          _buildGroupHeader(context, tr.shotListFloorPlanSetGroupTitle),
          for (final otherSet in otherSets)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                otherSet.cameraCount > 0
                    ? tr.shotListFloorPlanPlacementsOtherCaseHasCameraHint(
                        otherSet.setName,
                        otherSet.cameraCount,
                      )
                    : tr.shotListFloorPlanPlacementsOtherCaseNoCameraHint(otherSet.setName),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ],
    );
  }

  /// One of the group's three headed sections — **Selection**, **On this shot**, **Set** — a
  /// step up from the smaller subsection titles ([_buildSection]/[_buildCamerasSection]'s own
  /// `labelSmall`) so the three read as the group's own top-level structure.
  Widget _buildGroupHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  /// The **Selection** section's own body: [selectedSymbolId]'s or [selectedArrowId]'s own read-out
  /// among [cameras]/[characters]/[lights]/[handProps]/[arrows] — every one of them already this
  /// shot's own live placements, so the match is a plain lookup, no new data. A camera match reuses
  /// [_buildCameraRow] (its own field-of-view stepper included); every other match is a plain row.
  /// The nothing-selected hint shows while neither id names a placement this shot actually carries
  /// (nothing selected at all, or the selection belongs to another shot or a ghost).
  Widget _buildSelectionSection(BuildContext context, Tr tr) {
    final theme = Theme.of(context);
    final selectedSymbolId = this.selectedSymbolId;
    final selectedArrowId = this.selectedArrowId;

    if (selectedSymbolId != null) {
      for (final camera in cameras) {
        if (camera.symbolId == selectedSymbolId) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildCameraRow(context, tr, camera),
          );
        }
      }
      for (final symbol in [...characters, ...lights, ...handProps]) {
        if (symbol.symbolId == selectedSymbolId) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildRow(
              context,
              label: symbol.label,
              color: Color(symbol.colorArgb),
              onDeleteRequested: onSymbolDeleteRequested == null
                  ? null
                  : () => onSymbolDeleteRequested!(symbol.symbolId),
            ),
          );
        }
      }
    }

    if (selectedArrowId != null) {
      for (final arrow in arrows) {
        if (arrow.arrowId == selectedArrowId) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildRow(
              context,
              label: arrow.label.isEmpty ? tr.shotListFloorPlanPlacementsArrowRowLabel : arrow.label,
              onDeleteRequested: onArrowDeleteRequested == null
                  ? null
                  : () => onArrowDeleteRequested!(arrow.arrowId),
            ),
          );
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        tr.shotListFloorPlanSelectionNoneHint,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  /// The cameras section: its title, then one row per camera carrying its own field-of-view stepper
  /// next to its label and its remove action — the control the field-of-view feature adds
  /// alongside the generic [_buildSection] every other placement kind still uses.
  Widget _buildCamerasSection(BuildContext context, Tr tr) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr.shotListFloorPlanPlacementsCamerasSectionTitle,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (cameras.isEmpty)
            Text(
              tr.shotListFloorPlanPlacementsNoCameraHint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          else
            for (final camera in cameras) _buildCameraRow(context, tr, camera),
        ],
      ),
    );
  }

  /// One camera's own row: its colour swatch and derived label, the `−`/`+` field-of-view stepper
  /// (withheld under [isReadOnly] or while [onCameraFovChanged] is null), and its remove action.
  Widget _buildCameraRow(BuildContext context, Tr tr, OcptFloorPlanSymbolShape camera) {
    final theme = Theme.of(context);
    final onCameraFovChanged = this.onCameraFovChanged;
    final fovDeg = camera.fovDeg ?? ocptFloorPlanDefaultCameraFovDeg;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: Color(camera.colorArgb), shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(camera.cameraLabel ?? camera.label, style: theme.textTheme.bodySmall),
          ),
          if (onCameraFovChanged != null) ...[
            IconButton(
              iconSize: 14,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              tooltip: tr.shotListFloorPlanDecreaseFovAction,
              onPressed: fovDeg <= ocptFloorPlanMinCameraFovDeg
                  ? null
                  : () => onCameraFovChanged(
                      camera.symbolId,
                      (fovDeg - _fovStepDeg).clamp(
                        ocptFloorPlanMinCameraFovDeg,
                        ocptFloorPlanMaxCameraFovDeg,
                      ),
                    ),
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 34,
              child: Text(
                tr.shotListFloorPlanCameraFovValueLabel(fovDeg.round()),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
            IconButton(
              iconSize: 14,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              tooltip: tr.shotListFloorPlanIncreaseFovAction,
              onPressed: fovDeg >= ocptFloorPlanMaxCameraFovDeg
                  ? null
                  : () => onCameraFovChanged(
                      camera.symbolId,
                      (fovDeg + _fovStepDeg).clamp(
                        ocptFloorPlanMinCameraFovDeg,
                        ocptFloorPlanMaxCameraFovDeg,
                      ),
                    ),
              icon: const Icon(Icons.add),
            ),
          ],
          if (onSymbolDeleteRequested != null)
            IconButton(
              iconSize: 14,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: () => onSymbolDeleteRequested!(camera.symbolId),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
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

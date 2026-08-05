// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_breakdown_palette.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_scene.dart';
import 'package:open_cine_prod_tools/models/ocpt_breakdown_target.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/models/ocpt_person.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_editable_field.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_status.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/breakdown/widgets/ocpt_breakdown_choice_chip.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_person_picker.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/modes/resources/widgets/ocpt_resources_sheet_field.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_breakdown_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_legend.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_suggestions.dart';

/// One occurrence of the inspected target: a live tag, resolved out of [OcptBreakdownScene.tags],
/// carrying just what the occurrences section shows and jumps to.
class _OcptBreakdownOccurrence {
  /// The id of the scene this occurrence's tag is in — what a click jumps the script view and the
  /// left dock to.
  final String sceneId;

  /// The scene's own display number.
  final String sceneNumber;

  /// The scene's own heading.
  final String sceneHeading;

  /// The tagged passage, verbatim.
  final String extract;

  /// Class constructor
  const _OcptBreakdownOccurrence({
    required this.sceneId,
    required this.sceneNumber,
    required this.sceneHeading,
    required this.extract,
  });
}

/// The right dock's `Inspector` tab while a target is selected: a colour swatch and the target's
/// name, its category (or role/set kind) and scene count, then — **element targets only**, a role
/// or a set having neither a status nor the fields below — its status chips, its category chips and
/// its details (name, sub-category, quantity, notes, owner, who brings it), then every target's own
/// occurrences in the screenplay, its suggested ones (§3.4 of the plan this ships under: a repeated
/// occurrence is offered, never applied — [suggestions] read the same way [scenes] is, verbatim
/// passages the target inspector shows and, unless [isReadOnly], offers to tag), and the two
/// trailing actions every kind offers.
///
/// The name field is where an element tagged from the script is given the label it is read under
/// everywhere else: creating one from the popover names it after the passage it was tagged from,
/// which is the passage's wording rather than the production's — "crown" the word, not `Queen's
/// crown, act III`. Renaming it here renames the element itself, so the script's own tooltips, the
/// legend, the recap table and the resources mode all follow.
///
/// Purely presentational, like `OcptShotInspectorPanel`: the mode is the only caller, wiring every
/// callback to `OcptBreakdownBloc` events and resolving [fieldValueOf] from the bloc's own pending
/// element field edits. [scenes] — every scene of the loaded snapshot, in source order, each
/// carrying its own live tags — is read once, internally, to build the occurrences section: there is
/// no scroll-to-passage in this change, a click only selects the occurrence's own scene.
///
/// [isReadOnly] withholds every control that writes — the status and category chips, the three
/// fields, the two person pickers, a suggested occurrence's own add control and the tag-removal
/// action — while leaving every read (the sheet itself, the occurrences and the suggested
/// occurrences alike, and their jump, `Open in Resources`) in place, mirroring
/// `OcptShotInspectorPanel`'s own convention: the panel takes the real callbacks and nulls them out
/// itself, so a control added later cannot be gated in one place and forgotten in the other.
class OcptBreakdownTargetInspector extends StatelessWidget {
  /// The selected target.
  final OcptBreakdownTarget target;

  /// The raw `elements` row [target] resolves to, non-null only when [target] is an
  /// [OcptBreakdownTargetKind.element] — everything the Status, Category and Details sections read.
  final OcptElement? element;

  /// The person named by [element]'s own owner, or null while nobody of the address book is.
  /// Ignored while [element] is null.
  final OcptPerson? owner;

  /// The person named by [element]'s own who-brings-it, or null while nobody does. Ignored while
  /// [element] is null.
  final OcptPerson? bringer;

  /// The whole address book, offered by the owner and who-brings-it pickers. Ignored while
  /// [element] is null.
  final List<OcptPerson> people;

  /// Every scene of the loaded snapshot, in source order, each carrying its own live tags — read
  /// once to build the occurrences section.
  final List<OcptBreakdownScene> scenes;

  /// [element]'s current value for `field` — a pending edit still in the bloc's own debounce, or the
  /// element's own stored value. Ignored while [element] is null.
  final String Function(OcptElementField field) fieldValueOf;

  /// Called when the "back to the scene sheet" link at the top of the panel is clicked. Never
  /// withheld: it only clears the selection, which writes nothing.
  final VoidCallback onBackToSceneRequested;

  /// Called with the status just picked, or null while it may not be changed.
  final ValueChanged<OcptElementStatus>? onStatusChanged;

  /// Called with the category just picked, or null while it may not be changed.
  final ValueChanged<OcptElementCategory>? onCategoryChanged;

  /// Called with a field's raw text on every keystroke, or null while the sheet may not be written
  /// to.
  final void Function(OcptElementField field, String rawValue)? onFieldChanged;

  /// Called with the person who now owns [element], or null to clear it; itself null while it may
  /// not be changed.
  final ValueChanged<String?>? onOwnerChanged;

  /// Called with the person who now brings [element], or null to clear it; itself null while it may
  /// not be changed.
  final ValueChanged<String?>? onBringerChanged;

  /// Called with an occurrence's own scene id when its row is clicked. Never withheld: selecting a
  /// scene writes nothing.
  final ValueChanged<String> onOccurrenceSelected;

  /// [target]'s own suggested occurrences, already computed and filtered to it
  /// (`OcptBreakdownState.selectedTargetSuggestions`) — passages elsewhere in the screenplay that
  /// read like one of [target]'s own tags but are not tagged themselves. The "Suggested occurrences"
  /// section is shown directly under the occurrences section, in the same shape, when this is
  /// non-empty, and dropped entirely otherwise.
  final List<OcptBreakdownSuggestion> suggestions;

  /// Called with a suggestion when its own row's add control is clicked, tagging that passage; null
  /// while it may not be accepted. Its own row's click to jump to the scene
  /// ([onOccurrenceSelected]) is never withheld — only the write is.
  final ValueChanged<OcptBreakdownSuggestion>? onSuggestionAccepted;

  /// Called when `Open in Resources` is clicked. Never withheld: switching mode reads, it never
  /// writes. Does **not** pre-select [target] there — the resources mode has no deep-link entry
  /// point yet, so the user lands on whichever tab and record it last showed.
  final VoidCallback onOpenInResourcesRequested;

  /// Whether the inline "remove this target's tags from the selected scene" confirmation is shown
  /// in place of the `Remove from the breakdown` action.
  final bool isTagRemovalPending;

  /// Called when `Remove from the breakdown` is clicked, asking for confirmation; null while it may
  /// not be answered.
  final VoidCallback? onTagRemovalRequested;

  /// Called when the inline confirmation's own cancel is clicked; null under the same condition as
  /// [onTagRemovalRequested].
  final VoidCallback? onTagRemovalCancelled;

  /// Called when the inline confirmation's own answer is clicked, removing the tags for good; null
  /// under the same condition as [onTagRemovalRequested].
  final VoidCallback? onTagRemovalConfirmed;

  /// Whether what the mode shows is a project version being previewed read-only, which no callback
  /// of this panel may write through.
  final bool isReadOnly;

  /// Class constructor
  const OcptBreakdownTargetInspector({
    super.key,
    required this.target,
    required this.element,
    required this.owner,
    required this.bringer,
    required this.people,
    required this.scenes,
    required this.fieldValueOf,
    required this.onBackToSceneRequested,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onFieldChanged,
    required this.onOwnerChanged,
    required this.onBringerChanged,
    required this.onOccurrenceSelected,
    required this.suggestions,
    required this.onSuggestionAccepted,
    required this.onOpenInResourcesRequested,
    required this.isTagRemovalPending,
    required this.onTagRemovalRequested,
    required this.onTagRemovalCancelled,
    required this.onTagRemovalConfirmed,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);
    final element = this.element;
    final occurrences = _occurrencesOf();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        InkWell(
          onTap: onBackToSceneRequested,
          mouseCursor: ocptClickableCursor,
          child: Text(
            tr.breakdownInspectorBackToSceneAction,
            style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: Color(target.color),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_displayedName(element), style: theme.textTheme.titleSmall),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "${ocptBreakdownLegendKeyLabel(tr, ocptBreakdownLegendKeyOf(target))} · "
          "${tr.breakdownInspectorSceneCountLabel(target.sceneIds.length)}",
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),

        if (element != null) ...[
          _sectionTitle(context, tr.breakdownElementStatusSectionTitle),
          const SizedBox(height: 8),
          _buildStatusChips(context, element),
          const SizedBox(height: 16),

          _sectionTitle(context, tr.breakdownElementCategorySectionTitle),
          const SizedBox(height: 8),
          _buildCategoryGrid(context, element),
          const SizedBox(height: 16),

          _sectionTitle(context, tr.breakdownElementDetailsSectionTitle),
          const SizedBox(height: 8),
          _buildDetails(context, tr, element),
          const SizedBox(height: 16),
        ],

        _sectionTitle(context, tr.breakdownOccurrencesSectionTitle),
        const SizedBox(height: 8),
        _buildOccurrences(context, tr, occurrences),
        const SizedBox(height: 16),

        if (suggestions.isNotEmpty) ...[
          _sectionTitle(
            context,
            tr.breakdownSuggestedOccurrencesSectionTitle(suggestions.length),
          ),
          const SizedBox(height: 8),
          _buildSuggestedOccurrences(context, tr, suggestions),
          const SizedBox(height: 16),
        ],

        FilledButton(
          onPressed: onOpenInResourcesRequested,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(36)),
          child: Text(tr.breakdownOpenInResourcesAction),
        ),
        const SizedBox(height: 8),
        if (isTagRemovalPending)
          _buildTagRemovalConfirmation(context, theme, tr)
        else if (!isReadOnly)
          OutlinedButton(
            onPressed: onTagRemovalRequested,
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(36)),
            child: Text(tr.breakdownRemoveFromBreakdownAction),
          ),
      ],
    );
  }

  /// The status chips row, one per [OcptElementStatus], the current one filled.
  Widget _buildStatusChips(BuildContext context, OcptElement element) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final status in OcptElementStatus.values)
        OcptBreakdownChoiceChip(
          label: ocptElementStatusLabel(Tr.of(context), status),
          color: ocptElementStatusColor(context, status),
          isSelected: element.status == status,
          onTap: onStatusChanged == null ? null : () => onStatusChanged!(status),
        ),
    ],
  );

  /// The two-column category grid, each entry carrying its own palette swatch, the current one
  /// marked.
  Widget _buildCategoryGrid(BuildContext context, OcptElement element) {
    final tr = Tr.of(context);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 3.4,
      children: [
        for (final category in OcptElementCategory.values)
          _OcptBreakdownCategoryChip(
            label: ocptElementCategoryLabel(tr, category),
            swatchColor: Color(ocptBreakdownColorOf(kind: OcptBreakdownTargetKind.element, category: category)),
            isSelected: element.category == category,
            onTap: onCategoryChanged == null ? null : () => onCategoryChanged!(category),
          ),
      ],
    );
  }

  /// The name, sub-category, quantity and notes fields, then the owner and who-brings-it pickers.
  Widget _buildDetails(BuildContext context, Tr tr, OcptElement element) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      OcptResourcesSheetField(
        ownerId: element.id,
        label: tr.breakdownElementNameLabel,
        value: fieldValueOf(OcptElementField.name),
        onChanged: onFieldChanged == null
            ? null
            : (value) => onFieldChanged!(OcptElementField.name, value),
      ),
      const SizedBox(height: 10),
      OcptResourcesSheetField(
        ownerId: element.id,
        label: tr.resourcesElementSubCategoryLabel,
        value: fieldValueOf(OcptElementField.subCategory),
        onChanged: onFieldChanged == null
            ? null
            : (value) => onFieldChanged!(OcptElementField.subCategory, value),
      ),
      const SizedBox(height: 10),
      OcptResourcesSheetField(
        ownerId: element.id,
        label: tr.resourcesElementQuantityLabel,
        value: fieldValueOf(OcptElementField.quantity),
        onChanged: onFieldChanged == null
            ? null
            : (value) => onFieldChanged!(OcptElementField.quantity, value),
      ),
      const SizedBox(height: 10),
      OcptResourcesSheetField(
        ownerId: element.id,
        label: tr.breakdownElementNotesLabel,
        value: fieldValueOf(OcptElementField.notes),
        multiline: true,
        onChanged: onFieldChanged == null
            ? null
            : (value) => onFieldChanged!(OcptElementField.notes, value),
      ),
      const SizedBox(height: 10),
      OcptResourcesPersonPicker(
        people: people,
        selectedPerson: owner,
        label: tr.resourcesElementOwnerLabel,
        emptyLabel: tr.resourcesElementNoOwner,
        onChanged: onOwnerChanged,
      ),
      const SizedBox(height: 10),
      OcptResourcesPersonPicker(
        people: people,
        selectedPerson: bringer,
        label: tr.resourcesElementBringerLabel,
        emptyLabel: tr.resourcesElementNoBringer,
        onChanged: onBringerChanged,
      ),
    ],
  );

  /// The bordered list of [occurrences], each row clickable.
  Widget _buildOccurrences(BuildContext context, Tr tr, List<_OcptBreakdownOccurrence> occurrences) {
    final theme = Theme.of(context);

    if (occurrences.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < occurrences.length; i++)
            InkWell(
              onTap: () => onOccurrenceSelected(occurrences[i].sceneId),
              mouseCursor: ocptClickableCursor,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  border: i == occurrences.length - 1
                      ? null
                      : Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr.breakdownOccurrenceSceneLabel(
                        occurrences[i].sceneNumber,
                        occurrences[i].sceneHeading,
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "…${occurrences[i].extract}…",
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: ocptMonospaceFontFamily,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The bordered list of [suggestions], the same shape [_buildOccurrences] builds for the live
  /// occurrences above it, each row additionally carrying a trailing add control tagging that
  /// passage — withheld, as a null [onSuggestionAccepted], while [isReadOnly]. A row whose own scene
  /// has, somehow, disappeared from [scenes] (a stale suggestion racing a freshly loaded snapshot) is
  /// skipped rather than shown with nothing to head it.
  Widget _buildSuggestedOccurrences(
    BuildContext context,
    Tr tr,
    List<OcptBreakdownSuggestion> suggestions,
  ) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(ocptRadiusMedium),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < suggestions.length; i++)
            _buildSuggestedOccurrenceRow(
              context,
              theme,
              tr,
              suggestions[i],
              isLast: i == suggestions.length - 1,
            ),
        ],
      ),
    );
  }

  /// One row of [_buildSuggestedOccurrences]: [suggestion]'s own scene and passage, exactly as an
  /// occurrence row reads, plus a trailing add control.
  Widget _buildSuggestedOccurrenceRow(
    BuildContext context,
    ThemeData theme,
    Tr tr,
    OcptBreakdownSuggestion suggestion, {
    required bool isLast,
  }) {
    final scene = _sceneById(suggestion.sceneId);
    if (scene == null) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: () => onOccurrenceSelected(suggestion.sceneId),
      mouseCursor: ocptClickableCursor,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr.breakdownOccurrenceSceneLabel(scene.displayNumber, scene.heading),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "…${suggestion.text}…",
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: ocptMonospaceFontFamily,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (onSuggestionAccepted != null)
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                tooltip: tr.breakdownSuggestionAcceptAction,
                visualDensity: VisualDensity.compact,
                onPressed: () => onSuggestionAccepted!(suggestion),
              ),
          ],
        ),
      ),
    );
  }

  /// The scene of [scenes] whose id is [sceneId], or null while none is — a suggestion's own scene
  /// having disappeared from a snapshot rebuilt underneath.
  OcptBreakdownScene? _sceneById(String sceneId) {
    for (final scene in scenes) {
      if (scene.id == sceneId) {
        return scene;
      }
    }

    return null;
  }

  /// The inline "remove this target's tags from the selected scene" confirmation, replacing the
  /// `Remove from the breakdown` action.
  Widget _buildTagRemovalConfirmation(BuildContext context, ThemeData theme, Tr tr) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        tr.breakdownRemoveFromBreakdownConfirmMessage,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: onTagRemovalCancelled,
            child: Text(tr.breakdownRemoveFromBreakdownCancelAction),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: onTagRemovalConfirmed,
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            child: Text(tr.breakdownRemoveFromBreakdownConfirmAction),
          ),
        ],
      ),
    ],
  );

  /// [target]'s live occurrences, resolved out of [scenes] in scene order — each scene's own
  /// [OcptBreakdownScene.tags] already ordered by start offset, the order the passages are read in.
  List<_OcptBreakdownOccurrence> _occurrencesOf() => [
    for (final scene in scenes)
      for (final tag in scene.tags)
        if (tag.targetKind == target.kind && tag.targetId == target.id)
          _OcptBreakdownOccurrence(
            sceneId: scene.id,
            sceneNumber: scene.displayNumber,
            sceneHeading: scene.heading,
            extract: tag.taggedText,
          ),
  ];

  /// The name shown at the top of the panel: whatever the name field currently holds while
  /// [element] is one, so a rename reads back as it is typed rather than only once the field
  /// debounce has landed and the snapshot has been read again, and [OcptBreakdownTarget.name] in
  /// every other case — a role, a set, or an element whose name has just been emptied, which the
  /// panel would otherwise head with nothing at all.
  String _displayedName(OcptElement? element) {
    if (element == null) {
      return target.name;
    }

    final pendingName = fieldValueOf(OcptElementField.name).trim();
    return pendingName.isEmpty ? target.name : pendingName;
  }

  /// One section title, the accent-coloured header the mock-up uses to separate the panel's
  /// sections, mirroring `OcptShotInspectorPanel._sectionTitle`.
  Widget _sectionTitle(BuildContext context, String title) => Text(
    title,
    style: Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
  );
}

/// One entry of the two-column category grid: a swatch and a label, tinted when [isSelected].
class _OcptBreakdownCategoryChip extends StatelessWidget {
  /// The chip's own label.
  final String label;

  /// The category's own palette colour, shown as a small swatch.
  final Color swatchColor;

  /// Whether this is the currently selected category.
  final bool isSelected;

  /// Called when the chip is clicked, or null while it may not be picked.
  final VoidCallback? onTap;

  /// Class constructor
  const _OcptBreakdownCategoryChip({
    required this.label,
    required this.swatchColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      borderRadius: BorderRadius.circular(ocptRadiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(ocptRadiusSmall),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: swatchColor, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isSelected ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

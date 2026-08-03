// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

/// The minimum width of a row's code badge, so a column of them lines up whatever they hold.
const double _codeBadgeMinWidth = 40;

/// The separator between the two halves of a row's own muted second line.
const String _secondLineSeparator = " · ";

/// The elements catalogue: one row per [OcptElement], under a heading per category — the mock-up's
/// own grouping, and the only structure a flat list of forty items has.
///
/// A row carries the element's code as a badge, its name, a muted line saying how many of it are
/// needed and where it comes from, and its tracking state on the right, painted the colour that
/// state is painted everywhere else in the mode. That last column is why the list is worth
/// scanning at all: it is the elements still to secure that lose a shooting day, exactly as it is
/// the location still awaiting its permit.
///
/// The categories are shown in the enum's own order and **only when they hold something** — a
/// heading over nothing would say a production has a costume department it does not have. The
/// grouping is read-time work over the single flat `sortKey` order the catalogue is stored in (see
/// `OcptElementsService`): there is one order to maintain, not one per category.
class OcptElementsList extends StatelessWidget {
  /// The elements to list, in display order.
  final List<OcptElement> elements;

  /// The id of the selected element, or null if none is.
  final String? selectedElementId;

  /// Called with an element's id when its row is clicked.
  final ValueChanged<String> onElementSelected;

  /// Class constructor
  const OcptElementsList({
    super.key,
    required this.elements,
    required this.selectedElementId,
    required this.onElementSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (elements.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          Tr.of(context).resourcesElementsEmptyHint,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      );
    }

    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return ListView(
      children: [
        for (final category in OcptElementCategory.values)
          if (_elementsOf(category) case final categoryElements when categoryElements.isNotEmpty)
            ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  ocptElementCategoryLabel(tr, category).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              for (final element in categoryElements)
                _OcptElementEntry(
                  element: element,
                  isSelected: element.id == selectedElementId,
                  onTap: () => onElementSelected(element.id),
                ),
            ],
      ],
    );
  }

  /// The elements of [category], in the catalogue's own order.
  List<OcptElement> _elementsOf(OcptElementCategory category) => [
    for (final element in elements)
      if (element.category == category) element,
  ];
}

/// One row of [OcptElementsList].
class _OcptElementEntry extends StatelessWidget {
  /// The element this row shows.
  final OcptElement element;

  /// Whether this element is the selected one.
  final bool isSelected;

  /// Called when the row is clicked.
  final VoidCallback onTap;

  /// Class constructor
  const _OcptElementEntry({
    required this.element,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tr = Tr.of(context);

    return InkWell(
      onTap: onTap,
      mouseCursor: ocptClickableCursor,
      child: ColoredBox(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: ocptSelectedStateAlpha)
            : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              if (element.code.isNotEmpty) ...[
                Container(
                  constraints: const BoxConstraints(minWidth: _codeBadgeMinWidth),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(ocptRadiusSmall),
                  ),
                  child: Text(
                    element.code,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      element.name.isEmpty ? tr.resourcesElementUnnamed : element.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontStyle: element.name.isEmpty ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _secondLineOf(tr),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                ocptElementTrackingLabel(tr, element),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: ocptElementTrackingColor(context, element),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The row's muted second line: the production's own sub-category when it gave one, then how many
  /// of the element are needed and where it comes from.
  ///
  /// The empty halves are dropped rather than shown as a placeholder — a leading separator would
  /// read as a missing word, and the provenance alone is always worth stating, since it is what
  /// says whether anyone still has to do something about it.
  String _secondLineOf(Tr tr) => [
    if (element.subCategory.isNotEmpty) element.subCategory,
    if (element.quantity.isNotEmpty) element.quantity,
    ocptElementSourceKindLabel(tr, element.sourceKind),
  ].join(_secondLineSeparator);
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_budget_labels.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_resources_labels.dart';

/// The dialog's own fixed width, in logical pixels — wide enough for a name, its category and a
/// trailing cost without wrapping.
const double _ocptElementPickerWidth = 420;

/// The dialog's own fixed height, in logical pixels — a ceiling on the scrolling list, mirroring
/// `OcptCardChoiceDialog`'s own `_ocptCardChoiceMaxHeight` reading: a project with a handful of
/// unpriced elements opens a short dialog, one with hundreds scrolls within this rather than
/// growing past the window.
const double _ocptElementPickerHeight = 420;

/// Offers every breakdown element `OcptBudgetState.unpricedElements` names — every live element no
/// live quote line prices yet — picked by `OcptBudgetFiche`'s own `+ From breakdown`
/// action.
///
/// **A plain searchable list, not `OcptCardChoiceDialog`'s own two-column card grid.** That dialog
/// is built for a handful of fixed choices (a mode's own document kinds); a project's own elements
/// catalogue can run into the hundreds, so this offers a search field over a scrolling list instead
/// — the same problem `OcptBreakdownTagPopover`'s own search field already answers, for the very
/// same reason.
///
/// It only asks: picking an available row pops with the [OcptElement] itself, through
/// `OcptRouterManager.pop`, never `Navigator`. It knows nothing about what the caller then does with
/// the pick — `OcptBudgetBloc._onLineCreatedFromElement` is what turns it into a fresh quote line,
/// once this dialog is already on its way out of the tree.
class OcptBudgetElementPickerDialog extends StatefulWidget {
  /// Every element offered — `OcptBudgetState.unpricedElements`, already filtered down to the ones
  /// no live quote line prices yet: this dialog does no filtering of its own kind, only the text
  /// search over what it was handed.
  final List<OcptElement> elements;

  /// The project's currency, an ISO 4217 code, shown beside a priced element's own trailing figure.
  final String currencyCode;

  /// Class constructor
  const OcptBudgetElementPickerDialog({super.key, required this.elements, required this.currencyCode});

  /// Shows the dialog and returns the element picked, or null if the user cancelled it.
  static Future<OcptElement?> show(
    BuildContext context, {
    required List<OcptElement> elements,
    required String currencyCode,
  }) => showDialog<OcptElement>(
    context: context,
    builder: (context) =>
        OcptBudgetElementPickerDialog(elements: elements, currencyCode: currencyCode),
  );

  @override
  State<OcptBudgetElementPickerDialog> createState() => _OcptBudgetElementPickerDialogState();
}

/// The state of [OcptBudgetElementPickerDialog]: owns the search field's own typed text.
class _OcptBudgetElementPickerDialogState extends State<OcptBudgetElementPickerDialog> {
  /// The search field's own current text, lower-cased once here rather than on every element
  /// filtered against it.
  String _query = "";

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.elements
        : [for (final element in widget.elements) if (element.name.toLowerCase().contains(query)) element];

    return AlertDialog(
      title: Text(tr.budgetLineFromElementDialogTitle),
      content: SizedBox(
        width: _ocptElementPickerWidth,
        height: _ocptElementPickerHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: tr.budgetLineFromElementSearchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          tr.budgetLineFromElementEmptyHint,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) => _OcptElementPickerRow(
                        element: filtered[index],
                        currencyCode: widget.currencyCode,
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => globalGetIt().get<OcptRouterManager>().pop<OcptElement>(),
          child: Text(tr.budgetEntryDialogCancelAction),
        ),
      ],
    );
  }
}

/// One row of [OcptBudgetElementPickerDialog]: the element's own name, its category underneath, and
/// its own cost trailing — [ocptBudgetEmptyValue] rather than a claimed zero while
/// [OcptElement.cost] is null, the same reading every other unpriced figure of this mode already
/// carries.
class _OcptElementPickerRow extends StatelessWidget {
  /// The element this row offers.
  final OcptElement element;

  /// The project's currency, an ISO 4217 code.
  final String currencyCode;

  /// Class constructor
  const _OcptElementPickerRow({required this.element, required this.currencyCode});

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final cost = element.cost;

    return ListTile(
      title: Text(element.name.isEmpty ? tr.resourcesElementUnnamed : element.name),
      subtitle: Text(ocptElementCategoryLabel(tr, element.category)),
      trailing: Text(cost == null ? ocptBudgetEmptyValue : ocptBudgetAmountLabel(cost, currencyCode)),
      onTap: () => globalGetIt().get<OcptRouterManager>().pop<OcptElement>(element),
    );
  }
}

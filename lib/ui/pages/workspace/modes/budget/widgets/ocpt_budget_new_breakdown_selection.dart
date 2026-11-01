// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_new_outcome.dart';
import 'package:open_cine_prod_tools/models/ocpt_element.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_budget_labels.dart';

/// What the wizard's breakdown selector (`addQuoteLinesFromBreakdown`) holds: the checked
/// elements, their quantities, the poste each will be filed under and the search text.
///
/// The wizard's state owns one instance and calls [dispose] with its own, so the quantity
/// controllers live exactly as long as the dialog does, whichever rows are on screen.
class OcptBudgetNewBreakdownSelection {
  /// The ids of the breakdown elements currently checked.
  final Set<String> selectedIds = {};

  /// The quantity of each checked element, in thousandths, keyed by element id.
  final Map<String, int> quantityMilliByElementId = {};

  /// The quantity field controller of each element met so far, keyed by element id.
  final Map<String, TextEditingController> _quantityControllers = {};

  /// The poste a row was individually filed under, overriding [bulkPosteId] — keyed by element id,
  /// absent while the row still follows the bulk default.
  final Map<String, String> _posteOverrideByElementId = {};

  /// The search text.
  String query = "";

  /// The poste every row inherits until it is given one of its own — the `File all under`
  /// header's own answer, and the default half of [posteFor].
  String? bulkPosteId;

  /// Class constructor
  OcptBudgetNewBreakdownSelection();

  /// The quantity field controller of [element], created on first request.
  TextEditingController quantityControllerOf(OcptElement element) =>
      _quantityControllers.putIfAbsent(
        element.id,
        () => TextEditingController(text: ocptBudgetQuantityLabel(defaultQuantityMilliOf(element))),
      );

  /// The quantity a fresh row is born with, in thousandths — the number of scenes [element]
  /// appears in. A suggestion, never a truth: right for a rostrum hired by the day, wrong for a
  /// backdrop built once, corrected in the table before creating rather than decided by the app.
  int defaultQuantityMilliOf(OcptElement element) =>
      (element.sceneLinks.isEmpty ? 1 : element.sceneLinks.length) * 1000;

  /// Checks or unchecks [element], remembering the quantity its row currently reads when it is
  /// checked.
  void setChecked(OcptElement element, {required bool isChecked}) {
    final controller = quantityControllerOf(element);
    if (isChecked) {
      selectedIds.add(element.id);
      quantityMilliByElementId[element.id] =
          ocptBudgetQuantityMilliOf(controller.text) ?? defaultQuantityMilliOf(element);
    } else {
      selectedIds.remove(element.id);
      quantityMilliByElementId.remove(element.id);
    }
  }

  /// Files every row under [posteId], clearing the per-row overrides: `File all under X` is a
  /// promise about every row, so everything really lands in X, ready to be re-filed one by one
  /// after.
  void setBulkPoste(String? posteId) {
    bulkPosteId = posteId;
    _posteOverrideByElementId.clear();
  }

  /// Files the row of [elementId] under [posteId], ignoring a null pick.
  void setPosteOverride(String elementId, String? posteId) {
    if (posteId != null) {
      _posteOverrideByElementId[elementId] = posteId;
    }
  }

  /// Records the quantity the row of [elementId] now reads, ignoring text that is not a number.
  void setQuantityText(String elementId, String value) {
    final quantityMilli = ocptBudgetQuantityMilliOf(value);
    if (quantityMilli != null) {
      quantityMilliByElementId[elementId] = quantityMilli;
    }
  }

  /// The poste breakdown row [elementId] will be filed under: its own override if it has one, else
  /// the bulk default — null while neither has been chosen, which is what keeps its line from being
  /// created.
  String? posteFor(String elementId) => _posteOverrideByElementId[elementId] ?? bulkPosteId;

  /// Whether lines can be created: something is checked and every checked element resolves to a
  /// poste — its own or the bulk default. A line with no poste is a row the quote has nowhere to
  /// file.
  bool get isReady => selectedIds.isNotEmpty && selectedIds.every((id) => posteFor(id) != null);

  /// The outcome creating the checked lines ends in, or null while nothing is checked or a checked
  /// row resolves no poste — [isReady] already withholds the button then, so this is the belt to
  /// that braces.
  OcptBudgetNewLinesFromBreakdownOutcome? outcome() {
    if (selectedIds.isEmpty) {
      return null;
    }

    final lines = <({String elementId, String posteId, int quantityMilli})>[];
    for (final elementId in selectedIds) {
      final posteId = posteFor(elementId);
      if (posteId == null) {
        return null;
      }
      lines.add((
        elementId: elementId,
        posteId: posteId,
        quantityMilli: quantityMilliByElementId[elementId] ?? 1000,
      ));
    }

    return OcptBudgetNewLinesFromBreakdownOutcome(lines: lines);
  }

  /// Disposes every quantity controller.
  void dispose() {
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
  }
}

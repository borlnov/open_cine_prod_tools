// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/utils/ocpt_budget_vat.dart';
import 'package:open_cine_prod_tools/utils/ocpt_cost_amount.dart';

/// The project settings page's "Budget defaults" section card: the project's default VAT rate, the
/// price of one meal and the price of one snack (`project_info.defaultVatRateBasisPoints`,
/// `mealPriceCents`, `snackPriceCents`) — the currency card's own doc comment announced this
/// neighbour, and here it is.
///
/// All three are optional and read the same way `minimumRestMinutes` already does: null means
/// nobody has recorded a figure, not that none applies, and nothing here is ever pre-filled with a
/// figure this app has not been told to advance (ADR 0027). The budget mode's
/// own views read all three once they ship — the VAT rate as the fallback every unpriced quote line
/// inherits, the two catering prices as the unit costs `ocpt_budget_regie.dart` multiplies the
/// schedule's own head counts by.
class OcptProjectSettingsBudgetSection extends StatelessWidget {
  /// The project's current default VAT rate, in basis points (`2000` is 20 %, `550` is 5.5 %), or
  /// null while nobody has recorded one.
  final int? defaultVatRateBasisPoints;

  /// Called with the newly committed rate, in basis points, or null to put it back to "not
  /// recorded" — whether typed as `0` (a real exemption) or through the `No rate` button.
  final ValueChanged<int?> onDefaultVatRateBasisPointsChanged;

  /// The project's current price of one meal, in cents, or null while nobody has recorded one.
  final int? mealPriceCents;

  /// Called with the newly committed meal price, in cents, or null to clear it.
  final ValueChanged<int?> onMealPriceCentsChanged;

  /// The project's current price of one snack, in cents, or null while nobody has recorded one.
  final int? snackPriceCents;

  /// Called with the newly committed snack price, in cents, or null to clear it.
  final ValueChanged<int?> onSnackPriceCentsChanged;

  /// The current project's currency, an ISO 4217 code, shown as both money fields' suffix.
  final String currencyCode;

  /// Class constructor
  const OcptProjectSettingsBudgetSection({
    required this.defaultVatRateBasisPoints,
    required this.onDefaultVatRateBasisPointsChanged,
    required this.mealPriceCents,
    required this.onMealPriceCentsChanged,
    required this.snackPriceCents,
    required this.onSnackPriceCentsChanged,
    required this.currencyCode,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final currencySymbol = NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr.projectSettingsBudgetSectionTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(tr.projectSettingsBudgetVatRateLabel)),
                _OcptProjectSettingsVatRateField(
                  basisPoints: defaultVatRateBasisPoints,
                  onChanged: onDefaultVatRateBasisPointsChanged,
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => onDefaultVatRateBasisPointsChanged(null),
                  child: Text(tr.projectSettingsBudgetVatRateNoRateAction),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tr.projectSettingsBudgetVatRateHint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text(tr.projectSettingsBudgetMealPriceLabel)),
                _OcptProjectSettingsBudgetMoneyField(
                  cents: mealPriceCents,
                  suffixText: currencySymbol,
                  onChanged: onMealPriceCentsChanged,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(tr.projectSettingsBudgetSnackPriceLabel)),
                _OcptProjectSettingsBudgetMoneyField(
                  cents: snackPriceCents,
                  suffixText: currencySymbol,
                  onChanged: onSnackPriceCentsChanged,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tr.projectSettingsBudgetCateringPriceHint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// The default VAT rate field: typed in per cent, committed on submit or focus loss, and read back
/// as the very digits [ocptVatRatePercentTextOf] writes —
/// `_OcptProjectSettingsMinimumRestField`'s own idiom
/// (`ocpt_project_settings_minimum_rest_section.dart`), with the one difference the card's own doc
/// comment argues: an **empty** submission here reverts the field instead of clearing the rate, for
/// the same reason a negative one does — since `0` is already the field's own way of stating a real
/// exemption, "not recorded" needs an affordance of its own (the `No rate` button beside it) rather
/// than being read off an empty text a stray keystroke could produce by accident.
///
/// The unit is worn as the field's `suffixText` rather than written into the text, so what a
/// committed field holds is always something it accepts back: a value read back as `20 %` could
/// never be edited into `21 %` again, every such submission parsing as nothing at all and reverting
/// to what was there before.
class _OcptProjectSettingsVatRateField extends StatefulWidget {
  /// The project's current default VAT rate, in basis points, or null while unset.
  final int? basisPoints;

  /// Called with the basis points just committed. Never called with null — the `No rate` button
  /// beside this field is the only thing that reports null, this field's own empty submission being
  /// a revert rather than a clear (see the class doc comment).
  final ValueChanged<int?> onChanged;

  /// Class constructor
  const _OcptProjectSettingsVatRateField({required this.basisPoints, required this.onChanged});

  @override
  State<_OcptProjectSettingsVatRateField> createState() => _OcptProjectSettingsVatRateFieldState();
}

/// The state of [_OcptProjectSettingsVatRateField]: owns the controller and the
/// commit-on-submit-or-focus-loss idiom.
class _OcptProjectSettingsVatRateFieldState extends State<_OcptProjectSettingsVatRateField> {
  /// The field's own text controller, seeded from [_OcptProjectSettingsVatRateField.basisPoints]'s
  /// own formatted reading.
  late final TextEditingController _controller = TextEditingController(text: _formatted);

  /// The field's own focus node, committing the moment it loses focus.
  final FocusNode _focusNode = FocusNode();

  /// The value this field last reported — compared against on every commit rather than
  /// [_OcptProjectSettingsVatRateField.basisPoints] itself, so a submission's own focus loss never
  /// commits the very same edit twice (`_OcptProjectSettingsMinimumRestField`'s own reasoning).
  late int? _lastReportedBasisPoints = widget.basisPoints;

  /// [_OcptProjectSettingsVatRateField.basisPoints] written in per cent through
  /// [ocptVatRatePercentTextOf], or the empty string while it is null.
  String get _formatted => ocptVatRatePercentTextOf(widget.basisPoints);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _OcptProjectSettingsVatRateField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.basisPoints != widget.basisPoints) {
      _lastReportedBasisPoints = widget.basisPoints;
      if (!_focusNode.hasFocus) {
        _controller.text = _formatted;
      }
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Commits the field's current text once it loses focus.
  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _commit();
    }
  }

  /// Parses the field's current text as a rate in per cent and reports the basis points it makes:
  /// a non-negative figure, `0` included, is reported and read back in the canonical per cent
  /// writing; an empty, unparseable or negative text reverts the field to whatever was last
  /// committed instead — "not recorded" is put back only through the card's own `No rate` button.
  void _commit() {
    final basisPoints = ocptVatRateBasisPointsOf(_controller.text.trim());
    if (basisPoints == null) {
      _controller.text = _formatted;
      return;
    }

    _controller.text = ocptVatRatePercentTextOf(basisPoints);
    if (basisPoints != _lastReportedBasisPoints) {
      _lastReportedBasisPoints = basisPoints;
      widget.onChanged(basisPoints);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return SizedBox(
      width: 88,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onSubmitted: (_) => _commit(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        style: theme.textTheme.bodySmall,
        decoration: InputDecoration(
          isDense: true,
          hintText: tr.projectSettingsBudgetVatRateFieldHint,
          suffixText: tr.projectSettingsBudgetVatRateSuffix,
        ),
      ),
    );
  }
}

/// One of the card's two money fields (meal price, snack price): typed and read back through
/// [ocptCostTextOf]/[ocptCostCentsOf], committed on submit or focus loss —
/// `_OcptProjectSettingsMinimumRestField`'s own idiom, with an **empty** submission a legal clearing
/// gesture exactly as that field's own is, since neither price has a `0` reading to be confused
/// with "not recorded" the way the VAT rate does.
///
/// The currency symbol is worn as the field's own `suffixText`, `OcptElementSheetSourcingCard`'s own
/// reasoning for its cost field: what a committed field holds is always something it accepts back.
class _OcptProjectSettingsBudgetMoneyField extends StatefulWidget {
  /// The project's current price, in cents, or null while unset.
  final int? cents;

  /// The currency symbol shown as the field's `suffixText`.
  final String suffixText;

  /// Called with the price just committed, or null when the field was submitted empty.
  final ValueChanged<int?> onChanged;

  /// Class constructor
  const _OcptProjectSettingsBudgetMoneyField({
    required this.cents,
    required this.suffixText,
    required this.onChanged,
  });

  @override
  State<_OcptProjectSettingsBudgetMoneyField> createState() =>
      _OcptProjectSettingsBudgetMoneyFieldState();
}

/// The state of [_OcptProjectSettingsBudgetMoneyField]: owns the controller and the
/// commit-on-submit-or-focus-loss idiom.
class _OcptProjectSettingsBudgetMoneyFieldState extends State<_OcptProjectSettingsBudgetMoneyField> {
  /// The field's own text controller, seeded from [_OcptProjectSettingsBudgetMoneyField.cents]'s own
  /// formatted reading.
  late final TextEditingController _controller = TextEditingController(text: _formatted);

  /// The field's own focus node, committing the moment it loses focus.
  final FocusNode _focusNode = FocusNode();

  /// The value this field last reported — compared against on every commit rather than
  /// [_OcptProjectSettingsBudgetMoneyField.cents] itself, so a submission's own focus loss never
  /// commits the very same edit twice.
  late int? _lastReportedCents = widget.cents;

  /// [_OcptProjectSettingsBudgetMoneyField.cents] written through [ocptCostTextOf], or the empty
  /// string while it is null.
  String get _formatted => ocptCostTextOf(widget.cents);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _OcptProjectSettingsBudgetMoneyField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.cents != widget.cents) {
      _lastReportedCents = widget.cents;
      if (!_focusNode.hasFocus) {
        _controller.text = _formatted;
      }
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Commits the field's current text once it loses focus.
  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      _commit();
    }
  }

  /// Parses the field's current text as money and reports the cents it makes: empty clears the
  /// price (a real gesture, reported as null), a parseable figure is reported and read back in the
  /// canonical writing, and anything unparseable reverts the field to whatever was last committed.
  void _commit() {
    final text = _controller.text.trim();

    if (text.isEmpty) {
      _controller.text = "";
      if (_lastReportedCents != null) {
        _lastReportedCents = null;
        widget.onChanged(null);
      }
      return;
    }

    final parsed = ocptCostCentsOf(text);
    if (parsed == null) {
      _controller.text = _formatted;
      return;
    }

    _controller.text = ocptCostTextOf(parsed);
    if (parsed != _lastReportedCents) {
      _lastReportedCents = parsed;
      widget.onChanged(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 110,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onSubmitted: (_) => _commit(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: theme.textTheme.bodySmall,
        decoration: InputDecoration(isDense: true, suffixText: widget.suffixText),
      ),
    );
  }
}

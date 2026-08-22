// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/models/ocpt_budget_mileage_rate.dart';
import 'package:open_cine_prod_tools/utils/ocpt_mileage_rate_amount.dart';

/// The project settings page's "Mileage rates" section card, beside
/// `OcptProjectSettingsBudgetSection`: the per-kilometre reimbursement rates
/// (`budget_mileage_rates`) the production names for itself — "Car", "Production van",
/// "Motorbike" — each a label and a rate typed to three decimals
/// (`OcptBudgetMileageRatesTable.ratePerKmMilliCents`'s own doc comment for why).
///
/// **This app ships no rate of its own, and this card offers no example, not even a greyed
/// one.** A mileage scale is a legal figure that differs by country and by vehicle, and advancing
/// one — even as a placeholder nobody is meant to keep — would be this app stating a figure
/// nobody here validated, exactly the argument `project_info.minimumRestMinutes` already settled
/// for a single column, generalised here to a whole table. An empty card therefore shows a short
/// explanation instead of a first row, never a pre-filled suggestion.
class OcptProjectSettingsMileageRatesSection extends StatelessWidget {
  /// The project's own mileage rates, in `sortKey` order.
  final List<OcptBudgetMileageRate> mileageRates;

  /// The current project's currency, an ISO 4217 code, shown as each rate field's suffix.
  final String currencyCode;

  /// Called when `Add a rate` is tapped.
  final VoidCallback onRateAdded;

  /// Called with a rate's id and the label just committed for it.
  final void Function(String rateId, String label) onRateLabelChanged;

  /// Called with a rate's id and the per-kilometre rate just committed for it, in thousandths of a
  /// cent.
  final void Function(String rateId, int ratePerKmMilliCents) onRateAmountChanged;

  /// Called with the rate a row's delete action was clicked for. The page opens
  /// `OcptConfirmDialog` from this callback — this widget only ever asks.
  final ValueChanged<OcptBudgetMileageRate> onRateDeletionRequested;

  /// Class constructor
  const OcptProjectSettingsMileageRatesSection({
    required this.mileageRates,
    required this.currencyCode,
    required this.onRateAdded,
    required this.onRateLabelChanged,
    required this.onRateAmountChanged,
    required this.onRateDeletionRequested,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);
    final currencySymbol = NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;
    final suffix = "$currencySymbol/km";

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr.projectSettingsMileageRatesSectionTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (mileageRates.isEmpty)
              Text(
                tr.projectSettingsMileageRatesEmptyHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (var index = 0; index < mileageRates.length; index++) ...[
                if (index > 0) const SizedBox(height: 4),
                _OcptProjectSettingsMileageRateRow(
                  key: ValueKey(mileageRates[index].id),
                  rate: mileageRates[index],
                  suffixText: suffix,
                  onLabelChanged: (label) => onRateLabelChanged(mileageRates[index].id, label),
                  onAmountChanged: (ratePerKmMilliCents) =>
                      onRateAmountChanged(mileageRates[index].id, ratePerKmMilliCents),
                  onDeleteRequested: () => onRateDeletionRequested(mileageRates[index]),
                ),
              ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onRateAdded,
                child: Text(tr.projectSettingsMileageRateAddAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of [OcptProjectSettingsMileageRatesSection]: the label and rate fields follow this
/// page's own committed-edit idiom (`_OcptProjectSettingsEpisodeRow`'s own doc comment) —
/// committed on submit or focus loss, never on every keystroke, and guarded against reporting the
/// same edit twice.
class _OcptProjectSettingsMileageRateRow extends StatefulWidget {
  /// The rate this row shows.
  final OcptBudgetMileageRate rate;

  /// The rate field's `suffixText`, the project's currency over a kilometre.
  final String suffixText;

  /// Called with the label just committed.
  final ValueChanged<String> onLabelChanged;

  /// Called with the rate just committed, in thousandths of a cent.
  final ValueChanged<int> onAmountChanged;

  /// Deletes this rate.
  final VoidCallback onDeleteRequested;

  /// Class constructor
  const _OcptProjectSettingsMileageRateRow({
    required this.rate,
    required this.suffixText,
    required this.onLabelChanged,
    required this.onAmountChanged,
    required this.onDeleteRequested,
    super.key,
  });

  @override
  State<_OcptProjectSettingsMileageRateRow> createState() =>
      _OcptProjectSettingsMileageRateRowState();
}

/// The state of [_OcptProjectSettingsMileageRateRow]: owns the two controllers and the
/// commit-on-submit-or-focus-loss idiom for both fields.
class _OcptProjectSettingsMileageRateRowState extends State<_OcptProjectSettingsMileageRateRow> {
  /// The label field's own controller, seeded from [_OcptProjectSettingsMileageRateRow.rate].
  late final TextEditingController _labelController = TextEditingController(
    text: widget.rate.label,
  );

  /// The rate field's own controller, seeded from [_OcptProjectSettingsMileageRateRow.rate]'s own
  /// formatted reading.
  late final TextEditingController _rateController = TextEditingController(text: _formattedRate);

  /// The label field's own focus node, committing the moment it loses focus.
  final FocusNode _labelFocusNode = FocusNode();

  /// The rate field's own focus node, committing the moment it loses focus.
  final FocusNode _rateFocusNode = FocusNode();

  /// The label this row last reported, compared against on every commit rather than
  /// [_OcptProjectSettingsMileageRateRow.rate]'s own label, so a submission's own focus loss never
  /// commits the very same edit twice.
  late String _lastReportedLabel = widget.rate.label;

  /// The rate this row last reported, in thousandths of a cent, compared against the same way
  /// [_lastReportedLabel] is.
  late int _lastReportedRatePerKmMilliCents = widget.rate.ratePerKmMilliCents;

  /// [_OcptProjectSettingsMileageRateRow.rate]'s own rate written through [ocptMileageRateTextOf].
  String get _formattedRate => ocptMileageRateTextOf(widget.rate.ratePerKmMilliCents);

  @override
  void initState() {
    super.initState();
    _labelFocusNode.addListener(_onLabelFocusChanged);
    _rateFocusNode.addListener(_onRateFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _OcptProjectSettingsMileageRateRow oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.rate.label != widget.rate.label) {
      _lastReportedLabel = widget.rate.label;
      if (!_labelFocusNode.hasFocus) {
        _labelController.text = widget.rate.label;
      }
    }
    if (oldWidget.rate.ratePerKmMilliCents != widget.rate.ratePerKmMilliCents) {
      _lastReportedRatePerKmMilliCents = widget.rate.ratePerKmMilliCents;
      if (!_rateFocusNode.hasFocus) {
        _rateController.text = _formattedRate;
      }
    }
  }

  @override
  void dispose() {
    _labelFocusNode
      ..removeListener(_onLabelFocusChanged)
      ..dispose();
    _rateFocusNode
      ..removeListener(_onRateFocusChanged)
      ..dispose();
    _labelController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  /// Commits the label field's current text once it loses focus.
  void _onLabelFocusChanged() {
    if (!_labelFocusNode.hasFocus) {
      _commitLabel();
    }
  }

  /// Commits the rate field's current text once it loses focus.
  void _onRateFocusChanged() {
    if (!_rateFocusNode.hasFocus) {
      _commitRate();
    }
  }

  /// Reports the label field's current text: any string is legal, the empty one included, exactly
  /// as an episode's title is.
  void _commitLabel() {
    final text = _labelController.text;
    if (text != _lastReportedLabel) {
      _lastReportedLabel = text;
      widget.onLabelChanged(text);
    }
  }

  /// Parses the rate field's current text and reports it, in thousandths of a cent: an empty or
  /// unparseable text reverts the field to whatever was last committed —
  /// `ratePerKmMilliCents` is never nullable, so there is no "clear" gesture here, only "not typed
  /// yet" reverting to the figure already stored.
  void _commitRate() {
    final parsed = ocptMileageRateMilliCentsOf(_rateController.text.trim());
    if (parsed == null) {
      _rateController.text = _formattedRate;
      return;
    }

    _rateController.text = ocptMileageRateTextOf(parsed);
    if (parsed != _lastReportedRatePerKmMilliCents) {
      _lastReportedRatePerKmMilliCents = parsed;
      widget.onAmountChanged(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _labelController,
            focusNode: _labelFocusNode,
            onSubmitted: (_) => _commitLabel(),
            style: theme.textTheme.bodySmall,
            decoration: InputDecoration(
              isDense: true,
              hintText: tr.projectSettingsMileageRateLabelHint,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 110,
          child: TextField(
            controller: _rateController,
            focusNode: _rateFocusNode,
            onSubmitted: (_) => _commitRate(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: theme.textTheme.bodySmall,
            decoration: InputDecoration(isDense: true, suffixText: widget.suffixText),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          tooltip: tr.projectSettingsMileageRateDeleteTooltip,
          visualDensity: VisualDensity.compact,
          onPressed: widget.onDeleteRequested,
        ),
      ],
    );
  }
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:open_cine_prod_tools/constants/ocpt_currency_codes.dart';
import 'package:open_cine_prod_tools/constants/ocpt_theme.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The project settings page's "Currency" section card: a single dropdown over
/// [ocptCurrencyCodes].
///
/// A card of its own, immediately followed by `OcptProjectSettingsBudgetSection`: currency is a
/// budget concern before it is anything else.
class OcptProjectSettingsCurrencySection extends StatelessWidget {
  /// The currency code currently selected, an ISO 4217 code.
  final String currencyCode;

  /// Called when the user picks a different currency.
  final ValueChanged<String> onCurrencyCodeChanged;

  /// Class constructor
  const OcptProjectSettingsCurrencySection({
    required this.currencyCode,
    required this.onCurrencyCodeChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr.projectSettingsCurrencySectionTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text(tr.projectSettingsCurrencyLabel)),
                DropdownButton<String>(
                  value: currencyCode,
                  onChanged: (value) {
                    if (value != null) {
                      onCurrencyCodeChanged(value);
                    }
                  },
                  mouseCursor: ocptClickableCursor,
                  // The current code is folded in even when it isn't one of the seven curated
                  // ones: a project created before this page shipped may have been seeded from a
                  // device locale `ocptCurrencyCodes` doesn't offer, and `DropdownButton` requires
                  // its value to match exactly one item.
                  items: [
                    for (final code in {...ocptCurrencyCodes, currencyCode})
                      DropdownMenuItem(value: code, child: Text(_currencyLabel(code))),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The label shown for [code] in the picker: the code itself and its symbol, e.g. `EUR — €`.
  ///
  /// Both come from `intl`'s own currency table rather than an ARB key: the codes are data, and
  /// `intl` already knows how to present them in every supported locale.
  String _currencyLabel(String code) =>
      "$code — ${NumberFormat.simpleCurrency(name: code).currencySymbol}";
}

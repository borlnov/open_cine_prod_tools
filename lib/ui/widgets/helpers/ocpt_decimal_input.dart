// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/services.dart';

/// What a field restricted to a decimal number may hold **while it is being typed**: digits, at
/// most one separator, and nothing else.
///
/// Deliberately looser than a complete number: `12.`, `,` and the empty string all match, because
/// they are all states a field passes through on the way to a value, and a formatter that refused
/// them would refuse the keystroke that produces them. Both separators are accepted for the reason
/// `ocptCostCentsOf` accepts both — the app ships in `en_GB` and in French, and the same user
/// switches keyboards.
final RegExp _partialDecimalPattern = RegExp(r"^\d*[.,]?\d*$");

/// Keeps a text field to a decimal number: anything else the user types or pastes is refused, and
/// the field keeps the value it already had.
///
/// This is a **gate, unlike the rest of the resources sheets**, which flag a value without refusing
/// it (`ocptEmailFormatError`, the cost field). The difference is what a rejected keystroke costs:
/// half a typed email address is a value on its way to being correct and must be storable, whereas
/// a letter in a quantity field is never on its way to anything — there is no number it could be
/// the beginning of.
class OcptDecimalTextInputFormatter extends TextInputFormatter {
  /// Class constructor
  const OcptDecimalTextInputFormatter();

  /// {@macro flutter.services.TextInputFormatter.formatEditUpdate}
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      _partialDecimalPattern.hasMatch(newValue.text) ? newValue : oldValue;
}

/// The formatters every field holding a decimal number installs — the element catalogue's quantity
/// and the per-scene quantity of a breakdown link, which must not be able to disagree about what
/// they accept.
const List<TextInputFormatter> ocptDecimalInputFormatters = [OcptDecimalTextInputFormatter()];

/// The keyboard those same fields ask for, so a phone or a tablet opens the numeric one rather than
/// the full keyboard.
const TextInputType ocptDecimalKeyboardType = TextInputType.numberWithOptions(decimal: true);

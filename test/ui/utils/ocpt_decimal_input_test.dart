// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_decimal_input.dart';

/// What the field holds after [formatter] has been offered [newText] over [oldText].
String _formatted({
  required OcptDecimalTextInputFormatter formatter,
  required String oldText,
  required String newText,
}) => formatter
    .formatEditUpdate(
      TextEditingValue(text: oldText, selection: TextSelection.collapsed(offset: oldText.length)),
      TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: newText.length)),
    )
    .text;

void main() {
  const formatter = OcptDecimalTextInputFormatter();

  group("OcptDecimalTextInputFormatter", () {
    test("accepts a whole number and a decimal one", () {
      for (final text in const ["", "3", "12", "12.5", "12,5", "0.75"]) {
        expect(
          _formatted(formatter: formatter, oldText: "", newText: text),
          text,
          reason: "$text is a number",
        );
      }
    });

    test("accepts the states a number passes through while being typed", () {
      // A formatter that refused these would refuse the very keystroke that produces them.
      for (final text in const ["12.", ".", ",", ",5"]) {
        expect(
          _formatted(formatter: formatter, oldText: "", newText: text),
          text,
          reason: "$text is a number on its way in",
        );
      }
    });

    test("refuses anything that is not a number, keeping what the field already held", () {
      for (final text in const ["plein", "12a", "×2", "2 par jour", "12.5.5", "12,5.5", "-3"]) {
        expect(
          _formatted(formatter: formatter, oldText: "4", newText: text),
          "4",
          reason: "$text is not a number",
        );
      }
    });
  });
}

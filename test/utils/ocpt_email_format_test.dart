// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_email_format.dart';

void main() {
  group("ocptEmailLooksWellFormed", () {
    test("accepts the addresses a production's address book actually holds", () {
      for (final value in [
        "clara@example.com",
        "clara.martin@example.co.uk",
        "clara+casting@example.com",
        "clara_martin@sous-domaine.example.fr",
        "  clara@example.com  ", // pasted with its surrounding whitespace
      ]) {
        expect(ocptEmailLooksWellFormed(value), isTrue, reason: value);
      }
    });

    test("accepts an empty value: no address at all is a normal state", () {
      expect(ocptEmailLooksWellFormed(""), isTrue);
      expect(ocptEmailLooksWellFormed("   "), isTrue);
    });

    test("rejects what people actually mistype", () {
      for (final value in [
        "clara.example.com", // no @
        "clara@", // no domain
        "@example.com", // no local part
        "clara@example", // no dot in the domain, see the pattern's own doc comment
        "clara@exam ple.com", // a stray space
        "clara@@example.com",
        "clara@example..com",
      ]) {
        expect(ocptEmailLooksWellFormed(value), isFalse, reason: value);
      }
    });
  });
}

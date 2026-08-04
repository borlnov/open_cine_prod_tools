// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_resources_search.dart';

void main() {
  group("ocptResourcesSearchNormalized", () {
    test("lower-cases plain text", () {
      expect(ocptResourcesSearchNormalized("Léa"), "lea");
      expect(ocptResourcesSearchNormalized("LÉA"), "lea");
    });

    test("folds every accented Latin-1 character the app's two languages need", () {
      expect(
        ocptResourcesSearchNormalized("àâäáãåçéèêëíìîïñóòôöõúùûüýÿ"),
        "aaaaaaceeeeiiiinooooouuuuyy",
      );
      expect(ocptResourcesSearchNormalized("œuf"), "oeuf");
      expect(ocptResourcesSearchNormalized("nœud"), "noeud");
      expect(ocptResourcesSearchNormalized("vitæ"), "vitae");
    });

    test("leaves plain ASCII untouched, only lower-cased", () {
      expect(ocptResourcesSearchNormalized("Martin"), "martin");
    });
  });

  group("ocptResourcesSearchMatches", () {
    test("an empty query always matches, whatever the fields", () {
      expect(ocptResourcesSearchMatches(query: "", fields: const []), isTrue);
      expect(ocptResourcesSearchMatches(query: "", fields: const ["Léa Martin"]), isTrue);
    });

    test("a whitespace-only query normalizes to empty and always matches too", () {
      expect(ocptResourcesSearchMatches(query: "   ", fields: const ["Léa Martin"]), isTrue);
    });

    test("an unaccented query finds an accented field", () {
      expect(ocptResourcesSearchMatches(query: "lea", fields: const ["Léa Martin"]), isTrue);
    });

    test("an accented, upper-case query finds a plain field", () {
      expect(ocptResourcesSearchMatches(query: "LÉA", fields: const ["Lea Martin"]), isTrue);
    });

    test("matches anywhere inside a field, not just at its start", () {
      expect(ocptResourcesSearchMatches(query: "artin", fields: const ["Léa Martin"]), isTrue);
    });

    test("matches when any one of several fields matches", () {
      expect(
        ocptResourcesSearchMatches(query: "lyon", fields: const ["Léa Martin", "", "Lyon"]),
        isTrue,
      );
    });

    test("does not match when nothing in the fields contains the query", () {
      expect(
        ocptResourcesSearchMatches(query: "paris", fields: const ["Léa Martin", "Lyon"]),
        isFalse,
      );
    });

    test("does not match a set of fields that is entirely empty", () {
      expect(ocptResourcesSearchMatches(query: "lea", fields: const ["", ""]), isFalse);
    });
  });
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_crew_position_search.dart';

void main() {
  group("ocptCrewPositionSearchNormalized", () {
    test("lower-cases plain text", () {
      expect(ocptCrewPositionSearchNormalized("Réalisateur"), "realisateur");
      expect(ocptCrewPositionSearchNormalized("RÉALISATEUR"), "realisateur");
    });

    test("drops every middle dot an inclusive-writing label carries", () {
      expect(ocptCrewPositionSearchNormalized("réalisateur·rice"), "realisateurrice");
      expect(ocptCrewPositionSearchNormalized("chef·fe électricien·ne"), "cheffe electricienne");
    });

    test("folds accents the same way the resources search does", () {
      expect(ocptCrewPositionSearchNormalized("Décorateur"), "decorateur");
      expect(ocptCrewPositionSearchNormalized("Ingénieur·e"), "ingenieure");
    });

    test("trims leading and trailing whitespace", () {
      expect(ocptCrewPositionSearchNormalized("  Grip  "), "grip");
    });
  });

  group("ocptCrewPositionSearchMatches", () {
    test("an empty query always matches, whatever the label", () {
      expect(ocptCrewPositionSearchMatches(query: "", label: "Réalisateur·rice"), isTrue);
    });

    test("a whitespace-only query normalizes to empty and always matches too", () {
      expect(ocptCrewPositionSearchMatches(query: "   ", label: "Réalisateur·rice"), isTrue);
    });

    test("an unaccented, dot-free query finds an inclusive-writing label", () {
      expect(ocptCrewPositionSearchMatches(query: "realisateurrice", label: "Réalisateur·rice"), isTrue);
    });

    test("a plain substring query finds a label carrying it, case-insensitively", () {
      expect(ocptCrewPositionSearchMatches(query: "ELEC", label: "Chef·fe électricien·ne"), isTrue);
    });

    test("matches anywhere inside the label, not just at its start", () {
      expect(ocptCrewPositionSearchMatches(query: "rice", label: "Réalisateur·rice"), isTrue);
    });

    test("does not match when the label does not contain the query", () {
      expect(ocptCrewPositionSearchMatches(query: "machiniste", label: "Réalisateur·rice"), isFalse);
    });
  });
}

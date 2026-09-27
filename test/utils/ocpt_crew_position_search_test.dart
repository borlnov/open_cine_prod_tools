// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/utils/ocpt_crew_position_search.dart';

/// Every word written in inclusive writing across the French crew position labels, lower-cased,
/// with the feminine reading it must give. A label added later with a word this table does not
/// hold fails [main]'s catalogue test until the word is checked and added here — which is the
/// point: a word no rule of `ocptInclusiveFeminineOf` fits would otherwise search wrongly, silently.
const Map<String, String> _expectedFeminineWords = {
  "adjoint·e": "adjointe",
  "administrateur·rice": "administratrice",
  "animatronicien·ne": "animatronicienne",
  "assistant·e": "assistante",
  "bruiteur·euse": "bruiteuse",
  "cadreur·euse": "cadreuse",
  "chargé·e": "chargée",
  "chef·fe": "cheffe",
  "coiffeur·euse": "coiffeuse",
  "conducteur·rice": "conductrice",
  "conseiller·ère": "conseillère",
  "constructeur·rice": "constructrice",
  "coordinateur·rice": "coordinatrice",
  "costumier·ère": "costumière",
  "couturier·ère": "couturière",
  "créateur·rice": "créatrice",
  "directeur·rice": "directrice",
  "décorateur·rice": "décoratrice",
  "ensemblier·ère": "ensemblière",
  "exécutif·ve": "exécutive",
  "général·e": "générale",
  "habilleur·euse": "habilleuse",
  "illustrateur·rice": "illustratrice",
  "maquilleur·euse": "maquilleuse",
  "mixeur·euse": "mixeuse",
  "monteur·euse": "monteuse",
  "opérateur·rice": "opératrice",
  "patineur·euse": "patineuse",
  "premier·ère": "première",
  "producteur·rice": "productrice",
  "réalisateur·rice": "réalisatrice",
  "régisseur·euse": "régisseuse",
  "répétiteur·rice": "répétitrice",
  "sous-chef·fe": "sous-cheffe",
  "spécialisé·e": "spécialisée",
  "superviseur·euse": "superviseuse",
  "technicien·ne": "technicienne",
  "teinturier·ère": "teinturière",
  "électricien·ne": "électricienne",
};

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

    test("matches the feminine reading of an inclusive label", () {
      expect(ocptCrewPositionSearchMatches(query: "directrice", label: "Directeur·rice"), isTrue);
      expect(
        ocptCrewPositionSearchMatches(query: "régisseuse générale", label: "Régisseur·euse général·e"),
        isTrue,
      );
      expect(
        ocptCrewPositionSearchMatches(
          query: "premiere assistante realisatrice",
          label: "Premier·ère assistant·e réalisateur·rice",
        ),
        isTrue,
      );
    });

    test("matches the masculine reading across several words", () {
      expect(
        ocptCrewPositionSearchMatches(
          query: "premier assistant realisateur",
          label: "Premier·ère assistant·e réalisateur·rice",
        ),
        isTrue,
      );
    });
  });

  group("ocptInclusiveReadingsOf", () {
    test("reads a label in the masculine, then in the feminine", () {
      expect(ocptInclusiveReadingsOf("Premier·ère assistant·e réalisateur·rice"), [
        "Premier assistant réalisateur",
        "Première assistante réalisatrice",
      ]);
    });

    test("has nothing to offer for a label with no middle dot", () {
      expect(ocptInclusiveReadingsOf("Scripte"), isEmpty);
      expect(ocptInclusiveReadingsOf("Unit manager"), isEmpty);
    });
  });

  group("ocptInclusiveFeminineOf", () {
    test("replaces the ending each pattern names, and appends any other", () {
      expect(ocptInclusiveFeminineOf("réalisateur·rice"), "réalisatrice");
      expect(ocptInclusiveFeminineOf("régisseur·euse"), "régisseuse");
      expect(ocptInclusiveFeminineOf("costumier·ère"), "costumière");
      expect(ocptInclusiveFeminineOf("exécutif·ve"), "exécutive");
      expect(ocptInclusiveFeminineOf("Sous-chef·fe"), "Sous-cheffe");
      expect(ocptInclusiveFeminineOf("assistant·e"), "assistante");
    });

    test("leaves a word with no middle dot as it is", () {
      expect(ocptInclusiveFeminineOf("scripte"), "scripte");
    });

    test("reads every inclusive word of the French crew position labels as expected", () {
      final french = jsonDecode(File("lib/l10n/intl_fr.arb").readAsStringSync()) as Map<String, dynamic>;
      final inclusiveWords = <String>{
        for (final entry in french.entries)
          if (entry.key.startsWith("resourcesCrewPosition") && !entry.key.contains("Picker"))
            for (final word in (entry.value as String).split(" "))
              if (word.contains("·")) word,
      };

      expect(inclusiveWords, isNotEmpty);
      for (final word in inclusiveWords) {
        final key = word.toLowerCase();
        expect(_expectedFeminineWords, contains(key), reason: "no expected feminine for '$word'");
        expect(ocptInclusiveFeminineOf(word).toLowerCase(), _expectedFeminineWords[key], reason: word);
      }
    });
  });
}

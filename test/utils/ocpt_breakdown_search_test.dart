// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_breakdown_target_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_element_category.dart';
import 'package:open_cine_prod_tools/utils/ocpt_breakdown_search.dart';

/// Builds an element candidate named [name], tagged in [taggedSceneCount] scenes.
OcptBreakdownSearchCandidate _element({
  required String id,
  required String name,
  OcptElementCategory category = OcptElementCategory.prop,
  int taggedSceneCount = 0,
}) => OcptBreakdownSearchCandidate(
  kind: OcptBreakdownTargetKind.element,
  id: id,
  name: name,
  category: category,
  taggedSceneCount: taggedSceneCount,
);

/// Builds a role candidate named [name], tagged in [taggedSceneCount] scenes.
OcptBreakdownSearchCandidate _role({
  required String id,
  required String name,
  int taggedSceneCount = 0,
}) => OcptBreakdownSearchCandidate(
  kind: OcptBreakdownTargetKind.role,
  id: id,
  name: name,
  category: null,
  taggedSceneCount: taggedSceneCount,
);

/// Builds a set candidate named [name], tagged in [taggedSceneCount] scenes.
OcptBreakdownSearchCandidate _set({
  required String id,
  required String name,
  int taggedSceneCount = 0,
}) => OcptBreakdownSearchCandidate(
  kind: OcptBreakdownTargetKind.set,
  id: id,
  name: name,
  category: null,
  taggedSceneCount: taggedSceneCount,
);

void main() {
  group("ocptBreakdownSearchCatalogues — grouping", () {
    test("splits the matching candidates into their three kinds", () {
      final results = ocptBreakdownSearchCatalogues(
        query: "",
        candidates: [
          _role(id: "r1", name: "Léa"),
          _set(id: "s1", name: "Cuisine"),
          _element(id: "e1", name: "Lampe"),
        ],
      );

      expect(results.roles.map((c) => c.id), ["r1"]);
      expect(results.sets.map((c) => c.id), ["s1"]);
      expect(results.elements.map((c) => c.id), ["e1"]);
    });

    test("a kind with no match is an empty list, never null", () {
      final results = ocptBreakdownSearchCatalogues(
        query: "zzz",
        candidates: [_role(id: "r1", name: "Léa")],
      );

      expect(results.roles, isEmpty);
      expect(results.sets, isEmpty);
      expect(results.elements, isEmpty);
      expect(results.isEmpty, isTrue);
    });

    test("isEmpty is false as soon as one kind has a match", () {
      final results = ocptBreakdownSearchCatalogues(
        query: "",
        candidates: [_role(id: "r1", name: "Léa")],
      );

      expect(results.isEmpty, isFalse);
    });
  });

  group("ocptBreakdownSearchCatalogues — matching", () {
    test("an empty query matches every candidate", () {
      final results = ocptBreakdownSearchCatalogues(
        query: "",
        candidates: [_element(id: "e1", name: "Lampe"), _element(id: "e2", name: "Chaise")],
      );

      expect(results.elements.map((c) => c.id).toSet(), {"e1", "e2"});
    });

    test("a whitespace-only query also matches every candidate", () {
      final results = ocptBreakdownSearchCatalogues(
        query: "   ",
        candidates: [_element(id: "e1", name: "Lampe")],
      );

      expect(results.elements.map((c) => c.id), ["e1"]);
    });

    test("an unaccented query finds an accented name, folding through ocptResourcesSearchMatches", () {
      final results = ocptBreakdownSearchCatalogues(
        query: "lea",
        candidates: [_role(id: "r1", name: "Léa"), _role(id: "r2", name: "Marc")],
      );

      expect(results.roles.map((c) => c.id), ["r1"]);
    });

    test("a query typed into the middle of a name still finds it", () {
      final results = ocptBreakdownSearchCatalogues(
        query: "amp",
        candidates: [_element(id: "e1", name: "Lampe de bureau")],
      );

      expect(results.elements.map((c) => c.id), ["e1"]);
    });

    test("matching never looks at the category, only at the name", () {
      // "propane" must not list every element merely because it is a prop.
      final results = ocptBreakdownSearchCatalogues(
        query: "propane",
        candidates: [
          _element(id: "e1", name: "Lampe"),
          _element(id: "e2", name: "Chaise"),
        ],
      );

      expect(results.elements, isEmpty);
    });
  });

  group("ocptBreakdownSearchCatalogues — ranking", () {
    test("a prefix match ranks before a match found only elsewhere in the name", () {
      final results = ocptBreakdownSearchCatalogues(
        query: "lampe",
        candidates: [
          _element(id: "e1", name: "Grande lampe"),
          _element(id: "e2", name: "Lampe de bureau"),
        ],
      );

      expect(results.elements.map((c) => c.id), ["e2", "e1"]);
    });

    test("an already-tagged candidate ranks before an untouched one, prefix status equal", () {
      final results = ocptBreakdownSearchCatalogues(
        query: "",
        candidates: [
          _element(id: "e1", name: "Chaise"),
          _element(id: "e2", name: "Table", taggedSceneCount: 3),
        ],
      );

      expect(results.elements.map((c) => c.id), ["e2", "e1"]);
    });

    test("the prefix criterion outranks the tagged criterion", () {
      final results = ocptBreakdownSearchCatalogues(
        query: "lampe",
        candidates: [
          // Not a prefix match, but tagged a lot.
          _element(id: "e1", name: "Grande lampe", taggedSceneCount: 10),
          // A prefix match, but never tagged.
          _element(id: "e2", name: "Lampe de bureau"),
        ],
      );

      expect(results.elements.map((c) => c.id), ["e2", "e1"]);
    });

    test("ties fall back to the name, compared normalized so accents don't scatter the order", () {
      final results = ocptBreakdownSearchCatalogues(
        query: "",
        candidates: [_role(id: "r1", name: "Zoé"), _role(id: "r2", name: "Amélie")],
      );

      expect(results.roles.map((c) => c.id), ["r2", "r1"]);
    });

    test("a full tie on name falls back to the id, deterministically", () {
      final results = ocptBreakdownSearchCatalogues(
        query: "",
        candidates: [_role(id: "r2", name: "Léa"), _role(id: "r1", name: "Léa")],
      );

      expect(results.roles.map((c) => c.id), ["r1", "r2"]);
    });

    test("ranking each kind is independent of the others", () {
      final results = ocptBreakdownSearchCatalogues(
        query: "",
        candidates: [
          _role(id: "r1", name: "Zoé"),
          _set(id: "s1", name: "Cuisine", taggedSceneCount: 1),
          _set(id: "s2", name: "Atelier"),
        ],
      );

      expect(results.roles.map((c) => c.id), ["r1"]);
      expect(results.sets.map((c) => c.id), ["s1", "s2"]);
    });
  });

  group("ocptBreakdownSearchCatalogues — capping", () {
    test("caps each kind at perKindLimit, keeping the best matches after ranking", () {
      final candidates = [
        _element(id: "e1", name: "Aaa"),
        _element(id: "e2", name: "Bbb", taggedSceneCount: 1),
        _element(id: "e3", name: "Ccc", taggedSceneCount: 1),
        _element(id: "e4", name: "Ddd"),
      ];

      final results = ocptBreakdownSearchCatalogues(
        query: "",
        candidates: candidates,
        perKindLimit: 2,
      );

      // Tagged candidates rank first, so the cap keeps e2 and e3, not e1 and e2.
      expect(results.elements.map((c) => c.id), ["e2", "e3"]);
    });

    test("the default cap is ocptBreakdownSearchPerKindLimit", () {
      final candidates = List.generate(
        ocptBreakdownSearchPerKindLimit + 3,
        (i) => _element(id: "e$i", name: "Element $i"),
      );

      final results = ocptBreakdownSearchCatalogues(query: "", candidates: candidates);

      expect(results.elements.length, ocptBreakdownSearchPerKindLimit);
    });

    test("a perKindLimit of zero throws ArgumentError", () {
      expect(
        () => ocptBreakdownSearchCatalogues(query: "", candidates: const [], perKindLimit: 0),
        throwsArgumentError,
      );
    });

    test("a negative perKindLimit throws ArgumentError", () {
      expect(
        () => ocptBreakdownSearchCatalogues(query: "", candidates: const [], perKindLimit: -1),
        throwsArgumentError,
      );
    });
  });
}

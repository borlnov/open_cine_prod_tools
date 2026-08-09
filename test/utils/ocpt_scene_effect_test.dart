// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/types/ocpt_scene_effect_category.dart';
import 'package:open_cine_prod_tools/utils/ocpt_scene_effect.dart';

void main() {
  group('ocptSceneEffectOf', () {
    test('reads an INT heading with an English day word', () {
      final effect = ocptSceneEffectOf('INT. HOUSE - DAY');

      expect(effect.printedEffect, 'INT / DAY');
      expect(effect.place, OcptScenePlace.interior);
      expect(effect.timeOfDay, OcptSceneTimeOfDay.day);
    });

    test('reads an EXT heading with an English night word', () {
      final effect = ocptSceneEffectOf('EXT. STREET - NIGHT');

      expect(effect.printedEffect, 'EXT / NIGHT');
      expect(effect.place, OcptScenePlace.exterior);
      expect(effect.timeOfDay, OcptSceneTimeOfDay.night);
    });

    test('reads a French INT heading with JOUR', () {
      final effect = ocptSceneEffectOf('INT. CUISINE - JOUR');

      expect(effect.printedEffect, 'INT / JOUR');
      expect(effect.place, OcptScenePlace.interior);
      expect(effect.timeOfDay, OcptSceneTimeOfDay.day);
    });

    test('reads a French EXT heading with NUIT', () {
      final effect = ocptSceneEffectOf('EXT. RUE - NUIT');

      expect(effect.printedEffect, 'EXT / NUIT');
      expect(effect.place, OcptScenePlace.exterior);
      expect(effect.timeOfDay, OcptSceneTimeOfDay.night);
    });

    test('time-of-day matching is case-insensitive but prints verbatim', () {
      final effect = ocptSceneEffectOf('INT. CUISINE - jour');

      expect(effect.printedEffect, 'INT / jour');
      expect(effect.timeOfDay, OcptSceneTimeOfDay.day);
    });

    test(
      'an EST prefix reads as exterior, the same variant the call sheet already accepted',
      () {
        final effect = ocptSceneEffectOf('EST. JARDIN - JOUR');

        // Printed as "EXT", not "EST": the call sheet's own reading normalises the variant, exactly
        // as the pre-refactor `_effectOf` already did.
        expect(effect.printedEffect, 'EXT / JOUR');
        expect(effect.place, OcptScenePlace.exterior);
      },
    );

    for (final prefix in [
      'INT./EXT. VOITURE',
      'INT/EXT. VOITURE',
      'I/E. VOITURE',
    ]) {
      test('an "$prefix" heading prints INT/EXT but classifies no place', () {
        final effect = ocptSceneEffectOf('$prefix - JOUR');

        expect(effect.printedEffect, 'INT/EXT / JOUR');
        expect(effect.place, isNull);
        expect(effect.timeOfDay, OcptSceneTimeOfDay.day);
      });
    }

    test(
      'an unrecognised time-of-day word classifies no time of day, but still prints',
      () {
        final effect = ocptSceneEffectOf('INT. CUISINE - DAWN');

        expect(effect.printedEffect, 'INT / DAWN');
        expect(effect.place, OcptScenePlace.interior);
        expect(effect.timeOfDay, isNull);
      },
    );

    test(
      'a heading naming neither INT nor EXT keeps its own prefix verbatim, unclassified',
      () {
        final effect = ocptSceneEffectOf('CUISINE - JOUR');

        expect(effect.printedEffect, 'CUISINE / JOUR');
        expect(effect.place, isNull);
      },
    );

    test('a heading with no " - " split reads as nothing at all', () {
      final effect = ocptSceneEffectOf('INT. CUISINE');

      expect(effect.printedEffect, isNull);
      expect(effect.place, isNull);
      expect(effect.timeOfDay, isNull);
    });

    test('a null heading reads as nothing at all', () {
      final effect = ocptSceneEffectOf(null);

      expect(effect.printedEffect, isNull);
      expect(effect.place, isNull);
      expect(effect.timeOfDay, isNull);
    });
  });

  group('ocptSceneEffectCategoryOf', () {
    test('an empty list of headings classifies as null (nothing placed)', () {
      expect(ocptSceneEffectCategoryOf(const []), isNull);
    });

    test(
      'a list of only unclassifiable headings classifies as null (nothing to say)',
      () {
        final category = ocptSceneEffectCategoryOf([
          'INT. CUISINE - DAWN',
          'no split here',
          null,
        ]);

        expect(category, isNull);
      },
    );

    test('every classifiable heading agreeing reads as that one category', () {
      final category = ocptSceneEffectCategoryOf([
        'INT. CUISINE - JOUR',
        'INT. SALON - JOUR',
        'INT. CUISINE - DAWN', // unclassifiable, contributes nothing either way
      ]);

      expect(category, OcptSceneEffectCategory.interiorDay);
    });

    test('two disagreeing classifiable headings read as mixed', () {
      final category = ocptSceneEffectCategoryOf([
        'INT. CUISINE - JOUR',
        'EXT. RUE - NUIT',
      ]);

      expect(category, OcptSceneEffectCategory.mixed);
    });

    test('every one of the four categories is reachable', () {
      expect(
        ocptSceneEffectCategoryOf(['INT. A - JOUR']),
        OcptSceneEffectCategory.interiorDay,
      );
      expect(
        ocptSceneEffectCategoryOf(['INT. A - NUIT']),
        OcptSceneEffectCategory.interiorNight,
      );
      expect(
        ocptSceneEffectCategoryOf(['EXT. A - JOUR']),
        OcptSceneEffectCategory.exteriorDay,
      );
      expect(
        ocptSceneEffectCategoryOf(['EXT. A - NUIT']),
        OcptSceneEffectCategory.exteriorNight,
      );
    });
  });
}

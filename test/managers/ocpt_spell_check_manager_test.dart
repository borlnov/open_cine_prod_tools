// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/ocpt_global_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_spell_check_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';

/// Reads a dictionary asset straight off disk, the seam [OcptSpellCheckManager] takes in place of
/// `rootBundle.loadString` for a test: `flutter test` runs on the plain Dart VM, and this manager
/// only ever hands the two files' text across an isolate boundary, so a test does not need the
/// asset bundle machinery at all — it needs the very same bytes `rootBundle` would have read,
/// which the repository already carries at the path the manager itself asks for
/// (`assets/dictionaries/<language>/index.{aff,dic}`, relative to the repository root `flutter
/// test` runs from).
Future<String> _readDictionaryAssetFromDisk(String assetKey) => File(assetKey).readAsString();

void main() {
  // OcptScreenplayLanguage (through appLogger(), used by the manager and its worker) requires a
  // global manager instance to exist; merely accessing it creates the (otherwise unused)
  // singleton.
  setUpAll(() => OcptGlobalManager.instance);

  group('OcptSpellCheckManager with the French dictionary loaded', () {
    late OcptSpellCheckManager manager;

    setUpAll(() async {
      manager = OcptSpellCheckManager(loadAsset: _readDictionaryAssetFromDisk);
      await manager.useLanguage(OcptScreenplayLanguage.fr);
    });

    tearDownAll(() => manager.disposeLifeCycle());

    test('reports the loaded language', () {
      expect(manager.loadedLanguage, OcptScreenplayLanguage.fr);
    });

    test('finds no misspelling in a correctly spelled French word', () async {
      final result = await manager.check({'a': "aujourd'hui"});

      expect(result['a'], isEmpty);
    });

    test('finds a misspelling in a French word the dictionary does not know', () async {
      final result = await manager.check({'a': 'aujourdhuiii'});

      expect(result['a'], isNotEmpty);
    });

    test('round-trips a non-trivial key type intact', () async {
      final keyA = (sceneId: 'scene-1', lineIndex: 3);
      final keyB = (sceneId: 'scene-2', lineIndex: 7);

      final result = await manager.check({
        keyA: "aujourd'hui",
        keyB: 'aujourdhuiii',
      });

      expect(result.keys, containsAll([keyA, keyB]));
      expect(result[keyA], isEmpty);
      expect(result[keyB], isNotEmpty);
    });

    test('a learned word turns a previously unknown word known', () async {
      const madeUpWord = 'zorglurbe';

      final before = await manager.check({'a': madeUpWord});
      expect(before['a'], isNotEmpty);

      manager.setLearnedWords({madeUpWord});
      final after = await manager.check({'a': madeUpWord});
      expect(after['a'], isEmpty);

      // Leave the manager as the other tests in this group expect it.
      manager.setLearnedWords(const {});
    });

    test('drops a response whose request was issued under a stale generation', () async {
      final pending = manager.check({'a': "aujourd'hui"});
      // Bumps the generation before the isolate round trip above can possibly have resolved,
      // since resolving it needs at least one more event-loop turn than this synchronous call.
      manager.ignoreWords({'some-irrelevant-word'});

      final result = await pending;

      expect(result, isEmpty);

      // Leave the manager as the other tests in this group expect it.
      manager.ignoreWords(const {});
    });

    test('useLanguage(null) unloads the dictionary and check returns empty', () async {
      await manager.useLanguage(null);

      expect(manager.loadedLanguage, isNull);
      expect(await manager.check({'a': "aujourd'hui"}), isEmpty);
    });
  });

  group('OcptSpellCheckManager with the English dictionary loaded', () {
    late OcptSpellCheckManager manager;

    setUpAll(() async {
      manager = OcptSpellCheckManager(loadAsset: _readDictionaryAssetFromDisk);
      await manager.useLanguage(OcptScreenplayLanguage.enGb);
    });

    tearDownAll(() => manager.disposeLifeCycle());

    test('finds no misspelling in a correctly spelled English word', () async {
      final result = await manager.check({'a': 'screenplay'});

      expect(result['a'], isEmpty);
    });

    test('finds a misspelling in an English word the dictionary does not know', () async {
      final result = await manager.check({'a': 'screenplaiy'});

      expect(result['a'], isNotEmpty);
    });

    test('suggestionsFor returns candidates for a misspelled word', () async {
      final suggestions = await manager.suggestionsFor('screenplaiy');

      expect(suggestions, isNotEmpty);
    });
  });

  test('check returns empty with no dictionary ever loaded', () async {
    final manager = OcptSpellCheckManager(loadAsset: _readDictionaryAssetFromDisk);
    addTearDown(manager.disposeLifeCycle);

    expect(await manager.check({'a': 'anything'}), isEmpty);
    expect(await manager.suggestionsFor('anything'), isEmpty);
  });
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:isolate';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_life_cycle/act_life_cycle.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import 'package:spell_kit/spell_kit.dart';

/// Reads the text asset at [assetKey]. The type of [OcptSpellCheckManager.useLanguage]'s
/// injectable seam, defaulting to [rootBundle]'s own `loadString` — see that constructor
/// parameter's doc comment for why a test wants to be able to replace it.
typedef OcptSpellCheckAssetLoader = Future<String> Function(String assetKey);

/// The directory, under `assets/dictionaries/`, a bundled hunspell dictionary pair for
/// [language] is read from.
String _assetDirectoryFor(OcptScreenplayLanguage language) {
  switch (language) {
    case OcptScreenplayLanguage.fr:
      return "fr";
    case OcptScreenplayLanguage.enGb:
      return "en_GB";
  }
}

/// Builds the [OcptSpellCheckManager] instance registered by the global manager.
class OcptSpellCheckManagerBuilder extends AbsLifeCycleFactory<OcptSpellCheckManager> {
  /// Class constructor
  const OcptSpellCheckManagerBuilder() : super(OcptSpellCheckManager.new);

  /// {@macro act_life_cycle.AbsLifeCycleFactory.dependsOn}
  @override
  Iterable<Type> dependsOn() => [LoggerManager];
}

/// Owns the one long-lived worker isolate this app's spell-checking runs on
/// (`docs/plans/screenplay-spell-check.md` §3.1).
///
/// The isolate holds a `spell_kit` `SpellChecker` built over whichever language's dictionary
/// [useLanguage] last loaded, plus the session's ignored words and the open project's learned
/// words ([ignoreWords], [setLearnedWords]). It is spawned lazily on the first non-null
/// [useLanguage] call and lives for the whole app session, never one per editor mount: parsing a
/// dictionary costs ~250-350 ms and the parsed form ~14 MB, and the editor is remounted by an
/// episode switch, a mode toggle, an import and a version restore — none of which has anything to
/// do with which language is being checked.
///
/// Every request rides a small message-passing protocol (private classes and the isolate's own
/// entry point sit at the bottom of this file) keyed by a request id, so two [check] calls can be
/// in flight at once and each resolves to its own answer. A request carries the [generation] it
/// was issued under; a response arriving once the generation has moved on (a language change, a
/// word learned or unlearned) is dropped here rather than reaching the caller — resolved to an
/// empty map/list instead of left to hang or made to throw, since a stale answer painted over
/// fresh text would be worse than no answer at all.
///
/// This manager sees no `Tr` and no project row: the bloc that calls it resolves both a
/// language's provenance and any word it wants learned or ignored before handing them in here.
class OcptSpellCheckManager extends AbsWithLifeCycle {
  /// Creates an [OcptSpellCheckManager].
  ///
  /// [loadAsset] is the injectable seam over reading a dictionary's `.aff`/`.dic` text out of the
  /// asset bundle, defaulting to [rootBundle]'s own `loadString`. A test that cannot reach the
  /// asset bundle the way `rootBundle` needs to can pass one reading the very same files straight
  /// off disk instead — the manager never cares which.
  OcptSpellCheckManager({OcptSpellCheckAssetLoader? loadAsset})
    : _loadAsset = loadAsset ?? rootBundle.loadString;

  /// The seam [useLanguage] reads a dictionary's two asset files through.
  final OcptSpellCheckAssetLoader _loadAsset;

  /// The worker isolate this manager talks to, or null while none is spawned (before the first
  /// [useLanguage] call, or after [useLanguage] was last called with null, or after the isolate
  /// died unexpectedly).
  _SpellCheckWorkerHandle? _worker;

  /// The language whose dictionary is currently loaded in the worker, or null if none is.
  OcptScreenplayLanguage? _loadedLanguage;

  /// The words the bloc last pushed in through [ignoreWords].
  Set<String> _ignoredWords = const {};

  /// The words the bloc last pushed in through [setLearnedWords].
  Set<String> _learnedWords = const {};

  /// The next request id handed out by [_nextRequestId].
  int _requestIdCounter = 0;

  /// Bumped by [useLanguage], [ignoreWords] and [setLearnedWords]; see the class doc comment for
  /// what it guards against.
  int _generation = 0;

  /// The [check] requests still awaiting a `_CheckResponse`, keyed by request id.
  final Map<int, _PendingCheck> _pendingChecks = {};

  /// The [suggestionsFor] requests still awaiting a `_SuggestResponse`, keyed by request id.
  final Map<int, _PendingSuggestion> _pendingSuggestions = {};

  /// The language whose dictionary is currently loaded, or null if none is.
  OcptScreenplayLanguage? get loadedLanguage => _loadedLanguage;

  /// The current generation; see the class doc comment.
  int get generation => _generation;

  /// The next request id, minted once per outgoing message so a response can be matched back to
  /// the request that caused it.
  int _nextRequestId() => _requestIdCounter++;

  /// Loads [language]'s bundled dictionary into the worker isolate, spawning it lazily on first
  /// use, or unloads it and kills the worker when [language] is null.
  ///
  /// The two asset files are read here, on the **main** isolate (`rootBundle.loadString`, ~1.8 MB,
  /// cheap), and only their text is sent to the worker, which parses them there: `rootBundle`
  /// inside a plain isolate would need the `BackgroundIsolateBinaryMessenger`/`RootIsolateToken`
  /// dance, and sending two strings avoids the platform channel entirely. Calling this with
  /// [language] already loaded is a no-op. Every pending [check]/[suggestionsFor] request in
  /// flight under the generation this call replaces resolves to an empty answer rather than the
  /// stale one it was going to get.
  Future<void> useLanguage(OcptScreenplayLanguage? language) async {
    if (language == _loadedLanguage) {
      return;
    }

    _generation++;
    _loadedLanguage = language;

    if (language == null) {
      await _killWorker();
      return;
    }

    final assetDirectory = _assetDirectoryFor(language);
    final affix = await _loadAsset("assets/dictionaries/$assetDirectory/index.aff");
    final dictionary = await _loadAsset("assets/dictionaries/$assetDirectory/index.dic");

    final worker = await _ensureWorker();
    if (worker == null) {
      // The isolate failed to spawn; already logged by _ensureWorker. Leave _loadedLanguage as
      // recorded above (it's the truthful "what was asked for"), but there is nothing more to do:
      // every check/suggestionsFor call already returns empty with no worker to talk to.
      return;
    }

    final requestId = _nextRequestId();
    final loadCompleter = Completer<void>();
    _pendingLoad = _PendingLoad(
      requestId: requestId,
      complete: () {
        if (!loadCompleter.isCompleted) {
          loadCompleter.complete();
        }
      },
    );
    worker.sendPort.send(_LoadRequest(requestId: requestId, affix: affix, dictionary: dictionary));
    await loadCompleter.future;

    _pushExtraWords(worker);
  }

  /// Checks every text of [textsByKey] for misspellings in one isolate round trip, returning the
  /// misspelled ranges found in each, keyed back by the very same [K] the caller handed in.
  ///
  /// Returns an empty map immediately, with no isolate round trip at all, when no dictionary is
  /// loaded or [textsByKey] is empty.
  Future<Map<K, List<SpellRange>>> check<K>(Map<K, String> textsByKey) async {
    final worker = _worker;
    if (worker == null || textsByKey.isEmpty) {
      return const {};
    }

    final keys = textsByKey.keys.toList(growable: false);
    final textsByIndex = <int, String>{
      for (var i = 0; i < keys.length; i++) i: textsByKey[keys[i]]!,
    };

    final requestGeneration = _generation;
    final completer = Completer<Map<K, List<SpellRange>>>();
    final requestId = _nextRequestId();
    _pendingChecks[requestId] = _PendingCheck(
      generation: requestGeneration,
      resolve: (rangesByIndex) {
        if (completer.isCompleted) {
          return;
        }
        completer.complete({
          for (var i = 0; i < keys.length; i++) keys[i]: rangesByIndex[i] ?? const [],
        });
      },
      resolveEmpty: () {
        if (!completer.isCompleted) {
          completer.complete(const {});
        }
      },
    );

    worker.sendPort.send(_CheckRequest(requestId: requestId, textsByIndex: textsByIndex));

    return completer.future;
  }

  /// Suggests up to five corrections for [word], on demand — never computed ahead of a
  /// right-click asking for it.
  ///
  /// Returns an empty list immediately, with no isolate round trip at all, when no dictionary is
  /// loaded.
  Future<List<String>> suggestionsFor(String word) async {
    final worker = _worker;
    if (worker == null) {
      return const [];
    }

    final requestGeneration = _generation;
    final completer = Completer<List<String>>();
    final requestId = _nextRequestId();
    _pendingSuggestions[requestId] = _PendingSuggestion(
      generation: requestGeneration,
      resolve: (suggestions) {
        if (!completer.isCompleted) {
          completer.complete(suggestions);
        }
      },
      resolveEmpty: () {
        if (!completer.isCompleted) {
          completer.complete(const []);
        }
      },
    );

    worker.sendPort.send(_SuggestRequest(requestId: requestId, word: word));

    return completer.future;
  }

  /// Sets the session's ignored words (never persisted, dropped when the app closes), replacing
  /// whatever was pushed in before. Bumps [generation] and clears the worker's memo.
  void ignoreWords(Set<String> words) {
    _ignoredWords = words;
    _generation++;
    final worker = _worker;
    if (worker != null) {
      _pushExtraWords(worker);
    }
  }

  /// Sets the open project's learned words, replacing whatever was pushed in before. Bumps
  /// [generation] and clears the worker's memo.
  void setLearnedWords(Set<String> words) {
    _learnedWords = words;
    _generation++;
    final worker = _worker;
    if (worker != null) {
      _pushExtraWords(worker);
    }
  }

  /// Sends the union of [_ignoredWords] and [_learnedWords] to [worker]; fire-and-forget, since
  /// nothing here needs to await the memo actually being cleared before returning.
  void _pushExtraWords(_SpellCheckWorkerHandle worker) {
    worker.sendPort.send(
      _SetExtraWordsRequest(words: {..._ignoredWords, ..._learnedWords}),
    );
  }

  /// Returns the already-spawned worker, or spawns one and returns it, or returns null (having
  /// already logged why) if spawning failed.
  Future<_SpellCheckWorkerHandle?> _ensureWorker() async {
    final existing = _worker;
    if (existing != null) {
      return existing;
    }

    final readyCompleter = Completer<SendPort>();
    final receivePort = ReceivePort();
    final exitPort = ReceivePort();
    final errorPort = ReceivePort();

    // Ownership of this subscription is transferred to the _SpellCheckWorkerHandle constructed
    // below; it is cancelled by _killWorker/_handleWorkerDeath, not in this function.
    // ignore: cancel_subscriptions
    late final StreamSubscription<dynamic> messageSubscription;
    Isolate isolate;
    try {
      isolate = await Isolate.spawn(
        _spellCheckWorkerMain,
        receivePort.sendPort,
        onExit: exitPort.sendPort,
        onError: errorPort.sendPort,
      );
    } catch (error) {
      appLogger().e("A problem occurred when tried to spawn the spell-check worker isolate: "
          "$error");
      receivePort.close();
      exitPort.close();
      errorPort.close();
      return null;
    }

    messageSubscription = receivePort.listen((message) {
      if (!readyCompleter.isCompleted && message is SendPort) {
        readyCompleter.complete(message);
        return;
      }
      _handleWorkerMessage(message);
    });

    errorPort.listen((message) {
      appLogger().e("The spell-check worker isolate reported an error: $message");
    });

    exitPort.listen((_) {
      appLogger().w("The spell-check worker isolate exited");
      unawaited(_handleWorkerDeath());
    });

    final workerSendPort = await readyCompleter.future;
    final worker = _SpellCheckWorkerHandle(
      isolate: isolate,
      sendPort: workerSendPort,
      messageSubscription: messageSubscription,
      exitPort: exitPort,
      errorPort: errorPort,
    );
    _worker = worker;
    return worker;
  }

  /// Handles a message received from the worker isolate: a `_LoadResponse`, a `_CheckResponse` or
  /// a `_SuggestResponse`.
  void _handleWorkerMessage(Object? message) {
    switch (message) {
      case _LoadResponse(:final requestId):
        final pendingLoad = _pendingLoad;
        if (pendingLoad != null && pendingLoad.requestId == requestId) {
          _pendingLoad = null;
          pendingLoad.complete();
        }
      case _CheckResponse(:final requestId, :final rangesByIndex):
        final pending = _pendingChecks.remove(requestId);
        if (pending == null) {
          return;
        }
        if (pending.generation != _generation) {
          pending.resolveEmpty();
        } else {
          pending.resolve(rangesByIndex);
        }
      case _SuggestResponse(:final requestId, :final suggestions):
        final pending = _pendingSuggestions.remove(requestId);
        if (pending == null) {
          return;
        }
        if (pending.generation != _generation) {
          pending.resolveEmpty();
        } else {
          pending.resolve(suggestions);
        }
    }
  }

  /// The single in-flight `_LoadRequest` awaited by [useLanguage], or null. Only one load is ever
  /// in flight at a time (`useLanguage` is awaited to completion before it can be called again),
  /// so a single slot is enough.
  _PendingLoad? _pendingLoad;

  /// Kills the worker isolate (if any) and completes every pending request with a safe, empty
  /// answer rather than leaving it to hang.
  Future<void> _killWorker() async {
    final worker = _worker;
    _worker = null;
    if (worker == null) {
      return;
    }
    await worker.messageSubscription.cancel();
    worker.exitPort.close();
    worker.errorPort.close();
    worker.isolate.kill(priority: Isolate.immediate);
    _failAllPending();
  }

  /// Handles the worker isolate having exited on its own (a crash, most likely): clears the
  /// worker reference and completes every pending request with a safe, empty answer.
  Future<void> _handleWorkerDeath() async {
    final worker = _worker;
    if (worker == null) {
      return;
    }
    _worker = null;
    await worker.messageSubscription.cancel();
    worker.exitPort.close();
    worker.errorPort.close();
    _failAllPending();
  }

  /// Completes every pending [check]/[suggestionsFor]/load request with a safe, empty answer.
  void _failAllPending() {
    for (final pending in _pendingChecks.values) {
      pending.resolveEmpty();
    }
    _pendingChecks.clear();
    for (final pending in _pendingSuggestions.values) {
      pending.resolveEmpty();
    }
    _pendingSuggestions.clear();
    final pendingLoad = _pendingLoad;
    if (pendingLoad != null) {
      _pendingLoad = null;
      pendingLoad.complete();
    }
  }

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  @override
  Future<void> disposeLifeCycle() async {
    await _killWorker();
    return super.disposeLifeCycle();
  }
}

/// A pending [OcptSpellCheckManager.check] call: the generation it was issued under and the two
/// ways it can be resolved once a `_CheckResponse` (or a worker death) settles it.
class _PendingCheck {
  /// Creates a [_PendingCheck].
  _PendingCheck({required this.generation, required this.resolve, required this.resolveEmpty});

  /// The generation [OcptSpellCheckManager.check] was called under.
  final int generation;

  /// Completes the caller's future with the real answer.
  final void Function(Map<int, List<SpellRange>> rangesByIndex) resolve;

  /// Completes the caller's future with an empty map.
  final void Function() resolveEmpty;
}

/// A pending [OcptSpellCheckManager.suggestionsFor] call, the mirror of [_PendingCheck].
class _PendingSuggestion {
  /// Creates a [_PendingSuggestion].
  _PendingSuggestion({required this.generation, required this.resolve, required this.resolveEmpty});

  /// The generation [OcptSpellCheckManager.suggestionsFor] was called under.
  final int generation;

  /// Completes the caller's future with the real answer.
  final void Function(List<String> suggestions) resolve;

  /// Completes the caller's future with an empty list.
  final void Function() resolveEmpty;
}

/// A pending `_LoadRequest`, resolved either by its `_LoadResponse` or by the worker dying before
/// one arrives.
class _PendingLoad {
  /// Creates a [_PendingLoad].
  _PendingLoad({required this.requestId, required this.complete});

  /// The id of the `_LoadRequest` this is waiting on.
  final int requestId;

  /// Completes the caller's future — a load has nothing more to report than "done".
  final void Function() complete;
}

/// What [OcptSpellCheckManager] holds about its spawned worker isolate.
class _SpellCheckWorkerHandle {
  /// Creates a [_SpellCheckWorkerHandle].
  _SpellCheckWorkerHandle({
    required this.isolate,
    required this.sendPort,
    required this.messageSubscription,
    required this.exitPort,
    required this.errorPort,
  });

  /// The spawned isolate.
  final Isolate isolate;

  /// The port every request is sent through.
  final SendPort sendPort;

  /// The subscription reading every message the worker sends back.
  final StreamSubscription<dynamic> messageSubscription;

  /// The port the worker's exit is reported on.
  final ReceivePort exitPort;

  /// The port an uncaught error in the worker is reported on.
  final ReceivePort errorPort;
}

/// The base type of every message [OcptSpellCheckManager] sends to the worker isolate.
sealed class _WorkerRequest {
  /// Const constructor for subclasses.
  const _WorkerRequest();
}

/// Asks the worker to parse [affix]/[dictionary] into a fresh `SpellChecker`, replacing whatever
/// it held before.
class _LoadRequest extends _WorkerRequest {
  /// Creates a [_LoadRequest].
  const _LoadRequest({required this.requestId, required this.affix, required this.dictionary});

  /// The id the matching `_LoadResponse` carries back.
  final int requestId;

  /// The `.aff` file's contents.
  final String affix;

  /// The `.dic` file's contents.
  final String dictionary;
}

/// Asks the worker to check every text of [textsByIndex] for misspellings.
class _CheckRequest extends _WorkerRequest {
  /// Creates a [_CheckRequest].
  const _CheckRequest({required this.requestId, required this.textsByIndex});

  /// The id the matching `_CheckResponse` carries back.
  final int requestId;

  /// The texts to check, keyed by the index [OcptSpellCheckManager.check] assigned each of the
  /// caller's own keys.
  final Map<int, String> textsByIndex;
}

/// Asks the worker for up to five suggestions for [word].
class _SuggestRequest extends _WorkerRequest {
  /// Creates a [_SuggestRequest].
  const _SuggestRequest({required this.requestId, required this.word});

  /// The id the matching `_SuggestResponse` carries back.
  final int requestId;

  /// The word to suggest corrections for.
  final String word;
}

/// Tells the worker the current set of extra (ignored + learned) words to treat as known,
/// replacing whatever it held before. Fire-and-forget: nothing awaits this settling.
class _SetExtraWordsRequest extends _WorkerRequest {
  /// Creates a [_SetExtraWordsRequest].
  const _SetExtraWordsRequest({required this.words});

  /// The words to treat as known, in addition to the loaded dictionary.
  final Set<String> words;
}

/// The base type of every message the worker isolate sends back to [OcptSpellCheckManager].
sealed class _WorkerResponse {
  /// Const constructor for subclasses.
  const _WorkerResponse();
}

/// Answers a `_LoadRequest`: the dictionary has been parsed and is ready.
class _LoadResponse extends _WorkerResponse {
  /// Creates a [_LoadResponse].
  const _LoadResponse(this.requestId);

  /// The id of the `_LoadRequest` this answers.
  final int requestId;
}

/// Answers a `_CheckRequest` with the misspelled ranges found in each text.
class _CheckResponse extends _WorkerResponse {
  /// Creates a [_CheckResponse].
  const _CheckResponse(this.requestId, this.rangesByIndex);

  /// The id of the `_CheckRequest` this answers.
  final int requestId;

  /// The misspelled ranges found, keyed by the same index the request carried.
  final Map<int, List<SpellRange>> rangesByIndex;
}

/// Answers a `_SuggestRequest` with the suggestions found.
class _SuggestResponse extends _WorkerResponse {
  /// Creates a [_SuggestResponse].
  const _SuggestResponse(this.requestId, this.suggestions);

  /// The id of the `_SuggestRequest` this answers.
  final int requestId;

  /// The suggestions found, empty if none were or no dictionary was loaded.
  final List<String> suggestions;
}

/// The worker isolate's entry point, given the [mainSendPort] to hand its own [SendPort] back on
/// as its very first message (the handshake [OcptSpellCheckManager._ensureWorker] awaits).
///
/// Holds a `SpellChecker`/`SpellSuggester` pair once a `_LoadRequest` has been answered, and the
/// current extra-word set `_SetExtraWordsRequest` last pushed in. Never touches `rootBundle` or
/// anything Flutter: it only ever sees the two dictionary sources as plain strings, already read
/// by the manager on the main isolate.
void _spellCheckWorkerMain(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  SpellChecker? checker;
  SpellSuggester? suggester;

  receivePort.listen((Object? message) {
    switch (message) {
      case _LoadRequest(:final requestId, :final affix, :final dictionary):
        final parsed = SpellDictionary.parse(affix: affix, dictionary: dictionary);
        checker = SpellChecker(parsed);
        suggester = SpellSuggester(checker!);
        mainSendPort.send(_LoadResponse(requestId));
      case _CheckRequest(:final requestId, :final textsByIndex):
        final currentChecker = checker;
        final rangesByIndex = <int, List<SpellRange>>{};
        if (currentChecker != null) {
          final options = SpellTokenizerOptions.fromAffixFile(currentChecker.dictionary.affixFile);
          for (final entry in textsByIndex.entries) {
            rangesByIndex[entry.key] = currentChecker.misspellingsIn(
              entry.value,
              options: options,
            );
          }
        }
        mainSendPort.send(_CheckResponse(requestId, rangesByIndex));
      case _SuggestRequest(:final requestId, :final word):
        final currentSuggester = suggester;
        final suggestions = currentSuggester?.suggestionsFor(word) ?? const <String>[];
        mainSendPort.send(_SuggestResponse(requestId, suggestions));
      case _SetExtraWordsRequest(:final words):
        checker?.setExtraWords(words);
    }
  });
}

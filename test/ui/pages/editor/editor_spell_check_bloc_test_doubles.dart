// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_spell_check_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_spell_check_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_spell_check_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:spell_kit/spell_kit.dart';

/// The app language every projects manager built here is given, so a created project's own
/// screenplay language never depends on the machine the tests run on.
String testAppLanguageCode() => "en";

/// A router manager whose [pop] only records that it was called: these bloc tests don't build a
/// real GoRouter for it to operate on.
///
/// [onPop] lets a test await the exact moment [pop] is called, rather than racing on an unrelated
/// state emitted earlier in the same event handler (the emitted state and the handler's own
/// completion are not ordered with respect to a stream listener in the test).
class RecordingRouterManager extends OcptRouterManager {
  /// Completes when [pop] is called, so a test can wait for it.
  final _popCompleter = Completer<void>();

  /// Whether [pop] was called.
  bool get popped => _popCompleter.isCompleted;

  /// Completes the moment [pop] is called.
  Future<void> get onPop => _popCompleter.future;

  /// Records the call instead of delegating to the (never initialized) GoRouter.
  @override
  void pop<Y extends Object?>([Y? result]) {
    if (!_popCompleter.isCompleted) {
      _popCompleter.complete();
    }
  }
}

/// An export manager that is never asked for anything: the mode bloc needs one, these tests do not
/// export.
class InertExportManager extends OcptExportManager {
  /// Class constructor
  InertExportManager() : super(fileSelectorManager: const FileSelectorManager());
}

/// A spell-check manager whose language and dictionary the test controls.
class FakeSpellCheckManager extends OcptSpellCheckManager {
  /// Every [check] call's requested texts, keyed the same way the bloc addresses them (a raw-mode
  /// block index, or a styled-mode node id), in call order.
  final List<Map<Object, String>> checkCalls = [];

  /// Computes [check]'s answer for a request; overridable per test.
  Map<Object, List<SpellRange>> Function(Map<Object, String> requested) answerFor = (requested) => {
    for (final entry in requested.entries) entry.key: [SpellRange(0, entry.value.length)],
  };

  /// When set, [check] awaits this before resolving — a test's way of holding an isolate round
  /// trip open long enough to change something (the language, most plainly) out from under it, to
  /// exercise the "a stale generation's answer is dropped" path.
  Completer<void>? gate;

  /// Every [suggestionsFor] call's requested word, in call order.
  final List<String> suggestionsForCalls = [];

  /// Computes [suggestionsFor]'s answer for a word; overridable per test.
  List<String> Function(String word) suggestionsAnswer = (word) => const [];

  /// Every [ignoreWords] call's whole replacement set, in call order.
  final List<Set<String>> ignoreWordsCalls = [];

  /// Every word [ignoreWord] was called with, in call order — this fake's own accumulation,
  /// mirroring the real manager's (`docs/architecture/screenplay.md`), so a test can assert both
  /// that the manager was reached and that the accumulation actually happened.
  final List<String> ignoredWords = [];

  /// Every [setLearnedWords] call's whole replacement set, in call order.
  final List<Set<String>> setLearnedWordsCalls = [];

  /// The language loaded, or null before any.
  OcptScreenplayLanguage? _loadedLanguage;

  /// The generation, which moves on whenever the checker's verdicts may change.
  int _generation = 0;

  /// Read the language loaded.
  @override
  OcptScreenplayLanguage? get loadedLanguage => _loadedLanguage;

  /// Read the generation.
  @override
  int get generation => _generation;

  /// Load [language] and move the generation on, unless it is already the one loaded.
  @override
  Future<void> useLanguage(OcptScreenplayLanguage? language) async {
    if (language == _loadedLanguage) {
      return;
    }
    _loadedLanguage = language;
    _generation++;
  }

  /// Record the texts asked about, wait for the gate when there is one, and answer with the canned
  /// ranges.
  @override
  Future<Map<K, List<SpellRange>>> check<K>(Map<K, String> textsByKey) async {
    final requested = <Object, String>{
      for (final entry in textsByKey.entries) entry.key as Object: entry.value,
    };
    checkCalls.add(requested);

    final pendingGate = gate;
    if (pendingGate != null) {
      await pendingGate.future;
    }

    final answer = answerFor(requested);
    return {
      for (final entry in textsByKey.entries)
        if (answer[entry.key as Object] != null) entry.key: answer[entry.key as Object]!,
    };
  }

  /// Record the word and answer with the canned suggestions.
  @override
  Future<List<String>> suggestionsFor(String word) async {
    suggestionsForCalls.add(word);
    return suggestionsAnswer(word);
  }

  /// Record the words and move the generation on.
  @override
  void ignoreWords(Set<String> words) {
    ignoreWordsCalls.add(words);
    _generation++;
  }

  /// Record the word and move the generation on.
  @override
  void ignoreWord(String word) {
    ignoredWords.add(word);
    _generation++;
  }

  /// Record the words and move the generation on.
  @override
  void setLearnedWords(Set<String> words) {
    setLearnedWordsCalls.add(words);
    _generation++;
  }
}

/// The fields of both blocs these tests read, each answered by the bloc that owns it.
class EditorStates {
  /// The mode bloc's state.
  final OcptEditorState mode;

  /// The spell-check bloc's state.
  final OcptEditorSpellCheckState spell;

  /// Read whether the mode is loading.
  bool get isLoading => mode.isLoading;

  /// Read whether the mode is previewing a version.
  bool get isPreviewingVersion => mode.isPreviewingVersion;

  /// Read whether the spell check is visible in the mode.
  bool get isSpellCheckVisible => mode.isSpellCheckVisible;

  /// Read the screenplay language of the mode.
  OcptScreenplayLanguage? get screenplayLanguage => mode.screenplayLanguage;

  /// Read the document of the mode.
  FountainDocument? get document => mode.document;

  /// Read the page setup of the mode.
  OcptPageSetup get pageSetup => mode.pageSetup;

  /// Read the scene headings of the mode.
  List<FountainSceneHeading> get scenes => mode.scenes;

  /// Read the ranges of the raw editor.
  List<SpellRange> get rawSpellCheckRanges => spell.rawSpellCheckRanges;

  /// Read the ranges of the styled editor.
  Map<String, List<SpellRange>> get styledSpellCheckRanges => spell.styledSpellCheckRanges;

  /// Class constructor
  const EditorStates(this.mode, this.spell);
}

/// The mode bloc and the spell-check bloc built together, the way the editor page builds them:
/// an event goes to the bloc that handles it, and a state is read off the bloc that owns it.
class Editor {
  /// The mode bloc.
  final OcptEditorBloc mode;

  /// The spell-check bloc.
  final OcptEditorSpellCheckBloc spell;

  /// Both blocs' current states.
  EditorStates get state => EditorStates(mode.state, spell.state);

  /// Both blocs' states, one per emit of either.
  Stream<EditorStates> get stream => Stream.multi((controller) {
    final subscriptions = [
      mode.stream.listen((_) => controller.add(state)),
      spell.stream.listen((_) => controller.add(state)),
    ];
    controller.onCancel = () {
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
    };
  }, isBroadcast: true);

  /// Class constructor
  Editor(this.mode, this.spell);

  /// Sends [event] to the bloc that handles it.
  void add(BlocEventForMixin event) =>
      event is OcptEditorSpellCheckEvent ? spell.add(event) : mode.add(event);

  /// Answers the styled editor's context menu, see `OcptEditorSpellCheckBloc.spellingSuggestionsFor`.
  Future<List<String>> spellingSuggestionsFor(String word) => spell.spellingSuggestionsFor(word);

  /// Closes both blocs, the spell-check one first as the tree does.
  Future<void> close() async {
    await spell.close();
    await mode.close();
  }
}

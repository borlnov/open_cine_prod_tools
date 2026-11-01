// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/ocpt_spell_check_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_project_dictionary_service.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_spell_checked_lines.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_reload_cause.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_spell_check_state.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_state.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/abs_ocpt_view_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_view_events.dart';
import 'package:spell_kit/spell_kit.dart';

/// This is the bloc class for the screenplay editor's spell-check: the underlines of both editing
/// surfaces, the two caches that keep a keystroke from re-checking the whole screenplay, the words
/// a writer teaches the checker, and the suggestions of the styled editor's context menu.
///
/// Whether anything is checked at all is the mode's to say: the machine-wide switch
/// (`OcptEditorState.isSpellCheckVisible`) and the project's language
/// (`OcptEditorState.screenplayLanguage`) are two independent on/off switches
/// (`docs/architecture/screenplay.md`), and every pass here reads them, and whether a version is
/// being previewed, off the mode's state at the moment it runs.
///
/// It reacts to the mode's state in three ways. A whole load (entry, a version preview, a restore)
/// drops both caches and every underline, pushes the project's learned words into
/// [OcptSpellCheckManager] and drives its dictionary to match. A new document (the parse debounce,
/// an import, a title page rewrite) or the raw mode becoming the mounted one requests a raw pass,
/// which is a no-op in styled mode. A change of the switch or of the language drives the dictionary
/// again, and clears the underlines when the switch is now off.
class OcptEditorSpellCheckBloc
    extends AbsOcptViewBloc<OcptEditorSpellCheckState, OcptEditorState, OcptEditorBloc> {
  /// The manager owning the spell-check worker isolate this bloc requests checks from.
  final OcptSpellCheckManager _spellCheckManager;

  /// The manager used to access the project currently open.
  final OcptProjectsManager _projectsManager;

  /// The service used to read and grow the open project's own learned-word dictionary
  /// ("Add to the project's dictionary").
  final OcptProjectDictionaryService _projectDictionaryService;

  /// The subscription to the mode's states, for what the epochs do not tell.
  late final StreamSubscription<OcptEditorState> _modeStates;

  /// The mode state [_onModeState] saw last, to tell what moved.
  OcptEditorState _previousModeState;

  /// Class constructor
  ///
  /// Every dependency but [modeBloc] can be overridden, which is what the tests do: a test hands in
  /// a fake [OcptSpellCheckManager] rather than the real, isolate-backed one.
  OcptEditorSpellCheckBloc({
    required super.modeBloc,
    OcptSpellCheckManager? spellCheckManager,
    OcptProjectsManager? projectsManager,
    OcptProjectDictionaryService? projectDictionaryService,
  }) : _spellCheckManager = spellCheckManager ?? globalGetIt().get<OcptSpellCheckManager>(),
       _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
       _projectDictionaryService =
           projectDictionaryService ??
           (projectsManager ?? globalGetIt().get<OcptProjectsManager>()).projectDictionaryService,
       _previousModeState = modeBloc.state,
       super(OcptEditorSpellCheckState.init()) {
    _modeStates = modeBloc.stream.listen(_onModeState);
  }

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptEditorSpellCheckRangesReportedEvent>(_onSpellCheckRangesReported);
    on<OcptEditorStyledSpellCheckTextsReportedEvent>(_onStyledSpellCheckTextsReported);
    on<OcptEditorStyledSpellCheckRangesReportedEvent>(_onStyledSpellCheckRangesReported);
    on<OcptEditorWordIgnoredEvent>(_onWordIgnored);
    on<OcptEditorWordLearnedEvent>(_onWordLearned);
    on<OcptEditorSpellCheckSettingsChangedEvent>(_onSettingsChanged);
    on<OcptEditorSpellCheckDictionaryRefreshRequestedEvent>(_onDictionaryRefreshRequested);
  }

  /// Starts afresh after a whole load: the document the caches and the underlines describe is gone.
  ///
  /// Both caches are dropped, because an episode switch, a version preview entering or leaving and
  /// the very first load all hand the passes a document built from a different Fountain source, and
  /// keeping either around risks a stale entry coincidentally matching a new block's or node's text.
  /// The styled editor rebuilds its own document from scratch on the very same triggers, so it
  /// reports a fresh set of node ids on its own. Every underline goes too, so a stale one never
  /// survives the swap; the raw pass repopulates its own once the dictionary is ready.
  ///
  /// The open project's own learned words are pushed into the manager right here, on every load: an
  /// episode switch and a version restore both come through here, and the manager is one
  /// process-wide instance holding whichever project's words were pushed in last. Nothing is read
  /// with no project open, there being no database to read a word list from. The dictionary itself
  /// is never awaited: loading a language can take ~300 ms the first time.
  @override
  Future<void> onModeStateChanged(
    OcptViewModeStateChangedEvent<OcptEditorState> event,
    Emitter<OcptEditorSpellCheckState> emitter,
  ) async {
    if (!event.hasReloaded || event.modeState.reloadCause != OcptEditorReloadCause.load) {
      return;
    }

    state.caches.clear();
    emitter(state.copyWith(rawSpellCheckRanges: const [], styledSpellCheckRanges: const {}));

    final project = _projectsManager.currentProject;
    if (project != null) {
      final learnedWords = await _projectDictionaryService.loadWords(database: project.database);
      state.caches.pushedLearnedWords = learnedWords.toSet();
      _spellCheckManager.setLearnedWords(state.caches.pushedLearnedWords);
    }

    unawaited(_reconcileSpellCheckLanguage());
  }

  /// Turns what the mode's state moved, other than a whole load, into a check or a dictionary
  /// update.
  ///
  /// A new document asks for a raw pass exactly where `docs/architecture/screenplay.md` puts it: on
  /// the parse debounce, never a keystroke. The raw mode becoming the mounted one asks for one too,
  /// because the pass is a no-op while any other mode is mounted, so the underlines can otherwise
  /// sit unrefreshed for as long as the styled editor was showing; the styled mode's own equivalent
  /// needs no such nudge, the styled editor reporting its checkable texts fresh the moment it
  /// (re)mounts.
  void _onModeState(OcptEditorState next) {
    final previous = _previousModeState;
    _previousModeState = next;

    final isLoad =
        next.reloadEpoch > previous.reloadEpoch && next.reloadCause == OcptEditorReloadCause.load;
    if (isClosing || isLoad) {
      return;
    }

    if (previous.screenplayLanguage != next.screenplayLanguage ||
        previous.isSpellCheckVisible != next.isSpellCheckVisible) {
      add(const OcptEditorSpellCheckSettingsChangedEvent());
    }

    final becameRaw = next.mode == OcptEditorMode.raw && previous.mode != OcptEditorMode.raw;
    if (becameRaw || previous.document != next.document) {
      _requestSpellCheck();
    }
  }

  /// Answers [OcptEditorSpellCheckSettingsChangedEvent].
  ///
  /// Switching off clears both sets of ranges right here, synchronously, rather than waiting for
  /// [_reconcileSpellCheckLanguage]'s own async tail: with the switch off, [_requestSpellCheck] never
  /// runs again (and the styled editor reports nothing to check — its own `isSpellCheckVisible`
  /// parameter, mirrored from the mode's state), so nothing would otherwise clear a stale underline
  /// still on screen in either mode. Switching on leaves the (already empty) ranges alone — the very
  /// next check answers them for real.
  Future<void> _onSettingsChanged(
    OcptEditorSpellCheckSettingsChangedEvent event,
    Emitter<OcptEditorSpellCheckState> emitter,
  ) async {
    if (!modeBloc.state.isSpellCheckVisible) {
      emitter(state.copyWith(rawSpellCheckRanges: const [], styledSpellCheckRanges: const {}));
    }

    unawaited(_reconcileSpellCheckLanguage());
  }

  /// Answers [OcptEditorSpellCheckDictionaryRefreshRequestedEvent].
  ///
  /// The dictionary re-read is compared against the words pushed last with `setEquals` before
  /// pushing anything: this event fires on *every* settings-page change, including one that never
  /// touched the dictionary at all, and pushing unconditionally would re-check the whole screenplay
  /// on a currency edit. When the set genuinely differs — a word un-learned, or learned, in
  /// `OcptProjectDictionaryDialog` since the last push — [OcptSpellCheckManager.setLearnedWords]
  /// bumps the manager's generation and both [_requestSpellCheck] and [_reissueStyledSpellCheck]
  /// re-send everything they have, which is what makes a word un-learned there underlined again here
  /// without anything having to be re-typed (`docs/architecture/foundations.md`, the project
  /// dictionary's own round trip).
  Future<void> _onDictionaryRefreshRequested(
    OcptEditorSpellCheckDictionaryRefreshRequestedEvent event,
    Emitter<OcptEditorSpellCheckState> emitter,
  ) async {
    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    final learnedWords = await _projectDictionaryService.loadWords(database: project.database);
    final learnedWordsSet = learnedWords.toSet();
    if (!setEquals(learnedWordsSet, state.caches.pushedLearnedWords)) {
      state.caches.pushedLearnedWords = learnedWordsSet;
      _spellCheckManager.setLearnedWords(state.caches.pushedLearnedWords);
      _requestSpellCheck();
      _reissueStyledSpellCheck();
    }
  }

  /// Answers [OcptEditorSpellCheckRangesReportedEvent], the async tail of [_requestSpellCheck].
  ///
  /// Drops the answer (a stale generation's answer is never painted,
  /// `docs/architecture/screenplay.md`) when: [OcptEditorSpellCheckRangesReportedEvent.generation]
  /// no longer matches [OcptSpellCheckManager.generation] (a language change, or a word learned or
  /// ignored, happened while the isolate round trip was in flight); spell-checking is now off
  /// (either switch) or a version is now being previewed (both can have flipped mid-flight too); or
  /// [OcptEditorSpellCheckRangesReportedEvent.checkedText] no longer matches
  /// `OcptEditorState.document`'s own `sourceText` — the document has moved on to a newer parse
  /// since this request was issued, and painting these ranges over it would misplace every one of
  /// them.
  Future<void> _onSpellCheckRangesReported(
    OcptEditorSpellCheckRangesReportedEvent event,
    Emitter<OcptEditorSpellCheckState> emitter,
  ) async {
    if (event.generation != _spellCheckManager.generation) {
      return;
    }
    if (modeBloc.state.isPreviewingVersion ||
        !modeBloc.state.isSpellCheckVisible ||
        modeBloc.state.screenplayLanguage == null) {
      return;
    }
    final document = modeBloc.state.document;
    if (document == null || document.sourceText != event.checkedText) {
      return;
    }

    emitter(state.copyWith(rawSpellCheckRanges: event.ranges));
  }

  /// Answers [OcptEditorStyledSpellCheckTextsReportedEvent], the styled mode's own counterpart to
  /// the raw mode's trigger: fires a check over `event.textsByNodeId` without
  /// awaiting the isolate round trip (an [Emitter] can't be used once this handler has returned),
  /// answered back as its own [OcptEditorStyledSpellCheckRangesReportedEvent].
  ///
  /// A no-op — nothing sent, [OcptEditorSpellCheckState.styledSpellCheckRanges] left exactly as it is — while
  /// a version is being previewed or spell-checking is off (either switch): the styled editor
  /// itself already withholds every checkable text under those same conditions (its own
  /// `isSpellCheckVisible` parameter, and it is simply never mounted under a preview), so this
  /// event would only ever carry an empty map then in practice, but the guard is kept here too for
  /// the same reason [_requestSpellCheck]'s own guard is: a stray event arriving right as either
  /// switch flips underneath it must never reach the manager.
  ///
  /// Only *changed* texts are sent to [OcptSpellCheckManager.check], mirroring
  /// [_requestSpellCheck]'s own dedup and for the identical reason — a keystroke in one node costs
  /// one node's check, not the whole reported set — except keyed by node id rather than by a
  /// positional block index: a node id is already a stable key on its own (see
  /// `OcptEditorSpellCheckCaches.styled`'s own doc comment), so no offset-translation step is needed when
  /// re-assembling the answer.
  Future<void> _onStyledSpellCheckTextsReported(
    OcptEditorStyledSpellCheckTextsReportedEvent event,
    Emitter<OcptEditorSpellCheckState> emitter,
  ) async {
    // Remembered unconditionally, even under a guard below that turns the rest of this handler
    // into a no-op: [_onWordIgnored]/[_onWordLearned] re-issue a check over exactly what was last
    // reported, and they must never re-issue one over a stale set left over from before spell-
    // checking was switched off.
    state.caches.lastStyledTexts = event.textsByNodeId;

    if (modeBloc.state.isPreviewingVersion) {
      return;
    }
    if (!modeBloc.state.isSpellCheckVisible || modeBloc.state.screenplayLanguage == null) {
      return;
    }

    _requestStyledSpellCheck(event.textsByNodeId);
  }

  /// Fires a styled-mode spell-check request over [textsByNodeId], without awaiting the isolate
  /// round trip — the async tail this handler's callers can't stick around for arrives as its own
  /// [OcptEditorStyledSpellCheckRangesReportedEvent]. The body [_onStyledSpellCheckTextsReported]
  /// used to run inline before its own dedup/re-check needs ([_onWordIgnored]/[_onWordLearned])
  /// made a second caller of the exact same steps worth factoring out.
  void _requestStyledSpellCheck(Map<String, String> textsByNodeId) {
    _resetStyledSpellCheckCacheIfStale();

    final textsToSend = <String, String>{
      for (final entry in textsByNodeId.entries)
        if (state.caches.styled[entry.key]?.text != entry.value) entry.key: entry.value,
    };
    state.caches.styled.removeWhere((nodeId, _) => !textsByNodeId.containsKey(nodeId));

    final requestGeneration = _spellCheckManager.generation;

    unawaited(
      _spellCheckManager.check(textsToSend).then((rangesByNodeId) {
        if (isClosing) {
          return;
        }

        for (final entry in rangesByNodeId.entries) {
          final text = textsToSend[entry.key];
          if (text == null) {
            continue;
          }
          state.caches.styled[entry.key] = (
            text: text,
            ranges: _dropSkippedSpellRanges(entry.value, text),
          );
        }

        final ranges = <String, List<SpellRange>>{
          for (final nodeId in textsByNodeId.keys)
            if (state.caches.styled[nodeId] != null) nodeId: state.caches.styled[nodeId]!.ranges,
        };

        add(
          OcptEditorStyledSpellCheckRangesReportedEvent(
            generation: requestGeneration,
            ranges: ranges,
          ),
        );
      }),
    );
  }

  /// Re-issues a styled-mode check over the texts the styled editor last reported — used by [_onWordIgnored]/
  /// [_onWordLearned], whose own [OcptSpellCheckManager.ignoreWord]/[OcptSpellCheckManager
  /// .setLearnedWords] call already bumped the manager's generation, which is what makes
  /// [_requestStyledSpellCheck]'s own [_resetStyledSpellCheckCacheIfStale] treat every one of
  /// these texts as needing a fresh answer even though none of them actually changed: the styled
  /// editor itself has nothing to report here, since no text changed either.
  ///
  /// A no-op under the same two conditions [_onStyledSpellCheckTextsReported] guards its own call
  /// on (spell-checking off by either switch); a version preview is guarded by the caller instead,
  /// since both callers refuse their whole event under one.
  void _reissueStyledSpellCheck() {
    if (!modeBloc.state.isSpellCheckVisible || modeBloc.state.screenplayLanguage == null) {
      return;
    }
    _requestStyledSpellCheck(state.caches.lastStyledTexts);
  }

  /// Answers [OcptEditorStyledSpellCheckRangesReportedEvent], the async tail of
  /// [_onStyledSpellCheckTextsReported].
  ///
  /// Drops the answer under the same three conditions [_onSpellCheckRangesReported] does, minus the
  /// `checkedText` comparison that event has no counterpart for: ranges here are keyed by node id
  /// rather than by document-absolute offset, so a range computed against a node's text that has
  /// since changed is instead clamped and dropped by the styled editor itself, at the point it's
  /// turned into a `TextError` (see [OcptEditorStyledSpellCheckRangesReportedEvent]'s own doc
  /// comment) — the very last of those guards, and the one place left that can
  /// actually tell a node's *current* text length from here.
  Future<void> _onStyledSpellCheckRangesReported(
    OcptEditorStyledSpellCheckRangesReportedEvent event,
    Emitter<OcptEditorSpellCheckState> emitter,
  ) async {
    if (event.generation != _spellCheckManager.generation) {
      return;
    }
    if (modeBloc.state.isPreviewingVersion ||
        !modeBloc.state.isSpellCheckVisible ||
        modeBloc.state.screenplayLanguage == null) {
      return;
    }

    emitter(state.copyWith(styledSpellCheckRanges: event.ranges));
  }

  /// Returns up to five spelling suggestions for [word] — the answer the styled editor's
  /// right-click context menu awaits before it can show its suggestion entries at all
  /// (`docs/architecture/screenplay.md`). This is a plain method the page `await`s
  /// rather than a dispatched event, deliberately: an event has no channel back to its caller, and
  /// a right-click can afford the one isolate round trip this costs (~1 ms once the dictionary is
  /// warm) far better than every other spell-check path in this bloc could afford waiting on one.
  ///
  /// Returns `const []` immediately, with no isolate round trip at all, while spell-checking is
  /// off (either `OcptEditorState.isSpellCheckVisible` or `OcptEditorState.screenplayLanguage` says
  /// so) or a version is being previewed — the same three conditions every other spell-check path
  /// here guards on.
  Future<List<String>> spellingSuggestionsFor(String word) {
    if (modeBloc.state.isPreviewingVersion ||
        !modeBloc.state.isSpellCheckVisible ||
        modeBloc.state.screenplayLanguage == null) {
      return Future.value(const []);
    }
    return _spellCheckManager.suggestionsFor(word);
  }

  /// Answers [OcptEditorWordIgnoredEvent]: tells [OcptSpellCheckManager.ignoreWord] and re-issues a
  /// check over both editing surfaces — the manager's own generation bump has just invalidated both
  /// spell-check caches, so [_requestSpellCheck] (raw) and [_reissueStyledSpellCheck] (styled) both
  /// re-send everything they have rather than skipping it as unchanged, which is what makes the
  /// ignored word's underline disappear without anything having to be re-typed.
  ///
  /// Refused entirely while a version is being previewed, like every other write this bloc makes.
  Future<void> _onWordIgnored(
    OcptEditorWordIgnoredEvent event,
    Emitter<OcptEditorSpellCheckState> emitter,
  ) async {
    if (modeBloc.state.isPreviewingVersion) {
      return;
    }

    _spellCheckManager.ignoreWord(event.word);
    _requestSpellCheck();
    _reissueStyledSpellCheck();
  }

  /// Answers [OcptEditorWordLearnedEvent]: teaches the event's word to the open project's
  /// dictionary through [_projectDictionaryService], reloads its word list and pushes it into
  /// [OcptSpellCheckManager.setLearnedWords], then re-issues a check over both editing surfaces for
  /// the identical reason [_onWordIgnored] does.
  ///
  /// A no-op with no project open. Refused entirely while a version is being previewed, like every
  /// other write this bloc makes.
  Future<void> _onWordLearned(
    OcptEditorWordLearnedEvent event,
    Emitter<OcptEditorSpellCheckState> emitter,
  ) async {
    if (modeBloc.state.isPreviewingVersion) {
      return;
    }

    final project = _projectsManager.currentProject;
    if (project == null) {
      return;
    }

    await _projectDictionaryService.learnWord(database: project.database, word: event.word);
    final learnedWords = await _projectDictionaryService.loadWords(database: project.database);
    state.caches.pushedLearnedWords = learnedWords.toSet();
    _spellCheckManager.setLearnedWords(state.caches.pushedLearnedWords);

    _requestSpellCheck();
    _reissueStyledSpellCheck();
  }

  /// Loads or unloads `OcptSpellCheckManager`'s dictionary to match
  /// `OcptEditorState.screenplayLanguage`/[OcptEditorState.isSpellCheckVisible] (the two
  /// independent on/off switches of `docs/architecture/screenplay.md`: with either off, the
  /// isolate stays unloaded and nothing is checked), then requests a fresh raw-mode pass so the
  /// underlines catch up once a dictionary that needed loading has actually finished doing so.
  ///
  /// Never awaited by its own callers ([onModeStateChanged], [_onSettingsChanged]): `OcptSpellCheckManager.useLanguage` can take ~300 ms the first
  /// time a language loads, and none of them should hold the editor's own state update back for
  /// it.
  Future<void> _reconcileSpellCheckLanguage() async {
    final wantsSpellCheck =
        modeBloc.state.isSpellCheckVisible && modeBloc.state.screenplayLanguage != null;
    await _spellCheckManager.useLanguage(
      wantsSpellCheck ? modeBloc.state.screenplayLanguage : null,
    );
    if (isClosing) {
      return;
    }
    _requestSpellCheck();
  }

  /// Clears `OcptEditorSpellCheckCaches.raw` the first time it is asked to work under a different (language,
  /// visibility, manager generation) combination than the one it was last built under: a cached
  /// entry was found by a dictionary, ignore list or learned-word set that has since changed
  /// (`OcptSpellCheckManager.generation` bumps on every one of those), and keeping it around would
  /// answer with a checker that no longer exists.
  void _resetSpellCheckCacheIfStale() {
    final key = (
      language: modeBloc.state.screenplayLanguage,
      isVisible: modeBloc.state.isSpellCheckVisible,
      generation: _spellCheckManager.generation,
    );
    if (key == state.caches.rawKey) {
      return;
    }
    state.caches.raw.clear();
    state.caches.rawKey = key;
  }

  /// Clears `OcptEditorSpellCheckCaches.styled` the first time it is asked to work under a different
  /// (language, visibility, manager generation) combination than the one it was last built under —
  /// the styled mode's own counterpart to [_resetSpellCheckCacheIfStale], same reasoning.
  void _resetStyledSpellCheckCacheIfStale() {
    final key = (
      language: modeBloc.state.screenplayLanguage,
      isVisible: modeBloc.state.isSpellCheckVisible,
      generation: _spellCheckManager.generation,
    );
    if (key == state.caches.styledKey) {
      return;
    }
    state.caches.styled.clear();
    state.caches.styledKey = key;
  }

  /// Fires a raw-mode spell-check request over `modeBloc.state.document`'s prose blocks, without awaiting
  /// the isolate round trip: the answer arrives later as its own
  /// [OcptEditorSpellCheckRangesReportedEvent], since an [Emitter] can't be used once the handler
  /// that called this has already returned (true of every caller: [_onModeState]'s own parse
  /// debounce tick, and [_reconcileSpellCheckLanguage]'s async tail).
  ///
  /// A no-op while a version is being previewed, while spell-checking is off (either switch), or
  /// while the styled mode is the one mounted — the raw controller is the only thing that ever
  /// paints [OcptEditorSpellCheckState.rawSpellCheckRanges] (`OcptEditorSearchTextController`, wired only
  /// into `OcptEditorSourceField`), so a styled-mode pass here would be an isolate round trip for a
  /// squiggle nothing paints. In every no-op case [OcptEditorSpellCheckState.rawSpellCheckRanges] is left
  /// exactly as it is: [_onSettingsChanged] already clears it synchronously the moment the switch
  /// flips off, so there is nothing stale left for this method to clear, and [_onModeState] is
  /// what calls this again the moment raw mode becomes the mounted one, so the field never answers
  /// with a document version older than whatever raw mode is about to show.
  ///
  /// Only *changed* texts are sent to [OcptSpellCheckManager.check]
  /// (`docs/architecture/screenplay.md`): [_rawSpellCheckBlocksOf] keys every checked block by its
  /// index in the walk order, and `OcptEditorSpellCheckCaches.raw` is compared against by that same index, so
  /// a block whose own source text hasn't changed since the index last held it is skipped.
  /// `OcptSpellCheckManager .check` itself fast-paths an empty request map to an empty answer with
  /// no isolate round trip at all (its own doc comment), so calling it unconditionally here — even
  /// when nothing changed — costs nothing extra while still re-assembling and re-reporting the
  /// full, current set of absolute ranges: a block's cached *relative* ranges are re-translated by
  /// its *current* `startOffset` on every pass, which is what keeps an edit to an earlier,
  /// unrelated block from leaving every later misspelling underlined in the wrong place.
  void _requestSpellCheck() {
    final document = modeBloc.state.document;
    if (document == null ||
        modeBloc.state.isPreviewingVersion ||
        modeBloc.state.mode != OcptEditorMode.raw) {
      return;
    }
    if (!modeBloc.state.isSpellCheckVisible || modeBloc.state.screenplayLanguage == null) {
      return;
    }

    _resetSpellCheckCacheIfStale();

    final blocks = _rawSpellCheckBlocksOf(document);
    final textsToSend = <int, String>{
      for (final block in blocks)
        if (state.caches.raw[block.index]?.text != block.text) block.index: block.text,
    };
    final liveIndices = blocks.map((block) => block.index).toSet();
    state.caches.raw.removeWhere((index, _) => !liveIndices.contains(index));

    final requestGeneration = _spellCheckManager.generation;
    final checkedText = document.sourceText;

    unawaited(
      _spellCheckManager.check(textsToSend).then((rangesByIndex) {
        if (isClosing) {
          return;
        }

        for (final entry in rangesByIndex.entries) {
          final blockText = textsToSend[entry.key];
          if (blockText == null) {
            continue;
          }
          state.caches.raw[entry.key] = (
            text: blockText,
            ranges: _dropSkippedSpellRanges(entry.value, blockText),
          );
        }

        final absoluteRanges = <SpellRange>[
          for (final block in blocks)
            for (final relative in state.caches.raw[block.index]?.ranges ?? const <SpellRange>[])
              SpellRange(relative.start + block.startOffset, relative.end + block.startOffset),
        ];

        add(
          OcptEditorSpellCheckRangesReportedEvent(
            generation: requestGeneration,
            checkedText: checkedText,
            ranges: absoluteRanges,
          ),
        );
      }),
    );
  }

  /// The screenplay's own prose blocks of [document], walked in source order and addressed by a
  /// dense 0-based index over just those blocks (a `FountainSceneHeading`, unchecked, is simply
  /// never given one — [_requestSpellCheck]'s cache is bounded by how many *checked* blocks the
  /// screenplay holds, not by its block count as a whole).
  ///
  /// Recurses into a `FountainDialogueGroup`'s `children` rather than ever handing the group itself
  /// to [ocptLineTypeOfBlock] (which answers null for it, per that function's own doc comment): the
  /// group is a container, and its cue and its dialogue lines each carry their own line type. A
  /// [_RawSpellCheckBlock]'s own `text` is a block's own substring of [FountainDocument.sourceText]
  /// — the exact text raw mode displays and its `OcptEditorSearchTextController` paints offsets
  /// into, which is not necessarily [OcptEditorState.text]: the parser may have normalized the
  /// source's line endings, so the two can disagree on length and offsets even when they read the
  /// same.
  List<_RawSpellCheckBlock> _rawSpellCheckBlocksOf(FountainDocument document) {
    final result = <_RawSpellCheckBlock>[];
    var index = 0;

    void visit(FountainBlock block) {
      if (block is FountainDialogueGroup) {
        for (final child in block.children) {
          visit(child);
        }
        return;
      }

      final lineType = ocptLineTypeOfBlock(block);
      if (lineType == null || !ocptIsSpellCheckedLineType(lineType)) {
        return;
      }

      final range = block.sourceRange;
      result.add((
        index: index++,
        text: document.sourceText.substring(range.startOffset, range.endOffset),
        startOffset: range.startOffset,
      ));
    }

    for (final block in document.blocks) {
      visit(block);
    }

    return result;
  }

  /// {@macro act_life_cycle.MixinWithLifeCycleDispose.disposeLifeCycle}
  @override
  Future<void> disposeLifeCycle() async {
    unawaited(_modeStates.cancel());
    return super.disposeLifeCycle();
  }
}

/// One block `OcptEditorSpellCheckBloc._rawSpellCheckBlocksOf` hands back: `index` is this block's position
/// among only the checked blocks (its `OcptEditorBloc.state.caches.raw` key), `text` is its own
/// substring of [FountainDocument.sourceText], and `startOffset` is where that substring begins in
/// the document, used to translate the manager's block-relative [SpellRange]s back into
/// document-absolute ones.
typedef _RawSpellCheckBlock = ({int index, String text, int startOffset});

/// Drops every range of [misspellings] that falls inside one of [text]'s own
/// [ocptSpellCheckSkipSpansIn] spans — an inline authoring note or boneyard comment sitting inside
/// a line of action or dialogue is scaffolding, not the script, per that function's own doc
/// comment. [misspellings] and the spans it's tested against are both relative to the very same
/// [text], so no offset translation is needed here.
List<SpellRange> _dropSkippedSpellRanges(List<SpellRange> misspellings, String text) {
  final skipSpans = ocptSpellCheckSkipSpansIn(text);
  if (skipSpans.isEmpty) {
    return misspellings;
  }

  return [
    for (final range in misspellings)
      if (!skipSpans.any((span) => range.start >= span.start && range.end <= span.end)) range,
  ];
}

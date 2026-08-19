// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';

/// The dialog reached from the project settings page's dictionary section `Edit…` button: reads,
/// filters, adds to and removes from the project's learned-word dictionary
/// (`docs/architecture/foundations.md`) — the words a writer has taught the spell checker
/// through "Add to the project's dictionary", or through this dialog's own add field.
///
/// Like `OcptEditorTitlePageDialog`, this dialog **reports rather than writes**: [show] returns the
/// words added and the words removed, and it is the project settings page — not this dialog — that
/// applies them through `OcptProjectDictionaryService`. That keeps the dialog free of any database
/// dependency of its own and matches the shape every reporting dialog in this app already has.
///
/// Every row's own `✕` turns that row into an inline `Remove?`/`Yes`/`No` question, the second
/// holder of the `OcptProjectVersionCard` standing exception to the confirm-dialog rule
/// (`AGENTS.md`): a list of rows has no other way of saying *which* row is being talked about, and
/// stacking a modal question on this already-modal dialog to un-learn ten names in a row would be a
/// punishment.
///
/// Wrapped in `PopScope(canPop: false, …)`: Escape and the system back gesture would otherwise pop
/// the route directly, discarding a `✕`-then-`Yes` removal confirmed a moment before without ever
/// running [_OcptProjectDictionaryDialogState._close]'s diff. Routing every exit through that one
/// method is what makes the round trip's promise hold regardless of *how* the dialog closes.
class OcptProjectDictionaryDialog extends StatefulWidget {
  /// The project's currently learned words, live, in whatever order the caller holds them — the
  /// dialog re-sorts its own working copy case-insensitively on construction.
  final List<String> words;

  /// Class constructor
  const OcptProjectDictionaryDialog({required this.words, super.key});

  /// Shows the dialog and returns the words it ends up reporting as added and removed against
  /// [words] — see [_OcptProjectDictionaryDialogState._close] for exactly how that diff is
  /// computed. Not `barrierDismissible`: an outside click would otherwise skip the very diff logic
  /// [_OcptProjectDictionaryDialogState._close] exists to guarantee runs on every exit.
  static Future<({List<String> added, List<String> removed})?> show(
    BuildContext context, {
    required List<String> words,
  }) => showDialog<({List<String> added, List<String> removed})>(
    context: context,
    barrierDismissible: false,
    builder: (context) => OcptProjectDictionaryDialog(words: words),
  );

  @override
  State<OcptProjectDictionaryDialog> createState() => _OcptProjectDictionaryDialogState();
}

/// The state of [OcptProjectDictionaryDialog]: the working copy of the dictionary's words, the
/// filter and add fields, and which single row (if any) is asking `Remove?`.
class _OcptProjectDictionaryDialogState extends State<OcptProjectDictionaryDialog> {
  /// The working copy of the dictionary's words, sorted case-insensitively (ties broken by the
  /// exact text) — `OcptProjectDictionaryService.loadWords`'s own ordering, so a word added here
  /// lands exactly where a reload from the service would place it.
  late List<String> _words = _sorted(widget.words);

  /// The filter field's own controller.
  final _filterController = TextEditingController();

  /// The filter field's current text, trimmed and lower-cased once per rebuild rather than once
  /// per row.
  String _filterQuery = "";

  /// The add field's own controller.
  final _addController = TextEditingController();

  /// The add field's current validation error (a duplicate word), or null. Cleared on the field's
  /// very next keystroke, exactly as a fresh attempt deserves a fresh read.
  String? _addError;

  /// The word whose row is currently asking `Remove?` in place of itself, or null while none is —
  /// a single field is enough to guarantee only one row ever asks at a time.
  String? _confirmingRemovalOf;

  @override
  void initState() {
    super.initState();
    _filterController.addListener(_onFilterChanged);
    _addController.addListener(_onAddTextChanged);
  }

  @override
  void dispose() {
    _filterController
      ..removeListener(_onFilterChanged)
      ..dispose();
    _addController
      ..removeListener(_onAddTextChanged)
      ..dispose();
    super.dispose();
  }

  /// Re-filters the list on every keystroke of the filter field.
  void _onFilterChanged() {
    setState(() => _filterQuery = _filterController.text.trim().toLowerCase());
  }

  /// Clears a standing duplicate error the moment the add field is touched again — the user is
  /// mid-correction, and the stale error would otherwise outlive the very keystroke fixing it.
  void _onAddTextChanged() {
    if (_addError != null) {
      setState(() => _addError = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tr = Tr.of(context);
    final filtered = _filterQuery.isEmpty
        ? _words
        : _words.where((word) => word.toLowerCase().contains(_filterQuery)).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _close();
      },
      child: AlertDialog(
        title: Text(tr.projectDictionaryDialogTitle),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _filterController,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search),
                  hintText: tr.projectDictionaryFilterHint,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: _buildList(tr, filtered),
              ),
              const SizedBox(height: 12),
              _buildAddField(tr),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: _close, child: Text(tr.projectDictionaryCloseAction)),
        ],
      ),
    );
  }

  /// Builds the scrollable word list, or the one of its two empty-state lines that applies: the
  /// dictionary itself holds nothing yet, or the current filter matches none of what it holds —
  /// two different facts, worth two different sentences.
  Widget _buildList(Tr tr, List<String> filtered) {
    if (_words.isEmpty) {
      return Text(tr.projectDictionaryEmptyMessage);
    }
    if (filtered.isEmpty) {
      return Text(tr.projectDictionaryNoFilterMatchMessage);
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final word = filtered[index];
        return KeyedSubtree(
          key: ValueKey(word),
          child: _confirmingRemovalOf == word
              ? _buildRemovalConfirmationRow(tr, word)
              : _buildWordRow(tr, word),
        );
      },
    );
  }

  /// Builds one ordinary row: the word, and the `✕` that turns this very row into
  /// [_buildRemovalConfirmationRow].
  Widget _buildWordRow(Tr tr, String word) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(word)),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          tooltip: tr.projectDictionaryRemoveTooltip,
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() => _confirmingRemovalOf = word),
        ),
      ],
    ),
  );

  /// Builds the in-row `Remove?` question a row's own `✕` opened — the `OcptProjectVersionCard`
  /// idiom, answered inside the row rather than by a stacked confirm dialog. `No` simply forgets
  /// which word was asking, restoring the row untouched; `Yes` drops the word from the working
  /// copy.
  Widget _buildRemovalConfirmationRow(Tr tr, String word) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tr.projectDictionaryRemoveConfirmQuestion,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _confirmingRemovalOf = null),
            child: Text(tr.projectDictionaryRemoveConfirmNoAction),
          ),
          const SizedBox(width: 4),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () => _removeWord(word),
            child: Text(tr.projectDictionaryRemoveConfirmYesAction),
          ),
        ],
      ),
    );
  }

  /// Drops [word] from the working copy and closes its own removal question.
  void _removeWord(String word) {
    setState(() {
      _words = List.of(_words)..remove(word);
      _confirmingRemovalOf = null;
    });
  }

  /// Builds the add field and its `Add` button: trims on submission, refuses a blank entry
  /// silently (nothing worth learning), and refuses a word the working copy already holds
  /// case-insensitively with [_addError] under the field.
  Widget _buildAddField(Tr tr) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: TextField(
          controller: _addController,
          decoration: InputDecoration(
            isDense: true,
            hintText: tr.projectDictionaryAddFieldHint,
            errorText: _addError,
          ),
          onSubmitted: (_) => _addWord(),
        ),
      ),
      const SizedBox(width: 8),
      FilledButton(onPressed: _addWord, child: Text(tr.projectDictionaryAddAction)),
    ],
  );

  /// Adds the add field's current text to the working copy, in its sorted place, and clears the
  /// field — or refuses it, silently for a blank entry, with [_addError] for a case-insensitive
  /// duplicate.
  void _addWord() {
    final trimmed = _addController.text.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final lowered = trimmed.toLowerCase();
    if (_words.any((word) => word.toLowerCase() == lowered)) {
      setState(() => _addError = Tr.of(context).projectDictionaryDuplicateError);
      return;
    }

    setState(() {
      _words = _sorted([..._words, trimmed]);
      _addController.clear();
      _addError = null;
    });
  }

  /// Pops the dialog through the router manager (never `Navigator` directly), reporting the diff
  /// between [OcptProjectDictionaryDialog.words] and the working copy: `removed` is every original
  /// word no longer present, spelled exactly as it was, in the working copy; `added` is every
  /// working-copy word not present, spelled exactly as it now is, in the original list.
  ///
  /// The comparison is deliberately **exact-case**, not case-insensitive: it is what makes
  /// removing `marie` and then adding `Marie` back report *both* rather than cancel out. The
  /// project settings page applies every `removed` word before every `added` one, which turns that
  /// pair into `unlearnWord("marie")` followed by `learnWord("Marie")` —
  /// `OcptProjectDictionaryService.learnWord`'s own case-insensitive revive then rewrites the
  /// tombstoned row's spelling instead of leaving a duplicate, so the net effect is a re-spelling
  /// of the same row, not a delete-then-insert.
  ///
  /// Called from every exit this dialog offers — `Close`, and the [PopScope] intercepting Escape
  /// and the system back gesture — so a `✕`-then-`Yes` removal confirmed a moment earlier is never
  /// silently discarded.
  void _close() {
    final removed = widget.words.where((word) => !_words.contains(word)).toList();
    final added = _words.where((word) => !widget.words.contains(word)).toList();

    globalGetIt().get<OcptRouterManager>().pop((added: added, removed: removed));
  }

  /// Sorts [words] case-insensitively, ties broken by the exact text —
  /// `OcptProjectDictionaryService.loadWords`'s own ordering, reproduced here so the working copy
  /// never disagrees with what a reload from the service would show.
  static List<String> _sorted(List<String> words) => [...words]..sort((a, b) {
    final byLowerCase = a.toLowerCase().compareTo(b.toLowerCase());
    return byLowerCase != 0 ? byLowerCase : a.compareTo(b);
  });
}

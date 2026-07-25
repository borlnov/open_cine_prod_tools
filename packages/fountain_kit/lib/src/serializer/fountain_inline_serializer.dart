// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/models/fountain_styled_run.dart';
import 'package:fountain_kit/src/parser/fountain_inline_parser.dart';

/// Writes a list of [FountainStyledRun]s back out as a single marked-up
/// Fountain source line.
///
/// The canonical markers are `***text***` for bold+italic, with underline
/// placed outermost when combined with bold and/or italic (`_**text**_`,
/// `_*text*_`, `_***text***_`); a single style uses its own plain marker
/// (`**`, `*` or `_`). A note run's text already carries its `[[`/`]]`
/// delimiters (see [FountainStyledRun.isNote]) and is emitted verbatim.
///
/// Adjacent runs with identical styles are merged before emission, since
/// leaving them separate could make their markers run together into a
/// different marker on re-parse (for example two adjacent bold runs would
/// emit `**a****b**`, which re-parses as two runs, `a` and `b`, rather than
/// one `ab`).
///
/// Escaping follows a verify-by-reparse policy: [write] emits a line, then
/// parses it back with [FountainInlineParser.parseRuns]; if the result does
/// not match the (merged) input runs, it escapes the offending `*`, `_` and
/// `[` characters in plain-text runs and retries until the line round-trips
/// cleanly. A lone marker character that does not pair up with anything
/// (and so already round-trips as plain text) is never escaped.
class FountainInlineSerializer {
  /// Creates a [FountainInlineSerializer].
  const FountainInlineSerializer();

  /// The marker tokens [write] recognizes, tried longest-first, matching
  /// [FountainInlineParser]'s own matching order.
  static const List<String> _markerTokens = ['***', '**', '*', '_'];

  static const FountainInlineParser _parser = FountainInlineParser();

  /// Renders [runs] as a single marked-up Fountain source line.
  String write(List<FountainStyledRun> runs) {
    final merged = _mergeAdjacent(runs);
    final texts = [
      for (final run in merged)
        _isPlain(run) ? _escapeAmbiguousMarkers(run.text) : run.text,
    ];
    while (true) {
      final line = _emit(merged, texts);
      if (_runsEqual(_parser.parseRuns(line), merged)) {
        return line;
      }
      if (!_escapeOneMore(merged, texts)) {
        // Safety net: should not be reached given the pre-pass above, but
        // guarantees termination instead of looping forever.
        return line;
      }
    }
  }

  /// Merges adjacent runs that share the same style into one, dropping
  /// empty runs (they carry no text to serialize). Note runs are never
  /// merged with each other or with anything else: each stays its own
  /// atomic `[[...]]` unit even when directly adjacent to another note.
  List<FountainStyledRun> _mergeAdjacent(List<FountainStyledRun> runs) {
    final merged = <FountainStyledRun>[];
    for (final run in runs) {
      if (run.text.isEmpty) {
        continue;
      }
      final previous = merged.isEmpty ? null : merged.last;
      if (previous != null &&
          !previous.isNote &&
          !run.isNote &&
          _sameStyle(previous, run)) {
        merged[merged.length - 1] = FountainStyledRun(
          text: previous.text + run.text,
          isBold: run.isBold,
          isItalic: run.isItalic,
          isUnderline: run.isUnderline,
        );
      } else {
        merged.add(run);
      }
    }
    return merged;
  }

  /// Whether [a] and [b] carry the same style flags.
  bool _sameStyle(FountainStyledRun a, FountainStyledRun b) =>
      a.isBold == b.isBold &&
      a.isItalic == b.isItalic &&
      a.isUnderline == b.isUnderline;

  /// Whether [run] carries no style at all (plain text, not a note).
  bool _isPlain(FountainStyledRun run) =>
      !run.isBold && !run.isItalic && !run.isUnderline && !run.isNote;

  /// Joins every run's emitted text, in order, into one line.
  String _emit(List<FountainStyledRun> runs, List<String> texts) {
    final buffer = StringBuffer();
    for (var i = 0; i < runs.length; i++) {
      buffer.write(_emitRun(runs[i], texts[i]));
    }
    return buffer.toString();
  }

  /// Wraps a single run's (possibly already escaped) [text] in its markers.
  String _emitRun(FountainStyledRun run, String text) {
    if (text.isEmpty) {
      return '';
    }
    if (run.isNote) {
      return text;
    }
    return '${_openMarker(run)}$text${_closeMarker(run)}';
  }

  /// The opening marker for [run]'s style combination, underline outermost.
  String _openMarker(FountainStyledRun run) {
    if (run.isUnderline) {
      if (run.isBold && run.isItalic) {
        return '_***';
      }
      if (run.isBold) {
        return '_**';
      }
      if (run.isItalic) {
        return '_*';
      }
      return '_';
    }
    if (run.isBold && run.isItalic) {
      return '***';
    }
    if (run.isBold) {
      return '**';
    }
    if (run.isItalic) {
      return '*';
    }
    return '';
  }

  /// The closing marker for [run]'s style combination, mirroring
  /// [_openMarker].
  String _closeMarker(FountainStyledRun run) {
    if (run.isUnderline) {
      if (run.isBold && run.isItalic) {
        return '***_';
      }
      if (run.isBold) {
        return '**_';
      }
      if (run.isItalic) {
        return '*_';
      }
      return '_';
    }
    if (run.isBold && run.isItalic) {
      return '***';
    }
    if (run.isBold) {
      return '**';
    }
    if (run.isItalic) {
      return '*';
    }
    return '';
  }

  /// Escapes marker pairs in [text] that would otherwise be misread as
  /// emphasis or a note on re-parse, using the same longest-first,
  /// nearest-closing-marker rule [FountainInlineParser.parse] uses, so this
  /// agrees with how the parser would actually pair markers up. A marker
  /// character that never finds a partner (a "lone" character, harmless as
  /// plain text) is left untouched.
  String _escapeAmbiguousMarkers(String text) {
    final buffer = StringBuffer();
    var index = 0;
    while (index < text.length) {
      if (text.startsWith('[[', index)) {
        final closeIndex = text.indexOf(']]', index + 2);
        if (closeIndex != -1) {
          buffer
            ..write(r'\[')
            ..write('[')
            ..write(
              _escapeAmbiguousMarkers(text.substring(index + 2, closeIndex)),
            )
            ..write(']]');
          index = closeIndex + 2;
          continue;
        }
      }
      final token = _matchMarkerToken(text, index);
      if (token != null) {
        final closeIndex = text.indexOf(token, index + token.length);
        if (closeIndex != -1) {
          final inner = text.substring(index + token.length, closeIndex);
          buffer
            ..write(_escapeToken(token))
            ..write(_escapeAmbiguousMarkers(inner))
            ..write(_escapeToken(token));
          index = closeIndex + token.length;
          continue;
        }
      }
      buffer.write(text[index]);
      index++;
    }
    return buffer.toString();
  }

  /// Returns the first marker token starting at [index] in [text], trying
  /// longer tokens first, or `null` if none matches.
  String? _matchMarkerToken(String text, int index) {
    for (final token in _markerTokens) {
      if (text.startsWith(token, index)) {
        return token;
      }
    }
    return null;
  }

  /// Escapes every character of [token] individually, for example `**` →
  /// `\*\*`, so re-parsing sees no unescaped marker character at all.
  String _escapeToken(String token) =>
      token.split('').map((char) => '\\$char').join();

  /// Escapes the next unescaped `*`, `_` or `[` found across [runs]' plain
  /// (non-note, non-emphasis) [texts], in document order, and returns
  /// `true`; returns `false` once no more candidates remain. This is a
  /// fallback for ambiguity across a run boundary (for example a lone `*`
  /// in a plain run immediately followed by a real bold run's marker),
  /// which [_escapeAmbiguousMarkers] cannot see since it only looks within
  /// one run's own text.
  bool _escapeOneMore(List<FountainStyledRun> runs, List<String> texts) {
    for (var i = 0; i < runs.length; i++) {
      if (!_isPlain(runs[i])) {
        continue;
      }
      final text = texts[i];
      for (var j = 0; j < text.length; j++) {
        final char = text[j];
        if (char != '*' && char != '_' && char != '[') {
          continue;
        }
        if (j > 0 && text[j - 1] == r'\') {
          continue;
        }
        texts[i] = '${text.substring(0, j)}\\$char${text.substring(j + 1)}';
        return true;
      }
    }
    return false;
  }

  /// Whether [a] and [b] contain the same runs in the same order.
  bool _runsEqual(List<FountainStyledRun> a, List<FountainStyledRun> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}

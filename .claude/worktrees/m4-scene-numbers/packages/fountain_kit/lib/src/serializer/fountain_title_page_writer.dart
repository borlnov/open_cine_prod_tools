// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/src/models/fountain_source_range.dart';
import 'package:fountain_kit/src/models/fountain_title_page.dart';

/// Splices a title page's `key: value` entries into (or out of) a Fountain
/// source string, without touching anything else in the source.
///
/// Unlike `FountainSerializer.write`, which re-normalizes an entire parsed
/// document into canonical text, this only rewrites the title-page span
/// itself: every other byte of [apply]'s `source` argument (the blank line
/// separating the title page from the body, and the body itself) is left
/// completely untouched. This is essential for a title-page editor, which
/// must never re-format a screenplay's body just because a title-page field
/// changed.
class FountainTitlePageWriter {
  /// Creates a [FountainTitlePageWriter].
  const FountainTitlePageWriter();

  /// Returns [source] with its title page replaced by [entries].
  ///
  /// [existingRange] is the parsed title page's `sourceRange` currently found
  /// in [source] (`FountainTitlePage.sourceRange`), or null if [source] has
  /// no title page.
  ///
  /// - If [existingRange] is not null and [entries] is not empty, the
  ///   existing title page is replaced in place.
  /// - If [existingRange] is not null and [entries] is empty, the title page
  ///   is dropped entirely, along with the single blank source line that used
  ///   to separate it from the body.
  /// - If [existingRange] is null and [entries] is not empty, a new title
  ///   page is prepended, followed by a blank line, ahead of [source].
  /// - If [existingRange] is null and [entries] is empty, [source] is
  ///   returned unchanged.
  String apply({
    required String source,
    required FountainSourceRange? existingRange,
    required List<FountainTitlePageEntry> entries,
  }) {
    if (existingRange == null) {
      return entries.isEmpty ? source : '${_renderBlock(entries)}\n\n$source';
    }

    if (entries.isEmpty) {
      return _dropTitlePage(source, existingRange);
    }

    return source.substring(0, existingRange.startOffset) +
        _renderBlock(entries) +
        source.substring(existingRange.endOffset);
  }

  /// Renders [entries] as one block of `key: value` lines, in the exact same
  /// format `FountainSerializer` writes a title page in (duplicated here
  /// rather than shared, since it's 5 lines of formatting logic that isn't
  /// worth coupling the serializer and this writer over).
  String _renderBlock(List<FountainTitlePageEntry> entries) => entries.map(_renderEntry).join('\n');

  /// Renders a single title page entry.
  String _renderEntry(FountainTitlePageEntry entry) {
    if (entry.values.length == 1) {
      return '${entry.key}: ${entry.values.single}';
    }
    final continuationLines = entry.values.map((value) => '    $value').join('\n');
    return '${entry.key}:\n$continuationLines';
  }

  /// Removes the title page spanned by [range] from [source], together with
  /// the single blank line that separated it from the body, so the result
  /// doesn't start with a spurious leading blank line before the first real
  /// content.
  ///
  /// The parser computes [range]'s `endOffset` as the offset right after the
  /// last character of the title page's last value line -- i.e. right before
  /// that line's own trailing newline. So, right after `endOffset`, the
  /// source always holds: that trailing newline, then the blank separator
  /// line (the parser always consumes one, even when it coincides with the
  /// very end of the source), then the body. This walks past both of those,
  /// then drops everything from [range.startOffset] up to wherever the body
  /// actually starts.
  String _dropTitlePage(String source, FountainSourceRange range) {
    var bodyStart = range.endOffset;
    if (bodyStart < source.length && source[bodyStart] == '\n') {
      bodyStart += 1;
    }

    final nextNewline = source.indexOf('\n', bodyStart);
    final separatorLineEnd = nextNewline == -1 ? source.length : nextNewline;
    if (source.substring(bodyStart, separatorLineEnd).trim().isEmpty) {
      bodyStart = nextNewline == -1 ? source.length : nextNewline + 1;
    }

    return source.substring(0, range.startOffset) + source.substring(bodyStart);
  }
}

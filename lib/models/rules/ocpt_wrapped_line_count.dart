// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// Get how many lines [text] wraps to in a box [maxColumns] characters wide, using a greedy word
/// wrap (which is what text layout does for a fixed-pitch font). An empty [text] still occupies
/// one line.
int ocptWrappedLineCount(String text, int maxColumns) {
  if (text.length <= maxColumns) {
    return 1;
  }

  var lineCount = 1;
  var currentLineLength = 0;
  for (final word in text.split(" ")) {
    // +1 for the space that precedes the word on a non-empty line.
    final neededLength = currentLineLength == 0 ? word.length : currentLineLength + 1 + word.length;
    if (neededLength <= maxColumns) {
      currentLineLength = neededLength;
    } else {
      // A word longer than the whole box hard-wraps mid-word.
      lineCount += word.length > maxColumns ? (word.length / maxColumns).ceil() : 1;
      currentLineLength = word.length % maxColumns;
    }
  }

  return lineCount;
}

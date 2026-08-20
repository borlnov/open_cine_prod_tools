// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

/// Decodes [bytes] as the text of a screenplay document.
///
/// UTF-8 with malformed sequences replaced rather than thrown on (a file
/// saved in a legacy single-byte encoding still opens, with the handful of
/// accented characters it got wrong showing as replacement characters —
/// which is what the application already does with a `.fountain` file, and
/// is far better than refusing the whole screenplay), a leading byte order
/// mark dropped, and every line ending normalized to `\n` so nothing
/// downstream ever sees a stray carriage return.
String decodeScriptText(Uint8List bytes) {
  var text = utf8.decode(bytes, allowMalformed: true);

  if (text.startsWith('﻿')) {
    text = text.substring(1);
  }

  return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}

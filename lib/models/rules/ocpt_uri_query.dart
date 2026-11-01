// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

/// The query parameters of [uri], or null when they cannot be read.
///
/// A percent-escape that is not valid UTF-8 parses as a URI but throws a [FormatException] on this
/// read, which the three places that read a scanned or pasted URI treat as an unreadable query.
Map<String, String>? ocptQueryParametersOrNull(Uri uri) {
  Map<String, String>? query;
  try {
    query = uri.queryParameters;
  } on FormatException {
    query = null;
  }

  return query;
}

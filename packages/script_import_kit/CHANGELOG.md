<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: Apache-2.0
-->

# Changelog

## 0.1.0

- Initial release: a pure Dart reader turning the screenplay files a
  production is sent into Fountain text, one way and knowingly lossy.
- Reads a Final Draft `.fdx`: every paragraph type, scene numbers, dual
  dialogue, bold/italic/underline runs, and a free-form title page sorted
  into Fountain's six fields.
- Refuses a file it cannot read as a screenplay with a typed
  `ScriptImportException` rather than a half-wrong conversion.
- Renders every reader's typed lines through `fountain_kit`'s own writers,
  so re-parsing the produced text yields the types the reader meant.

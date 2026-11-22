// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';

/// The title-page keys both editing front-ends (the styled editor's field nodes and the
/// `Title page…` dialog) know how to show and edit, in the fixed order they are written.
const List<String> ocptTitlePageStandardKeys = [
  "Title",
  "Credit",
  "Author",
  "Draft date",
  "Contact",
  "Source",
];

/// The alias a source may write instead of `Author`, read as the same field.
const String ocptTitlePageAuthorsAlias = "Authors";

/// Tell whether [key] is one of the [ocptTitlePageStandardKeys], or the
/// [ocptTitlePageAuthorsAlias] read as `Author`, whatever its case.
bool ocptIsStandardTitlePageKey(String key) {
  final lowered = key.toLowerCase();
  return lowered == ocptTitlePageAuthorsAlias.toLowerCase() ||
      ocptTitlePageStandardKeys.any((standard) => standard.toLowerCase() == lowered);
}

/// Get the entries of [titlePage] that no editing front-end knows (`Copyright`, `Notes`,
/// `Revision`…), in their source order, or an empty list when [titlePage] is null.
List<FountainTitlePageEntry> ocptNonStandardTitlePageEntries(FountainTitlePage? titlePage) {
  if (titlePage == null) {
    return const [];
  }
  return List.unmodifiable([
    for (final entry in titlePage.entries)
      if (!ocptIsStandardTitlePageKey(entry.key)) entry,
  ]);
}

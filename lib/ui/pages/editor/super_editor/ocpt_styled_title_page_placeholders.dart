// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';

/// The placeholders a styled editor shows on its empty title-page fields.
final class OcptStyledTitlePagePlaceholders {
  /// Private constructor: this class only exposes static members.
  const OcptStyledTitlePagePlaceholders._();

  /// The placeholder text shown on an empty title-page field, keyed by
  /// `ocptTitlePageFieldKeys`: the field's own label in the `⋮ ▸ Title page…` dialog
  /// (`OcptEditorTitlePageDialog`), so the two front-ends of the same title page never disagree on
  /// what to call a field.
  static Map<String, String> of(BuildContext context) {
    final tr = Tr.of(context);
    return {
      "Title": tr.editorTitlePageTitleLabel,
      "Credit": tr.editorTitlePageCreditLabel,
      "Author": tr.editorTitlePageAuthorLabel,
      "Draft date": tr.editorTitlePageDraftDateLabel,
      "Contact": tr.editorTitlePageContactLabel,
      "Source": tr.editorTitlePageSourceLabel,
    };
  }
}

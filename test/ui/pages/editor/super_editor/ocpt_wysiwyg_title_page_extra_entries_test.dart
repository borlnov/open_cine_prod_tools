// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/models/rules/ocpt_title_page_standard_keys.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/super_editor/ocpt_wysiwyg_codec.dart';
import 'package:super_editor/super_editor.dart';
import 'ocpt_wysiwyg_codec_test_doubles.dart';

/// Decode [text] with its title page, then encode the resulting document back to source.
String _roundTrip(String text, {void Function(MutableDocument document)? edit}) {
  final decoded = OcptWysiwygCodec.decodeWithTitlePage(text);
  edit?.call(decoded.document);
  return OcptWysiwygCodec.encodeWithTitlePage(decoded.document).text;
}

/// Run the tests of the title-page entries no field of the styled editor represents.
void main() {
  group('extra title page entries', () {
    test('survive a decode then encode, after the standard fields', () {
      const text = 'Title: Brick\nAuthor: Stu\nCopyright: (c) 2012\nRevision: Blue\n\nIntro.';

      expect(_roundTrip(text), text);
    });

    test('keep their position after the standard fields and their original relative order', () {
      const text = 'Notes: first\nTitle: Brick\nCopyright: (c) 2012\nAuthor: Stu\n\nIntro.';

      expect(
        _roundTrip(text),
        'Title: Brick\nAuthor: Stu\nNotes: first\nCopyright: (c) 2012\n\nIntro.',
      );
    });

    test('keep every value of a multi-line entry', () {
      const text = 'Title: Brick\nNotes:\n    one\n    two\n\nIntro.';

      final encoded = _roundTrip(text);
      final titlePage = const FountainParser().parse(encoded).titlePage!;
      expect(titlePage.entry('Notes')!.values, ['one', 'two']);
    });

    test('survive an edit of a standard field', () {
      const text = 'Title: Brick\nCopyright: (c) 2012\n\nIntro.';

      final encoded = _roundTrip(text, edit: (document) => replaceText(document, 0, 'Stone'));

      expect(encoded, 'Title: Stone\nCopyright: (c) 2012\n\nIntro.');
    });

    test('are written even when every standard field is empty', () {
      const text = 'Copyright: (c) 2012\n\nIntro.';

      expect(_roundTrip(text), text);
    });

    test('are matched on their key whatever its case, and "Authors" is not duplicated', () {
      const text = 'title: Brick\nAUTHORS: Stu\nCOPYRIGHT: (c) 2012\n\nIntro.';

      final encoded = _roundTrip(text);

      expect(encoded, 'Title: Brick\nAuthor: Stu\nCOPYRIGHT: (c) 2012\n\nIntro.');
    });

    test('are absent from the nodes of a screenplay without any', () {
      final decoded = OcptWysiwygCodec.decodeWithTitlePage('Title: Brick\n\nIntro.');

      expect(
        decoded.document.getNodeAt(0)!.getMetadataValue(ocptTitlePageExtraEntriesMetadataKey),
        isNull,
      );
    });
  });

  group('ocptNonStandardTitlePageEntries', () {
    test('tells the standard keys from the others whatever their case', () {
      expect(ocptIsStandardTitlePageKey('draft DATE'), isTrue);
      expect(ocptIsStandardTitlePageKey('authors'), isTrue);
      expect(ocptIsStandardTitlePageKey('Copyright'), isFalse);
    });

    test('is empty for no title page', () {
      expect(ocptNonStandardTitlePageEntries(null), isEmpty);
    });
  });
}

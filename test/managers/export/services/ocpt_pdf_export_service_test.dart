// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_pdf_export_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A single shared instance, reused across every test below: this also
  // exercises the font-loading cache (repeated `generate` calls within the
  // same instance must not re-read the asset bundle).
  final service = OcptPdfExportService();
  const parser = FountainParser();
  const composer = FountainScriptComposer();
  const pageSetup = OcptPageSetup.standard();

  /// A screenplay long enough to span several pages (so page-count and
  /// page-number assertions are meaningful), with a title page, an
  /// explicitly numbered scene heading, and bold/italic/underline inline
  /// styling to exercise the font-variant selection.
  final longSource = StringBuffer()
    ..writeln('Title: The Great Escape')
    ..writeln('Credit: Written by')
    ..writeln('Author: Jane Doe')
    ..writeln('Draft date: July 19, 2026')
    ..writeln('Contact: jane@example.com')
    ..writeln();
  for (var scene = 1; scene <= 40; scene++) {
    longSource
      ..writeln('INT. HOUSE #$scene#')
      ..writeln()
      ..writeln(
        'The room is quiet. It is *very* quiet, **completely** silent, and '
        '_still_ besides.',
      )
      ..writeln()
      ..writeln('JANE')
      ..writeln('Hello there, is anyone home right now, at this very moment?')
      ..writeln();
  }

  FountainDocument parse(String source) => parser.parse(source);

  group('generate', () {
    test('produces bytes starting with the %PDF magic string', () async {
      final document = parse(longSource.toString());

      final bytes = await service.generate(
        document: document,
        pageSetup: pageSetup,
        projectName: 'The Great Escape',
        includeSceneNumbers: true,
        includeTitlePage: true,
      );

      expect(bytes, isNotEmpty);
      expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
    });

    test('page count matches the composer plus a title page', () async {
      final document = parse(longSource.toString());
      final metrics = pageSetup.toMetrics();
      final layout = composer.compose(document: document, metrics: metrics);

      final bytes = await service.generate(
        document: document,
        pageSetup: pageSetup,
        projectName: 'The Great Escape',
        includeSceneNumbers: true,
        includeTitlePage: true,
      );

      expect(_pageCount(bytes), layout.pages.length + 1);
    });

    test('omitting the title page produces one fewer page', () async {
      final document = parse(longSource.toString());

      final withTitlePage = await service.generate(
        document: document,
        pageSetup: pageSetup,
        projectName: 'The Great Escape',
        includeSceneNumbers: true,
        includeTitlePage: true,
      );
      final withoutTitlePage = await service.generate(
        document: document,
        pageSetup: pageSetup,
        projectName: 'The Great Escape',
        includeSceneNumbers: true,
        includeTitlePage: false,
      );

      expect(_pageCount(withTitlePage), _pageCount(withoutTitlePage) + 1);
    });

    test(
      'a document with no title page still gets a title page when the option is on',
      () async {
        const source = 'INT. HOUSE - DAY\n\nAction line.\n';
        final document = parse(source);
        expect(document.titlePage, isNull);

        final withTitlePage = await service.generate(
          document: document,
          pageSetup: pageSetup,
          projectName: 'Fallback Project',
          includeSceneNumbers: false,
          includeTitlePage: true,
        );
        final withoutTitlePage = await service.generate(
          document: document,
          pageSetup: pageSetup,
          projectName: 'Fallback Project',
          includeSceneNumbers: false,
          includeTitlePage: false,
        );

        expect(_pageCount(withTitlePage), _pageCount(withoutTitlePage) + 1);
      },
    );

    test(
      'generating twice from the same inputs yields the same page count and valid output',
      () async {
        final document = parse(longSource.toString());

        final first = await service.generate(
          document: document,
          pageSetup: pageSetup,
          projectName: 'The Great Escape',
          includeSceneNumbers: true,
          includeTitlePage: true,
        );
        final second = await service.generate(
          document: document,
          pageSetup: pageSetup,
          projectName: 'The Great Escape',
          includeSceneNumbers: true,
          includeTitlePage: true,
        );

        // The `pdf` package embeds a creation timestamp and a random
        // document ID in its trailer, so exact byte-for-byte equality isn't
        // realistic across two calls; page count and validity are what
        // determinism actually needs to guarantee here.
        expect(ascii.decode(first.sublist(0, 4)), '%PDF');
        expect(ascii.decode(second.sublist(0, 4)), '%PDF');
        expect(_pageCount(first), _pageCount(second));
      },
    );
  });

  group('pdfFileName', () {
    test('appends the pdf extension to the project name', () {
      expect(service.pdfFileName('My Movie'), 'My Movie.pdf');
    });
  });

  group('block-level base style embeds only the font variants actually used', () {
    // `pdf` only adds a font's object to the output file if some rendered text actually asked
    // for it: a document-wide `bytes.contains('CourierPrime-Bold')` check would therefore stay
    // green even if every *specific* element's base weight were wrong (any bold inline run
    // anywhere in the document satisfies it), which is exactly the gap that let a scene heading
    // print unbold and lyrics print upright go unnoticed. Restricting each document to a single
    // element type with no inline emphasis of its own makes the assertion track that element's
    // base style, and nothing else.
    test('a scene-heading-only document embeds the bold variant', () async {
      final document = parse('INT. HOUSE - DAY\n\nUnemphasised action line.\n');

      final bytes = await service.generate(
        document: document,
        pageSetup: pageSetup,
        projectName: 'P',
        includeSceneNumbers: false,
        includeTitlePage: false,
      );

      expect(_textOf(bytes), contains('CourierPrime-Bold'));
    });

    test('a document with only plain action text embeds no bold variant', () async {
      final document = parse('Unemphasised action line, nothing else on the page.\n');

      final bytes = await service.generate(
        document: document,
        pageSetup: pageSetup,
        projectName: 'P',
        includeSceneNumbers: false,
        includeTitlePage: false,
      );

      expect(_textOf(bytes), isNot(contains('CourierPrime-Bold')));
    });

    test('a lyrics-only document embeds the italic variant', () async {
      final document = parse('~ La la la\n~ La la la\n');

      final bytes = await service.generate(
        document: document,
        pageSetup: pageSetup,
        projectName: 'P',
        includeSceneNumbers: false,
        includeTitlePage: false,
      );

      expect(_textOf(bytes), contains('CourierPrime-Italic'));
    });

    test('a document with only plain action text embeds no italic variant', () async {
      final document = parse('Unemphasised action line, nothing else on the page.\n');

      final bytes = await service.generate(
        document: document,
        pageSetup: pageSetup,
        projectName: 'P',
        includeSceneNumbers: false,
        includeTitlePage: false,
      );

      expect(_textOf(bytes), isNot(contains('CourierPrime-Italic')));
    });
  });

  group('print-time uppercasing and scene-number placement', () {
    // Both groups below compare the *content streams* of two generated documents rather than
    // reading their text (Courier Prime is embedded as an Identity-H composite font, so a
    // content stream's `Tj`/`TJ` operands are font-specific glyph indices, not readable
    // characters — matching against them would mean writing a font-aware PDF text extractor,
    // which is out of scope here). Two documents whose *composed* screenplay text is identical
    // deflate to byte-identical content streams (deflate is deterministic), while two documents
    // that print different text do not: comparing the raw stream bytes is therefore a genuine,
    // parser-free oracle for "did this render the text I expected" without ever decoding it.
    test(
      'a lower-case forced character cue and transition print exactly like '
      'already upper-cased ones',
      () async {
        final mixedCase = parse(
          'INT. HOUSE - DAY\n\n@Mr. smith\nHello there.\n\n> burn to white.\n',
        );
        final upperCase = parse(
          'INT. HOUSE - DAY\n\n@MR. SMITH\nHello there.\n\n> BURN TO WHITE.\n',
        );

        final mixedCaseBytes = await service.generate(
          document: mixedCase,
          pageSetup: pageSetup,
          projectName: 'P',
          includeSceneNumbers: false,
          includeTitlePage: false,
        );
        final upperCaseBytes = await service.generate(
          document: upperCase,
          pageSetup: pageSetup,
          projectName: 'P',
          includeSceneNumbers: false,
          includeTitlePage: false,
        );

        expect(_contentStreams(mixedCaseBytes), _contentStreams(upperCaseBytes));
      },
    );

    test(
      'an explicitly numbered scene heading prints identically to an '
      'unnumbered one when scene numbers are switched off',
      () async {
        final numbered = parse('INT. HOUSE #7#\n\nAction line.\n');
        final unnumbered = parse('INT. HOUSE\n\nAction line.\n');

        final numberedBytes = await service.generate(
          document: numbered,
          pageSetup: pageSetup,
          projectName: 'P',
          includeSceneNumbers: false,
          includeTitlePage: false,
        );
        final unnumberedBytes = await service.generate(
          document: unnumbered,
          pageSetup: pageSetup,
          projectName: 'P',
          includeSceneNumbers: false,
          includeTitlePage: false,
        );

        expect(_contentStreams(numberedBytes), _contentStreams(unnumberedBytes));
      },
    );
  });
}

/// Counts a PDF's pages by counting its `/Type /Page` object markers
/// (excluding `/Type /Pages`, the tree node), a cheap way to assert on page
/// count without pulling in a full PDF parser as a test dependency.
int _pageCount(Uint8List bytes) {
  final text = latin1.decode(bytes);
  final matches = RegExp(r'/Type\s*/Page[^s]').allMatches(text);
  return matches.length;
}

/// Decodes [bytes] as Latin-1 (a lossless byte-for-byte mapping, unlike
/// UTF-8, which is what lets [contains] search for a literal PDF name like
/// `CourierPrime-Bold` regardless of the surrounding binary stream data).
String _textOf(Uint8List bytes) => latin1.decode(bytes, allowInvalid: true);

/// The raw (still-compressed) bytes of every `stream`/`endstream` object in
/// [bytes], in file order.
///
/// This is a boundary search, not a PDF parser: it never inspects the
/// surrounding object dictionaries (so it can't tell a page's content stream
/// from a font's embedded file), which is fine for an equality comparison
/// between two documents built from the same [OcptPdfExportService.generate]
/// call shape — both sides always contain the same kind of streams in the
/// same order, so any content difference between them still shows up.
List<String> _contentStreams(Uint8List bytes) {
  final text = _textOf(bytes);
  final pattern = RegExp(r'stream\r?\n(.*?)endstream', dotAll: true);
  return [for (final match in pattern.allMatches(text)) match.group(1)!];
}

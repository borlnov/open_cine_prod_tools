// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/managers/export/services/ocpt_pdf_export_service.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

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

  group('every line stays on its own row', () {
    // A script page positions each composed line absolutely at its own row,
    // so a line the renderer considers too wide for its box does not push
    // the page down: it wraps and draws its tail on top of the next row.
    // Asserting that every drawn baseline sits on the page's own 12-point
    // row grid is therefore a direct check that no line ever wrapped twice.
    const wideAction =
        'INT. HOUSE - DAY\n\n'
        'PAUL est habille en costume, il est dans le derriere de la scene, '
        'cote cour. Il s echauffe, il parait stresse.\n';

    for (final format in OcptPageFormat.values) {
      test('on ${format.name}, no baseline falls between two rows', () async {
        final bytes = await service.generate(
          document: parse(wideAction),
          pageSetup: pageSetup.copyWith(format: format),
          projectName: 'P',
          includeSceneNumbers: true,
          includeTitlePage: false,
        );

        final baselines = _textBaselines(bytes);
        expect(baselines, isNotEmpty);
        final top = baselines.reduce((a, b) => a > b ? a : b);
        for (final baseline in baselines) {
          final rows = (top - baseline) / 12;
          expect(
            rows,
            closeTo(rows.roundToDouble(), 0.001),
            reason:
                'a baseline $rows rows below the first one is off the row '
                'grid, i.e. drawn on top of a neighbouring line',
          );
        }
      });
    }
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

  group('inline-only emphasis embeds the matching font variant', () {
    // The group above proves each element's *base* style renders correctly, but every one of
    // its documents carries no inline emphasis of its own, so it can't tell whether an inline
    // `**bold**`/`*italic*`/`_underline_` run reaches the PDF at all: a document-wide
    // `contains('CourierPrime-Bold')` is satisfied by any bold anywhere, including a scene
    // heading's base weight, which is exactly the gap this closes. Every document here is a
    // single plain action line (regular base style) with one inline emphasis run, so a positive
    // match can only come from that run.
    test('a plain action line with an inline bold run embeds the bold variant', () async {
      final document = parse('Plain action with **bold** word only.\n');

      final bytes = await service.generate(
        document: document,
        pageSetup: pageSetup,
        projectName: 'P',
        includeSceneNumbers: false,
        includeTitlePage: false,
      );

      expect(_textOf(bytes), contains('CourierPrime-Bold'));
    });

    test('a plain action line with an inline italic run embeds the italic variant', () async {
      final document = parse('Plain action with *italic* word only.\n');

      final bytes = await service.generate(
        document: document,
        pageSetup: pageSetup,
        projectName: 'P',
        includeSceneNumbers: false,
        includeTitlePage: false,
      );

      expect(_textOf(bytes), contains('CourierPrime-Italic'));
    });

    test(
      'a plain action line with an inline bold-italic run embeds the bold-italic variant',
      () async {
        final document = parse('Plain action with ***both*** word only.\n');

        final bytes = await service.generate(
          document: document,
          pageSetup: pageSetup,
          projectName: 'P',
          includeSceneNumbers: false,
          includeTitlePage: false,
        );

        expect(_textOf(bytes), contains('CourierPrime-BoldItalic'));
      },
    );

    test(
      'a plain action line with an inline underline run prints differently from the '
      'same text unemphasised',
      () async {
        // Underline has no font variant of its own (it's a drawn stroke, not a font choice), so
        // the oracle here is the same content-stream comparison the uppercasing group above uses.
        // Both documents are underlined/plain for the *whole* line (one run each) rather than
        // just one word, so the two content streams differ only by the underline's stroke
        // operators, never by an incidental difference in how many runs the line split into.
        final underlined = parse('_Plain action with underline word only._\n');
        final plain = parse('Plain action with underline word only.\n');

        final underlinedBytes = await service.generate(
          document: underlined,
          pageSetup: pageSetup,
          projectName: 'P',
          includeSceneNumbers: false,
          includeTitlePage: false,
        );
        final plainBytes = await service.generate(
          document: plain,
          pageSetup: pageSetup,
          projectName: 'P',
          includeSceneNumbers: false,
          includeTitlePage: false,
        );

        expect(_contentStreams(underlinedBytes), isNot(_contentStreams(plainBytes)));
      },
    );
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

/// The absolute Y coordinate, in points from the page's bottom edge, of
/// every piece of text [bytes] draws.
///
/// Walks each page's content stream with just enough of a PDF graphics-state
/// interpreter to resolve a `Td` text position against the enclosing
/// `q`/`cm`/`Q` translations (the `pdf` package emits one translated group
/// per positioned widget, and only ever translations — never a rotation or a
/// scale — which is what makes summing the `cm` offsets sufficient here).
/// The drawn glyphs themselves are deliberately not decoded: only *where*
/// each run landed matters.
List<double> _textBaselines(Uint8List bytes) {
  final zlib = ZLibCodec();
  final baselines = <double>[];
  for (final stream in _contentStreams(bytes)) {
    final String content;
    try {
      content = latin1.decode(zlib.decode(latin1.encode(stream)));
    } on FormatException {
      // Not a deflated stream at all.
      continue;
    }

    // A page's content stream is pure printable ASCII (operators plus
    // hex-encoded glyph indices), while the other deflated streams of the
    // document are the embedded font files: skipping anything holding a
    // control byte keeps this walk on the pages alone, without needing to
    // parse the object dictionaries [_contentStreams] deliberately ignores.
    if (content.codeUnits.any((unit) => unit < 0x20 && unit != 0x0a)) {
      continue;
    }

    final stack = <double>[];
    var offsetY = 0.0;
    for (final token in _graphicsTokens.allMatches(content)) {
      switch (token.group(0)![0]) {
        case 'q':
          stack.add(offsetY);
        case 'Q':
          offsetY = stack.removeLast();
        default:
          final translation = double.tryParse(token.group(2) ?? '');
          if (translation == null) {
            baselines.add(offsetY + double.parse(token.group(4)!));
          } else {
            offsetY += translation;
          }
      }
    }
  }
  return baselines;
}

/// Matches the content-stream operators [_textBaselines] cares about: `q`,
/// `Q`, a `cm` translation matrix (whose Y offset is group 2) and a `Td` text
/// position (whose Y offset is group 4).
final RegExp _graphicsTokens = RegExp(
  r'\bq\b|\bQ\b|1 0 0 1 (-?[\d.]+) (-?[\d.]+) cm|(-?[\d.]+) (-?[\d.]+) Td',
);

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

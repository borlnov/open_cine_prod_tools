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
}

/// Counts a PDF's pages by counting its `/Type /Page` object markers
/// (excluding `/Type /Pages`, the tree node), a cheap way to assert on page
/// count without pulling in a full PDF parser as a test dependency.
int _pageCount(Uint8List bytes) {
  final text = latin1.decode(bytes);
  final matches = RegExp(r'/Type\s*/Page[^s]').allMatches(text);
  return matches.length;
}

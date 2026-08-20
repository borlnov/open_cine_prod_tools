// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:script_import_kit/src/emitter/script_fountain_emitter.dart';
import 'package:script_import_kit/src/emitter/script_line.dart';
import 'package:script_import_kit/src/emitter/script_title_page.dart';
import 'package:script_import_kit/src/models/script_import_exception.dart';
import 'package:script_import_kit/src/script_styled_runs.dart';
import 'package:script_import_kit/src/script_text_decoder.dart';
import 'package:xml/xml.dart';

/// Reads a Final Draft screenplay (`.fdx`) and converts it to Fountain.
///
/// An `.fdx` is a single XML document: a `<FinalDraft>` root whose
/// `<Content>` holds one `<Paragraph Type="…">` per line of screenplay,
/// each carrying one or more `<Text>` runs. The conversion is a
/// paragraph-type-to-[FountainLineType] mapping and nothing more — every
/// question of Fountain syntax is [ScriptFountainEmitter]'s.
///
/// What it deliberately does not carry over, none of which has a printed
/// equivalent in Fountain:
///
/// - `<ScriptNote>`, Final Draft's margin notes, are dropped rather than
///   turned into Fountain notes: they are an authoring side-channel, and a
///   `[[…]]` in the middle of the imported screenplay would read as content
///   the writer never put there;
/// - revision marks, locked pages, the element's own formatting overrides
///   and every `<Text>` style other than bold, italic and underline
///   (Final Draft's `AllCaps`, `Strikeout`…);
/// - anything outside `<Content>` and `<TitlePage>`: the cast list report,
///   the smart-type lists, the paper size.
class FdxScriptReader {
  /// Creates a [FdxScriptReader].
  const FdxScriptReader({this.emitter = const ScriptFountainEmitter()});

  /// Matches the credit line of a title page (`Written by`, `Screenplay
  /// by`, `Scénario de`), whose next line names the author.
  static final RegExp _creditLine = RegExp(
    r'^(written\s+by|screenplay\s+by|scénario\s+de)\b',
    caseSensitive: false,
  );

  /// Matches the line of a title page naming the work the screenplay was
  /// adapted from.
  static final RegExp _sourceLine = RegExp(
    r"^(based\s+on|d['’]après)",
    caseSensitive: false,
  );

  /// Matches the line of a title page naming which draft this is.
  static final RegExp _draftLine = RegExp(
    r'\b(draft|version)\b',
    caseSensitive: false,
  );

  /// Renders the lines this reader makes out of a document.
  final ScriptFountainEmitter emitter;

  /// Reads the Final Draft document held in [bytes] and returns its
  /// screenplay as Fountain source text.
  ///
  /// Throws a [ScriptImportException] when [bytes] hold no readable Final
  /// Draft screenplay: XML that does not parse or a root that is not
  /// `<FinalDraft>` ([ScriptImportFailure.malformedFile]), a document
  /// declaring itself to be something other than a script
  /// ([ScriptImportFailure.unsupportedFormat]), or a script with no line of
  /// screenplay in it ([ScriptImportFailure.emptyScript]).
  String read(Uint8List bytes) {
    final root = _parseRoot(decodeScriptText(bytes));

    final documentType = root.getAttribute('DocumentType')?.trim();
    if (documentType != null &&
        documentType.isNotEmpty &&
        documentType != 'Script') {
      throw ScriptImportException(
        ScriptImportFailure.unsupportedFormat,
        details: 'Final Draft DocumentType "$documentType" is not a script',
      );
    }

    final content = root.childElements.firstWhereOrNull(
      (element) => element.name.local == 'Content',
    );
    if (content == null) {
      throw const ScriptImportException(
        ScriptImportFailure.malformedFile,
        details: 'the FinalDraft element holds no Content element',
      );
    }

    final lines = _readBody(content);
    if (lines.isEmpty) {
      throw const ScriptImportException(ScriptImportFailure.emptyScript);
    }

    return emitter.write(lines: lines, titlePage: _readTitlePage(root));
  }

  /// Parses [xmlText] and returns its `<FinalDraft>` root element.
  XmlElement _parseRoot(String xmlText) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(xmlText);
    } on XmlException catch (exception) {
      throw ScriptImportException(
        ScriptImportFailure.malformedFile,
        details: 'the document is not well-formed XML: $exception',
      );
    }

    final root = document.rootElement;
    if (root.name.local != 'FinalDraft') {
      throw ScriptImportException(
        ScriptImportFailure.malformedFile,
        details: 'the root element is <${root.name.local}>, not <FinalDraft>',
      );
    }
    return root;
  }

  /// Reads every line of screenplay out of the document's `<Content>`.
  ///
  /// Anything that is not a `<Paragraph>` is skipped, which is what leaves
  /// a `<ScriptNote>` of its own behind; a `<Paragraph>` wrapping a
  /// `<DualDialogue>` is read as the pair of dialogue blocks it holds
  /// rather than as a line.
  List<ScriptLine> _readBody(XmlElement content) {
    final lines = <ScriptLine>[];
    for (final element in content.childElements) {
      switch (element.name.local) {
        case 'Paragraph':
          final dualDialogue = element.childElements.firstWhereOrNull(
            (child) => child.name.local == 'DualDialogue',
          );
          if (dualDialogue != null) {
            lines.addAll(_readDualDialogue(dualDialogue));
            continue;
          }
          final line = _readParagraph(element);
          if (line != null) {
            lines.add(line);
          }
        case 'DualDialogue':
          lines.addAll(_readDualDialogue(element));
        default:
          // Every other child (`<ScriptNote>`, `<Revision>`, whatever a
          // later Final Draft version adds) carries nothing that prints.
          continue;
      }
    }
    return lines;
  }

  /// Reads the two dialogue blocks a `<DualDialogue>` holds, marking the
  /// second character cue as the one spoken simultaneously with the first.
  List<ScriptLine> _readDualDialogue(XmlElement group) {
    final lines = <ScriptLine>[];
    var cueCount = 0;
    for (final paragraph in group.findAllElements('Paragraph')) {
      final isCue =
          _lineTypeOf(paragraph.getAttribute('Type')) ==
          FountainLineType.character;
      if (isCue) {
        cueCount++;
      }
      final line = _readParagraph(
        paragraph,
        isDualDialogue: isCue && cueCount == 2,
      );
      if (line != null) {
        lines.add(line);
      }
    }
    return lines;
  }

  /// Reads one `<Paragraph>` as a line of screenplay, or `null` when it
  /// carries no text at all (Final Draft's own way of writing a spacer).
  ScriptLine? _readParagraph(
    XmlElement paragraph, {
    bool isDualDialogue = false,
  }) {
    final runs = _runsOf(paragraph);
    if (runs.isEmpty) {
      return null;
    }

    return ScriptLine(
      type: _lineTypeOf(paragraph.getAttribute('Type')),
      runs: runs,
      sceneNumber: paragraph.getAttribute('Number')?.trim(),
      isDualDialogue: isDualDialogue,
    );
  }

  /// The [FountainLineType] a `<Paragraph>`'s `Type` attribute maps to.
  FountainLineType _lineTypeOf(String? paragraphType) =>
      switch (paragraphType?.trim()) {
        'Scene Heading' => FountainLineType.sceneHeading,
        'Character' => FountainLineType.character,
        'Parenthetical' => FountainLineType.parenthetical,
        'Dialogue' => FountainLineType.dialogue,
        'Transition' => FountainLineType.transition,
        // An act break prints centered on its own line, which is the one
        // thing Fountain has to say about it.
        'New Act' || 'End of Act' => FountainLineType.centeredText,
        // `Action`, `General`, `Shot`, `Cast List`, and every type a later
        // Final Draft version invents, all print as ordinary prose. Falling
        // back to action rather than refusing the file is deliberate: an
        // unknown element costs its own styling, never its text.
        _ => FountainLineType.action,
      };

  /// The styled runs of a `<Paragraph>`, one per direct `<Text>` child.
  ///
  /// Only direct children are read, which is what keeps the text of a
  /// `<ScriptNote>` nested inside the paragraph out of the line.
  List<FountainStyledRun> _runsOf(XmlElement paragraph) {
    final runs = <FountainStyledRun>[];
    for (final text in paragraph.childElements) {
      if (text.name.local != 'Text') {
        continue;
      }

      // A `<Text>` run holds one line's worth of text; a newline inside it
      // is the source's own wrapping, and a Fountain line cannot carry one.
      final value = text.innerText.replaceAll('\n', ' ');
      if (value.isEmpty) {
        continue;
      }

      final styles = _stylesOf(text.getAttribute('Style'));
      runs.add(
        FountainStyledRun(
          text: value,
          isBold: styles.contains('bold'),
          isItalic: styles.contains('italic'),
          isUnderline: styles.contains('underline'),
        ),
      );
    }
    return trimStyledRunEdges(runs);
  }

  /// The lower-cased style names a `<Text>`'s `Style` attribute lists
  /// (`"Bold+Italic"`), or an empty set when it declares none.
  Set<String> _stylesOf(String? style) => {
    if (style != null)
      for (final name in style.split('+'))
        if (name.trim().isNotEmpty) name.trim().toLowerCase(),
  };

  /// Reads the document's `<TitlePage>` into the six fields Fountain writes.
  ScriptTitlePage _readTitlePage(XmlElement root) {
    final titlePage = root.childElements.firstWhereOrNull(
      (element) => element.name.local == 'TitlePage',
    );
    if (titlePage == null) {
      return const ScriptTitlePage();
    }

    final lines = <String>[];
    for (final paragraph in titlePage.findAllElements('Paragraph')) {
      final text = _plainTextOf(paragraph);
      if (text.isNotEmpty) {
        lines.add(text);
      }
    }
    return _titlePageFrom(lines);
  }

  /// The whole text of a `<Paragraph>`, trimmed, with no styling.
  String _plainTextOf(XmlElement paragraph) =>
      _runsOf(paragraph).map((run) => run.text).join().trim();

  /// Sorts a title page's free-form [lines] into the six fields.
  ///
  /// Final Draft's title page is a page of prose, not a set of named
  /// fields: it has to be read the way a person reads it. The title comes
  /// first, a credit line is followed by its author, "based on" names the
  /// source, a line saying "draft" or "version" names the draft — and
  /// whatever is left is the contact block, so that not one line of the
  /// original is dropped on the floor.
  ScriptTitlePage _titlePageFrom(List<String> lines) {
    final remaining = List.of(lines);

    final title = remaining.isEmpty ? null : remaining.removeAt(0);

    String? credit;
    String? author;
    final creditIndex = remaining.indexWhere(_creditLine.hasMatch);
    if (creditIndex != -1) {
      credit = remaining.removeAt(creditIndex);
      if (creditIndex < remaining.length) {
        author = remaining.removeAt(creditIndex);
      }
    }

    String? source;
    final sourceIndex = remaining.indexWhere(_sourceLine.hasMatch);
    if (sourceIndex != -1) {
      source = remaining.removeAt(sourceIndex);
    }

    String? draftDate;
    final draftIndex = remaining.indexWhere(_draftLine.hasMatch);
    if (draftIndex != -1) {
      draftDate = remaining.removeAt(draftIndex);
    }

    return ScriptTitlePage(
      title: title,
      credit: credit,
      author: author,
      draftDate: draftDate,
      contact: remaining,
      source: source,
    );
  }
}

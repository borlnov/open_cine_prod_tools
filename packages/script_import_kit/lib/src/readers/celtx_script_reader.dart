// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:script_import_kit/src/emitter/script_fountain_emitter.dart';
import 'package:script_import_kit/src/emitter/script_line.dart';
import 'package:script_import_kit/src/emitter/script_title_page.dart';
import 'package:script_import_kit/src/models/script_import_exception.dart';
import 'package:script_import_kit/src/script_styled_runs.dart';
import 'package:script_import_kit/src/script_text_decoder.dart';
import 'package:xml/xml.dart';

/// The inline emphasis in force at one point of a Celtx script document.
///
/// Celtx's HTML nests its emphasis the way any HTML does, so the styles a
/// run carries are the ones every element above it opened: this is what is
/// carried down the walk of a paragraph's nodes.
class _InlineStyle {
  /// Creates an [_InlineStyle].
  const _InlineStyle({
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
  });

  /// Whether the text is bold.
  final bool isBold;

  /// Whether the text is italic.
  final bool isItalic;

  /// Whether the text is underlined.
  final bool isUnderline;

  /// This style with whatever the HTML element named [tagName] adds to it.
  ///
  /// An element Fountain has no marker for (a `<span>`, a `<font>`, a
  /// `<a>`) adds nothing and keeps the style as it is, so its text still
  /// comes through — only its styling is lost.
  _InlineStyle insideTag(String tagName) => switch (tagName) {
    'b' || 'strong' => _copyWith(isBold: true),
    'i' || 'em' => _copyWith(isItalic: true),
    'u' => _copyWith(isUnderline: true),
    _ => this,
  };

  /// This style with the flags given here turned on.
  _InlineStyle _copyWith({
    bool isBold = false,
    bool isItalic = false,
    bool isUnderline = false,
  }) => _InlineStyle(
    isBold: this.isBold || isBold,
    isItalic: this.isItalic || isItalic,
    isUnderline: this.isUnderline || isUnderline,
  );

  /// A run of [text] carrying this style.
  FountainStyledRun run(String text) => FountainStyledRun(
    text: text,
    isBold: isBold,
    isItalic: isItalic,
    isUnderline: isUnderline,
  );
}

/// What a Celtx project's manifest says about the screenplay it holds.
class _CeltxManifest {
  /// Creates a [_CeltxManifest].
  const _CeltxManifest({required this.scriptFileName, required this.titlePage});

  /// The name, inside the container, of the script document to read.
  final String scriptFileName;

  /// The title page the manifest's own metadata makes.
  final ScriptTitlePage titlePage;
}

/// Reads a legacy Celtx project (`.celtx`) and converts its screenplay to
/// Fountain.
///
/// A `.celtx` is a zip holding a `project.rdf` manifest and one HTML file
/// per document of the project. This reader opens the container in memory
/// (a `.celtx` is a screenplay's worth of text, not a package of media),
/// asks the manifest which document is the script, and reads that one:
/// every `<p class="…">` of its HTML becomes a line of screenplay, the
/// class naming what the line is. Every question of Fountain syntax is
/// [ScriptFountainEmitter]'s, exactly as it is for a Final Draft file.
///
/// What it deliberately does not carry over:
///
/// - **every document but the first script**: the catalogue, the
///   storyboard, the scratch files, the schedule and any further script
///   document of the same project. One import brings in one screenplay,
///   which is what the receiving application stores;
/// - the project's own media, its index cards and its notes, none of which
///   has a printed equivalent in a screenplay;
/// - every text style Fountain has no marker for — only bold, italic and
///   underline survive.
class CeltxScriptReader {
  /// Creates a [CeltxScriptReader].
  const CeltxScriptReader({this.emitter = const ScriptFountainEmitter()});

  /// The manifest entry naming the project's documents and its metadata.
  static const String _manifestFileName = 'project.rdf';

  /// What a `<p>`'s class says the line is.
  ///
  /// A class this map does not list — and a `<p>` carrying no class at all
  /// — falls back to action: an unrecognised element costs its own styling,
  /// never its text.
  static const Map<String, FountainLineType> _lineTypesByClass = {
    'sceneheading': FountainLineType.sceneHeading,
    'action': FountainLineType.action,
    'character': FountainLineType.character,
    'dialog': FountainLineType.dialogue,
    'parenthetical': FountainLineType.parenthetical,
    'transition': FountainLineType.transition,
    // A shot prints as prose: Fountain has no element of its own for it.
    'shot': FountainLineType.action,
    // An act break prints centered on its own line, which is the one thing
    // Fountain has to say about it.
    'act': FountainLineType.centeredText,
    'actbreak': FountainLineType.centeredText,
    'text': FountainLineType.action,
  };

  /// Matches a run of whitespace, which HTML renders as a single space
  /// however the file was laid out.
  static final RegExp _whitespaceRun = RegExp(r'\s+');

  /// Matches the separator between two segments of a container entry's
  /// path, whichever platform wrote the container.
  static final RegExp _pathSeparator = RegExp(r'[/\\]');

  /// Matches the separator between the segments of an RDF type URI, whose
  /// last one is what names the type.
  static final RegExp _uriSeparator = RegExp('[/#]');

  /// Renders the lines this reader makes out of a document.
  final ScriptFountainEmitter emitter;

  /// Reads the Celtx project held in [bytes] and returns the screenplay of
  /// its first script document as Fountain source text.
  ///
  /// Throws a [ScriptImportException] when [bytes] hold no readable
  /// screenplay: a container that does not open
  /// ([ScriptImportFailure.malformedFile]), a project whose manifest is
  /// missing, unreadable or names no script document, or a script document
  /// the container does not hold
  /// ([ScriptImportFailure.noScriptDocument]), or a script document with no
  /// line of screenplay in it ([ScriptImportFailure.emptyScript]).
  String read(Uint8List bytes) {
    final archive = _openContainer(bytes);
    final manifest = _readManifest(archive);

    final script = _findEntry(archive, manifest.scriptFileName);
    if (script == null) {
      throw ScriptImportException(
        ScriptImportFailure.noScriptDocument,
        details:
            'the container holds no "${manifest.scriptFileName}" the manifest '
            'names as its script document',
      );
    }

    final lines = _readBody(
      decodeScriptText(script.readBytes() ?? Uint8List(0)),
    );
    if (lines.isEmpty) {
      throw const ScriptImportException(ScriptImportFailure.emptyScript);
    }

    return emitter.write(lines: lines, titlePage: manifest.titlePage);
  }

  /// Opens [bytes] as the zip container a `.celtx` is.
  ///
  /// A container that opens on nothing is treated as a file that did not
  /// open at all: the decoder looks for the entry directory at the end of
  /// the bytes and hands back an empty archive when it finds none, which is
  /// what any file that is not a zip — a PDF renamed `.celtx`, a Celtx 2
  /// project — produces.
  Archive _openContainer(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (error) {
      // A truncated container fails somewhere inside the decoder rather
      // than at one known place, so every way it can give up is caught
      // here: what matters to the caller is that the file did not open.
      throw ScriptImportException(
        ScriptImportFailure.malformedFile,
        details: 'the file did not open as a zip container: $error',
      );
    }

    if (archive.isEmpty) {
      throw const ScriptImportException(
        ScriptImportFailure.malformedFile,
        details: 'the file holds no zip container',
      );
    }
    return archive;
  }

  /// Reads the project's `project.rdf` manifest.
  ///
  /// A manifest that is missing, that does not parse, or that names no
  /// script document all mean the same thing to the caller — there is no
  /// screenplay in this file to read — so all three raise
  /// [ScriptImportFailure.noScriptDocument].
  _CeltxManifest _readManifest(Archive archive) {
    final entry = _findEntry(archive, _manifestFileName);
    if (entry == null) {
      throw const ScriptImportException(
        ScriptImportFailure.noScriptDocument,
        details: 'the container holds no project.rdf manifest',
      );
    }

    final XmlDocument manifest;
    try {
      manifest = XmlDocument.parse(
        decodeScriptText(entry.readBytes() ?? Uint8List(0)),
      );
    } on XmlException catch (exception) {
      throw ScriptImportException(
        ScriptImportFailure.noScriptDocument,
        details: 'the project.rdf manifest is not well-formed XML: $exception',
      );
    }

    final elements = manifest.descendantElements.toList();

    final script = elements.firstWhereOrNull(
      (element) =>
          _isScriptDocument(element) && _valueOf(element, 'localfile') != null,
    );
    if (script == null) {
      throw const ScriptImportException(
        ScriptImportFailure.noScriptDocument,
        details: 'the project.rdf manifest names no script document',
      );
    }

    final project = elements.firstWhereOrNull(_isProject);
    return _CeltxManifest(
      // Checked just above: this is the very value the element was picked
      // for.
      scriptFileName: _valueOf(script, 'localfile')!,
      titlePage: ScriptTitlePage(
        title: project == null ? null : _valueOf(project, 'title'),
        author: project == null ? null : _valueOf(project, 'creator'),
      ),
    );
  }

  /// Whether [element] describes the project itself, whose metadata makes
  /// the title page.
  bool _isProject(XmlElement element) =>
      _localNamesOf(element).contains('project');

  /// Whether [element] describes a document this reader can read as a
  /// screenplay.
  ///
  /// RDF says the same thing in more than one shape — a `<cx:Document>`
  /// with a type attribute, an `<RDF:Description>` whose type is a URI
  /// ending in `ScriptDocument`, an element named after the type itself —
  /// so what is looked at is the set of names the element goes by, and a
  /// document is a script when one of them says so. An `AVScriptDocument`
  /// matches too: it is read like any other, and it is its own two-column
  /// content that then decides whether there is a screenplay in it.
  bool _isScriptDocument(XmlElement element) =>
      _localNamesOf(element).any((name) => name.contains('script'));

  /// The names [element] goes by, lower-cased: its own element name, and
  /// whatever its type says it is.
  Set<String> _localNamesOf(XmlElement element) {
    final declaredType =
        _valueOf(element, 'type') ?? _valueOf(element, 'documenttype');
    return {
      element.name.local.toLowerCase(),
      if (declaredType != null) _localPartOf(declaredType).toLowerCase(),
    };
  }

  /// The last segment of [value], which is what names the thing when an RDF
  /// type is written as a full URI (`http://celtx.com/NS/v1/Script`).
  String _localPartOf(String value) {
    final segments = value.split(_uriSeparator);
    return segments.lastWhere(
      (segment) => segment.isNotEmpty,
      orElse: () => '',
    );
  }

  /// What [element] says [localName] is, read from an attribute of that
  /// name or, failing that, from a child element of that name — RDF writes
  /// a property either way, and a manifest is free to mix the two.
  ///
  /// [localName] is matched case-insensitively and without its namespace
  /// prefix, so `cx:localFile`, `cx:localfile` and `localFile` all answer
  /// to the same question. Returns `null` when the property is absent or
  /// carries nothing but whitespace.
  String? _valueOf(XmlElement element, String localName) {
    final attribute = element.attributes.firstWhereOrNull(
      (attribute) => _sameName(attribute.name.local, localName),
    );
    final fromAttribute = attribute?.value.trim();
    if (fromAttribute != null && fromAttribute.isNotEmpty) {
      return fromAttribute;
    }

    final child = element.childElements.firstWhereOrNull(
      (child) => _sameName(child.name.local, localName),
    );
    final fromChild = child?.innerText.trim();
    return fromChild == null || fromChild.isEmpty ? null : fromChild;
  }

  /// Whether two XML local names name the same property.
  bool _sameName(String name, String other) =>
      name.toLowerCase() == other.toLowerCase();

  /// The container entry named [fileName], or `null` when it holds none.
  ///
  /// The name is matched without regard to case or to the separator the
  /// writing platform used; an entry sitting in a folder of its own answers
  /// to its bare file name too, so a container that wraps its project in a
  /// directory still opens.
  ArchiveFile? _findEntry(Archive archive, String fileName) {
    final wanted = _entryPathOf(fileName);
    final baseName = wanted.split('/').last;

    return archive.firstWhereOrNull(
          (entry) => entry.isFile && _entryPathOf(entry.name) == wanted,
        ) ??
        archive.firstWhereOrNull(
          (entry) =>
              entry.isFile &&
              _entryPathOf(entry.name).split('/').last == baseName,
        );
  }

  /// [name] as a comparable container path: lower-cased, `/`-separated, and
  /// without the `./` a writer may have prefixed it with.
  String _entryPathOf(String name) => name
      .toLowerCase()
      .split(_pathSeparator)
      .where((segment) => segment.isNotEmpty && segment != '.')
      .join('/');

  /// Reads every line of screenplay out of a script document's [html].
  ///
  /// Parsed as HTML rather than as XML on purpose: a Celtx script document
  /// is HTML 4.01 as a browser engine wrote it — unclosed `<br>`, named
  /// entities, attributes without quotes — none of which is well-formed
  /// XML.
  List<ScriptLine> _readBody(String html) => [
    for (final paragraph in html_parser.parse(html).querySelectorAll('p'))
      ..._readParagraph(paragraph),
  ];

  /// Reads one `<p>` as the lines of screenplay it holds.
  ///
  /// Several lines, and not one, because a `<br>` inside the paragraph is
  /// how Celtx writes a line break *inside* one block: the lines it yields
  /// are one block, which is what [ScriptLine.continuesBlock] says. A
  /// paragraph with nothing but whitespace in it yields none.
  List<ScriptLine> _readParagraph(dom.Element paragraph) {
    final segments = <List<FountainStyledRun>>[[]];
    _collectRuns(paragraph.nodes, const _InlineStyle(), segments);

    final type = _lineTypeOf(paragraph);
    final sceneNumber = paragraph.attributes['scenenumber']?.trim();

    final lines = <ScriptLine>[];
    for (final segment in segments) {
      final runs = trimStyledRunEdges(segment);
      if (runs.isEmpty) {
        continue;
      }

      lines.add(
        ScriptLine(
          type: type,
          runs: runs,
          // A scene number belongs to the heading itself, so only the line
          // that opens the block carries it.
          sceneNumber: lines.isEmpty ? sceneNumber : null,
          continuesBlock: lines.isNotEmpty,
        ),
      );
    }
    return lines;
  }

  /// Walks [nodes] under [style], appending the runs they hold to the last
  /// of [segments] and opening a new segment on every `<br>`.
  void _collectRuns(
    List<dom.Node> nodes,
    _InlineStyle style,
    List<List<FountainStyledRun>> segments,
  ) {
    for (final node in nodes) {
      if (node is dom.Text) {
        final text = _normalizedText(node.text);
        if (text.isNotEmpty) {
          segments.last.add(style.run(text));
        }
        continue;
      }

      if (node is! dom.Element) {
        // A comment, a doctype: nothing that prints.
        continue;
      }

      if (node.localName == 'br') {
        segments.add([]);
        continue;
      }

      _collectRuns(node.nodes, style.insideTag(node.localName ?? ''), segments);
    }
  }

  /// [text] as it would read on screen: every non-breaking space back to an
  /// ordinary one, and every run of whitespace — the newlines and the
  /// indentation the HTML was laid out with — collapsed to a single space,
  /// which is what an HTML renderer does with it.
  String _normalizedText(String text) =>
      text.replaceAll('\u00A0', ' ').replaceAll(_whitespaceRun, ' ');

  /// What a `<p>`'s class says its line is.
  FountainLineType _lineTypeOf(dom.Element paragraph) {
    for (final className in paragraph.classes) {
      final type = _lineTypesByClass[className.toLowerCase()];
      if (type != null) {
        return type;
      }
    }
    return FountainLineType.action;
  }
}

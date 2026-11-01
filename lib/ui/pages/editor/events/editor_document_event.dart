// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/ui/pages/editor/events/editor_base_event.dart';

/// The events about the text, its parsing, its saving, the caret and the title page.
sealed class OcptEditorDocumentEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorDocumentEvent();
}

/// Report that the source text was edited by the user.
///
/// This marks the screenplay dirty and (re)starts the parse and autosave debounce timers.
class OcptEditorTextChangedEvent extends OcptEditorDocumentEvent {
  /// The full source text as it now stands in the editor.
  final String text;

  /// Class constructor
  const OcptEditorTextChangedEvent({required this.text});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, text];
}

/// Request a re-parse of the current source text into a fresh `FountainDocument`.
///
/// This is dispatched by the bloc's own parse debounce timer; it isn't meant to be sent by
/// widgets.
class OcptEditorParseRequestedEvent extends OcptEditorDocumentEvent {
  /// Class constructor
  const OcptEditorParseRequestedEvent();
}

/// Request saving the current source text to the project database.
///
/// [isManual] tells whether the save was explicitly requested by the user (toolbar button or
/// Ctrl+S) rather than triggered by the autosave debounce timer: it decides the snapshot reason
/// the save is tagged with.
class OcptEditorSaveRequestedEvent extends OcptEditorDocumentEvent {
  /// Whether the save was explicitly requested by the user.
  final bool isManual;

  /// Class constructor
  const OcptEditorSaveRequestedEvent({required this.isManual});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, isManual];
}

/// Report that the editor caret moved to another source line.
///
/// The current line drives the preview scroll synchronization and the scene panel highlight.
class OcptEditorCaretMovedEvent extends OcptEditorDocumentEvent {
  /// The 0-based source line the caret is now on.
  final int line;

  /// Class constructor
  const OcptEditorCaretMovedEvent({required this.line});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, line];
}

/// Request moving the editor caret to the character offset a scene starts at.
///
/// This is sent when the user clicks a scene in the scene panel; the page applies the resulting
/// `OcptEditorJumpRequest` to its text controller.
class OcptEditorSceneJumpRequestedEvent extends OcptEditorDocumentEvent {
  /// The character offset, in the source text, at which the target scene starts.
  final int charOffset;

  /// Class constructor
  const OcptEditorSceneJumpRequestedEvent({required this.charOffset});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, charOffset];
}

/// Report that the project settings page was closed after changing something.
///
/// Unlike `OcptEditorPageSetupChangedEvent`, this carries no value: the project settings page
/// writes the project's page format itself (through the very same
/// `OcptProjectsManager.saveCurrentProjectPageFormat`), so all this bloc has to do is re-read it
/// and repaginate.
class OcptEditorProjectSettingsChangedEvent extends OcptEditorDocumentEvent {
  /// Class constructor
  const OcptEditorProjectSettingsChangedEvent();
}

/// Dismiss the transient save error currently shown, if any.
class OcptEditorSaveErrorDismissedEvent extends OcptEditorDocumentEvent {
  /// Class constructor
  const OcptEditorSaveErrorDismissedEvent();
}

/// Request leaving the editor and going back to the projects list.
///
/// If the screenplay is dirty, the pending change is flushed with a save first; the current
/// project is then closed and navigation goes back through the router manager.
class OcptEditorBackRequestedEvent extends OcptEditorDocumentEvent {
  /// Class constructor
  const OcptEditorBackRequestedEvent();
}

/// Request updating the screenplay's title-page metadata.
///
/// Each field is written into the Fountain source's title-page section (creating one if the
/// screenplay had none, or dropping it entirely if every field is left blank), then the change is
/// saved (tagged `OcptSnapshotReason.manual`) and the document is re-parsed.
class OcptEditorTitlePageChangedEvent extends OcptEditorDocumentEvent {
  /// The new `Title` field value, or an empty string to clear it.
  final String title;

  /// The new `Credit` field value, or an empty string to clear it.
  final String credit;

  /// The new `Author` field value, or an empty string to clear it.
  final String author;

  /// The new `Draft date` field value, or an empty string to clear it.
  final String draftDate;

  /// The new `Contact` field value, or an empty string to clear it.
  final String contact;

  /// The new `Source` field value, or an empty string to clear it.
  final String source;

  /// Class constructor
  const OcptEditorTitlePageChangedEvent({
    required this.title,
    required this.credit,
    required this.author,
    required this.draftDate,
    required this.contact,
    required this.source,
  });

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, title, credit, author, draftDate, contact, source];
}

/// Request writing the unsaved text before an export reads it, and complete once it is written.
///
/// Dispatched by `OcptEditorIoBloc`, which waits for it; it isn't meant to be sent by widgets. The
/// text is saved tagged `OcptSnapshotReason.export`, and the pending parse and autosave debounces are
/// dropped.
class OcptEditorSaveForExportRequestedEvent extends OcptEditorDocumentEvent {
  /// Class constructor
  const OcptEditorSaveForExportRequestedEvent();
}

/// Request replacing the screenplay text with [text], the text an import has just written to the
/// project, and complete once the mode's state holds it.
///
/// Dispatched by `OcptEditorIoBloc`, which waits for it; it isn't meant to be sent by widgets.
class OcptEditorImportedTextAppliedEvent extends OcptEditorDocumentEvent {
  /// The Fountain text the import wrote, which becomes the clean text of the editor.
  final String text;

  /// Class constructor
  const OcptEditorImportedTextAppliedEvent({required this.text});

  /// {@macro act_flutter_utility.BlocEventForMixin.props}
  @override
  List<Object?> get props => [...super.props, text];
}

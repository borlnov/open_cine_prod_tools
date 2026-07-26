// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/models/ocpt_pdf_export_options.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_right_dock_tab.dart';

/// The events handled by `OcptEditorBloc`.
sealed class OcptEditorEvent extends BlocEventForMixin {
  /// Class constructor
  const OcptEditorEvent();
}

/// Requests loading the current project's screenplay (text, title and page format) into the
/// editor.
///
/// This is dispatched once by the bloc's own constructor; it isn't meant to be sent by widgets.
class OcptEditorLoadRequestedEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorLoadRequestedEvent();
}

/// Reports that the source text was edited by the user.
///
/// This marks the screenplay dirty and (re)starts the parse and autosave debounce timers.
class OcptEditorTextChangedEvent extends OcptEditorEvent {
  /// The full source text as it now stands in the editor.
  final String text;

  /// Class constructor
  const OcptEditorTextChangedEvent({required this.text});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, text];
}

/// Requests a re-parse of the current source text into a fresh `FountainDocument`.
///
/// This is dispatched by the bloc's own parse debounce timer; it isn't meant to be sent by
/// widgets.
class OcptEditorParseRequestedEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorParseRequestedEvent();
}

/// Requests recomputing `OcptEditorState.statistics` from the current document and page setup.
///
/// This is dispatched by the bloc's own statistics debounce timer, kept separate from the parse
/// debounce because pagination is too heavy to run on every parse tick while typing continuously;
/// it isn't meant to be sent by widgets.
class OcptEditorStatisticsRecomputeRequestedEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorStatisticsRecomputeRequestedEvent();
}

/// Requests saving the current source text to the project database.
///
/// [isManual] tells whether the save was explicitly requested by the user (toolbar button or
/// Ctrl+S) rather than triggered by the autosave debounce timer: it decides the snapshot reason
/// the save is tagged with.
class OcptEditorSaveRequestedEvent extends OcptEditorEvent {
  /// Whether the save was explicitly requested by the user.
  final bool isManual;

  /// Class constructor
  const OcptEditorSaveRequestedEvent({required this.isManual});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, isManual];
}

/// Reports that the editor caret moved to another source line.
///
/// The current line drives the preview scroll synchronization and the scene panel highlight.
class OcptEditorCaretMovedEvent extends OcptEditorEvent {
  /// The 0-based source line the caret is now on.
  final int line;

  /// Class constructor
  const OcptEditorCaretMovedEvent({required this.line});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, line];
}

/// Requests moving the editor caret to the character offset a scene starts at.
///
/// This is sent when the user clicks a scene in the scene panel; the page applies the resulting
/// `OcptEditorJumpRequest` to its text controller.
class OcptEditorSceneJumpRequestedEvent extends OcptEditorEvent {
  /// The character offset, in the source text, at which the target scene starts.
  final int charOffset;

  /// Class constructor
  const OcptEditorSceneJumpRequestedEvent({required this.charOffset});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, charOffset];
}

/// Toggles the visibility of the scene panel.
class OcptEditorScenePanelToggledEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorScenePanelToggledEvent();
}

/// Selects a tab of the right dock, dispatched by the toolbar's preview/syntax buttons.
///
/// Implements decision 3's toggle semantics: if [tab] is already the dock's active tab, the dock
/// closes; otherwise the dock opens (or switches) to show [tab]. Either way, this is an explicit
/// user action on the dock, so it also clears `OcptEditorState.autoClosedRightDockTab` — a dock
/// the user just acted on by hand must never be silently reopened by a later mode switch.
class OcptEditorRightDockTabSelectedEvent extends OcptEditorEvent {
  /// The tab the toolbar button pressed represents.
  final OcptEditorRightDockTab tab;

  /// Class constructor
  const OcptEditorRightDockTabSelectedEvent({required this.tab});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, tab];
}

/// Closes the right dock via its own × close button, whichever tab is currently active.
///
/// Just like [OcptEditorRightDockTabSelectedEvent], this is an explicit user action, so it also
/// clears `OcptEditorState.autoClosedRightDockTab`.
class OcptEditorRightDockClosedEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorRightDockClosedEvent();
}

/// Requests updating the editor's dock width fractions, persisting whichever of [left]/[right] is
/// given.
///
/// Dispatched once per drag gesture, on `onHorizontalDragEnd`, never per frame: the live drag
/// itself only moves `OcptEditorDockLayoutController`'s in-memory fractions, which is what keeps a
/// drag from emitting a bloc state (and rebuilding the editing subtrees) on every frame.
class OcptEditorDockFractionsChangedEvent extends OcptEditorEvent {
  /// The new left (scenes) dock fraction, or null to leave it unchanged.
  final double? left;

  /// The new right (preview / syntax) dock fraction, or null to leave it unchanged.
  final double? right;

  /// Class constructor
  const OcptEditorDockFractionsChangedEvent({this.left, this.right});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, left, right];
}

/// Requests restoring both dock fractions to their defaults ("Reset panel layout").
class OcptEditorDockLayoutResetEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorDockLayoutResetEvent();
}

/// Toggles the editing mode between the styled block editor and the raw text source.
///
/// The new mode is persisted through `OcptPropertiesManager.editorMode`, so it's restored the
/// next time the editor is opened.
class OcptEditorModeToggledEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorModeToggledEvent();
}

/// Toggles the "Word-like" page simulation on or off.
///
/// The new value is persisted through `OcptPropertiesManager.isPageSimulationEnabled`, so it's
/// restored the next time the editor is opened.
class OcptEditorPageSimulationToggledEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorPageSimulationToggledEvent();
}

/// Toggles whether the styled editor shows every scene heading's number in its left gutter.
///
/// The new value is persisted through `OcptPropertiesManager.styledSceneNumbersVisible`, so it's
/// restored the next time the editor is opened.
class OcptEditorStyledSceneNumbersToggledEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorStyledSceneNumbersToggledEvent();
}

/// Requests updating the editor's page setup (page size and margins).
///
/// [pageSetup] is persisted (format per-project, margins app-wide) and applied live to the
/// preview and the styled page editor.
class OcptEditorPageSetupChangedEvent extends OcptEditorEvent {
  /// The new page setup to apply and persist.
  final OcptPageSetup pageSetup;

  /// Class constructor
  const OcptEditorPageSetupChangedEvent({required this.pageSetup});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, pageSetup];
}

/// Dismisses the transient save error currently shown, if any.
class OcptEditorSaveErrorDismissedEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorSaveErrorDismissedEvent();
}

/// Requests leaving the editor and going back to the projects list.
///
/// If the screenplay is dirty, the pending change is flushed with a save first; the current
/// project is then closed and navigation goes back through the router manager.
class OcptEditorBackRequestedEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorBackRequestedEvent();
}

/// Requests exporting the current screenplay to a `.fountain` file.
///
/// If the screenplay is dirty, it's saved first (tagged `OcptSnapshotReason.export`) so the
/// exported file matches exactly what the project stores.
class OcptEditorExportRequestedEvent extends OcptEditorEvent {
  /// The label of the file type shown in the native save dialog, localized by the caller.
  final String fileTypeLabel;

  /// Class constructor
  const OcptEditorExportRequestedEvent({required this.fileTypeLabel});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, fileTypeLabel];
}

/// Requests exporting the current screenplay to a PDF file.
///
/// If the screenplay is dirty, it's saved first (tagged `OcptSnapshotReason.export`) so the
/// exported PDF matches exactly what the project stores. [options] carries the one-off
/// format/margins and content toggles picked in the export dialog.
class OcptEditorExportPdfRequestedEvent extends OcptEditorEvent {
  /// The options this export runs with.
  final OcptPdfExportOptions options;

  /// The label of the file type shown in the native save dialog, localized by the caller.
  final String fileTypeLabel;

  /// Class constructor
  const OcptEditorExportPdfRequestedEvent({required this.options, required this.fileTypeLabel});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, options, fileTypeLabel];
}

/// Requests replacing the current screenplay text with the content of a picked `.fountain` file.
///
/// Dispatched only once the user confirmed the replacement in the import confirmation dialog.
class OcptEditorImportRequestedEvent extends OcptEditorEvent {
  /// The label of the file type shown in the open-file dialog, localized by the caller.
  final String fileTypeLabel;

  /// Class constructor
  const OcptEditorImportRequestedEvent({required this.fileTypeLabel});

  /// Object properties
  @override
  List<Object?> get props => [...super.props, fileTypeLabel];
}

/// Dismisses the transient export/import notice currently shown, if any.
class OcptEditorIoNoticeDismissedEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorIoNoticeDismissedEvent();
}

/// Requests updating the screenplay's title-page metadata.
///
/// Each field is written into the Fountain source's title-page section (creating one if the
/// screenplay had none, or dropping it entirely if every field is left blank), then the change is
/// saved (tagged `OcptSnapshotReason.manual`) and the document is re-parsed.
class OcptEditorTitlePageChangedEvent extends OcptEditorEvent {
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

  /// Object properties
  @override
  List<Object?> get props => [...super.props, title, credit, author, draftDate, contact, source];
}

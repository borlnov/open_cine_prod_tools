// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';

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

/// Toggles the visibility of the formatted preview panel.
class OcptEditorPreviewToggledEvent extends OcptEditorEvent {
  /// Class constructor
  const OcptEditorPreviewToggledEvent();
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
  /// Class constructor
  const OcptEditorExportRequestedEvent();
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

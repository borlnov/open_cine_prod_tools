// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:equatable/equatable.dart';
import 'package:fountain_kit/fountain_kit.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_mode.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// A request, produced by `OcptEditorBloc`, for the page to move the editor caret to
/// [charOffset].
///
/// [id] increases with every request, so the page's bloc listener can tell a fresh request apart
/// from the one it already applied even when two consecutive requests target the same offset
/// (e.g. clicking the same scene twice).
class OcptEditorJumpRequest extends Equatable {
  /// The character offset, in the source text, to move the caret to.
  final int charOffset;

  /// The monotonically increasing identifier of this request.
  final int id;

  /// Class constructor
  const OcptEditorJumpRequest({required this.charOffset, required this.id});

  /// Object properties
  @override
  List<Object?> get props => [charOffset, id];
}

/// The kind of transient notice `OcptEditorIoNotice` carries, one per export/import outcome.
enum OcptEditorIoNoticeKind {
  /// The screenplay was successfully exported to a `.fountain` file.
  exportSucceeded,

  /// Exporting the screenplay to a `.fountain` file failed.
  exportFailed,

  /// The screenplay text was successfully replaced by an imported `.fountain` file.
  importSucceeded,

  /// Importing a `.fountain` file to replace the screenplay text failed.
  importFailed,
}

/// A transient notice, produced by `OcptEditorBloc`, reporting the outcome of an export or an
/// import-and-replace, shown as a SnackBar then dismissed.
class OcptEditorIoNotice extends Equatable {
  /// The outcome this notice reports.
  final OcptEditorIoNoticeKind kind;

  /// The path the screenplay was exported to, only set when [kind] is
  /// [OcptEditorIoNoticeKind.exportSucceeded].
  final String? path;

  /// Class constructor
  const OcptEditorIoNotice({required this.kind, this.path});

  /// Object properties
  @override
  List<Object?> get props => [kind, path];
}

/// The state of `OcptEditorBloc`.
class OcptEditorState extends BlocStateForMixin<OcptEditorState> {
  /// Whether the screenplay is still being loaded from the project database.
  final bool isLoading;

  /// The title shown in the toolbar: the name of the project currently open.
  final String title;

  /// The full source text as last reported to the bloc (the text controller owns the live text).
  final String text;

  /// The last parsed document, or null while nothing has been parsed yet.
  ///
  /// The document lags [text] by the parse debounce delay: it always corresponds to some recent
  /// value of [text], not necessarily the latest one.
  final FountainDocument? document;

  /// Whether [text] holds changes that haven't been saved to the project database yet.
  final bool isDirty;

  /// Whether a save is currently in progress.
  final bool isSaving;

  /// The time of the last successful save, or null if nothing was saved in this session yet.
  final DateTime? lastSavedAt;

  /// Whether the last save attempt failed; shown as a transient SnackBar then dismissed.
  final bool hasSaveError;

  /// The 0-based source line the editor caret is currently on.
  final int currentLine;

  /// Whether the scene panel is shown.
  final bool isScenePanelVisible;

  /// Whether the formatted preview panel is shown.
  final bool isPreviewVisible;

  /// The current editing mode: the styled block editor or the raw text source.
  ///
  /// Persisted through `OcptPropertiesManager.editorMode`, loaded once on entry and updated on
  /// every toggle.
  final OcptEditorMode mode;

  /// The page format of the project, driving the preview's layout metrics.
  final OcptPageFormat pageFormat;

  /// Whether the "Word-like" page simulation (distinct paper sheets, real page size and
  /// margins) is enabled, in both the raw preview and the styled editor.
  ///
  /// Persisted through `OcptPropertiesManager.isPageSimulationEnabled`, loaded once on entry and
  /// updated on every toggle; on by default.
  final bool isPageSimulationEnabled;

  /// The pending caret jump request, or null if none was ever made.
  ///
  /// The page keeps track of the last [OcptEditorJumpRequest.id] it applied, so this doesn't
  /// need to be cleared once handled.
  final OcptEditorJumpRequest? jumpRequest;

  /// The transient export/import outcome currently shown as a SnackBar, or null if none is.
  final OcptEditorIoNotice? ioNotice;

  /// The scene headings of [document], in source order (empty while nothing is parsed).
  List<FountainSceneHeading> get scenes => document?.scenes ?? const [];

  /// Class constructor
  const OcptEditorState({
    required this.isLoading,
    required this.title,
    required this.text,
    required this.document,
    required this.isDirty,
    required this.isSaving,
    required this.lastSavedAt,
    required this.hasSaveError,
    required this.currentLine,
    required this.isScenePanelVisible,
    required this.isPreviewVisible,
    required this.mode,
    required this.pageFormat,
    required this.isPageSimulationEnabled,
    required this.jumpRequest,
    required this.ioNotice,
  });

  /// Init class constructor
  const OcptEditorState.init()
    : isLoading = true,
      title = "",
      text = "",
      document = null,
      isDirty = false,
      isSaving = false,
      lastSavedAt = null,
      hasSaveError = false,
      currentLine = 0,
      isScenePanelVisible = true,
      isPreviewVisible = true,
      mode = OcptEditorMode.styled,
      pageFormat = OcptPageFormat.usLetter,
      isPageSimulationEnabled = true,
      jumpRequest = null,
      ioNotice = null;

  /// {@macro act_flutter_utility.BlocStateForMixin.copyWith}
  ///
  /// [document], [lastSavedAt] and [jumpRequest] are only replaced when a new value is given:
  /// they never go back to null once set, so no clear flag is needed for them. [ioNotice] is only
  /// replaced when a new one is given or [clearIoNotice] is true, exactly like `OcptHomeState`'s
  /// own `error` field.
  @override
  OcptEditorState copyWith({
    bool? isLoading,
    String? title,
    String? text,
    FountainDocument? document,
    bool? isDirty,
    bool? isSaving,
    DateTime? lastSavedAt,
    bool? hasSaveError,
    int? currentLine,
    bool? isScenePanelVisible,
    bool? isPreviewVisible,
    OcptEditorMode? mode,
    OcptPageFormat? pageFormat,
    bool? isPageSimulationEnabled,
    OcptEditorJumpRequest? jumpRequest,
    OcptEditorIoNotice? ioNotice,
    bool clearIoNotice = false,
  }) => OcptEditorState(
    isLoading: isLoading ?? this.isLoading,
    title: title ?? this.title,
    text: text ?? this.text,
    document: document ?? this.document,
    isDirty: isDirty ?? this.isDirty,
    isSaving: isSaving ?? this.isSaving,
    lastSavedAt: lastSavedAt ?? this.lastSavedAt,
    hasSaveError: hasSaveError ?? this.hasSaveError,
    currentLine: currentLine ?? this.currentLine,
    isScenePanelVisible: isScenePanelVisible ?? this.isScenePanelVisible,
    isPreviewVisible: isPreviewVisible ?? this.isPreviewVisible,
    mode: mode ?? this.mode,
    pageFormat: pageFormat ?? this.pageFormat,
    isPageSimulationEnabled: isPageSimulationEnabled ?? this.isPageSimulationEnabled,
    jumpRequest: jumpRequest ?? this.jumpRequest,
    ioNotice: clearIoNotice ? null : (ioNotice ?? this.ioNotice),
  );

  /// Object properties
  @override
  List<Object?> get props => [
    ...super.props,
    isLoading,
    title,
    text,
    document,
    isDirty,
    isSaving,
    lastSavedAt,
    hasSaveError,
    currentLine,
    isScenePanelVisible,
    isPreviewVisible,
    mode,
    pageFormat,
    isPageSimulationEnabled,
    jumpRequest,
    ioNotice,
  ];
}

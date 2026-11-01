// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_entry.dart';
import 'package:open_cine_prod_tools/models/ocpt_workspace_export_pick.dart';
import 'package:open_cine_prod_tools/types/ocpt_editor_export_document.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_settings_reveal.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_event.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_io_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_io_notice.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_io_notice_kind.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/editor_spell_check_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_export_pdf_options_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_page_setup_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/editor/widgets/ocpt_editor_title_page_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/widgets/ocpt_workspace_export_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/workspace_event.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_project_package_missing_files_confirm.dart';
import 'package:open_cine_prod_tools/ui/widgets/helpers/ocpt_workspace_episode_export_tag.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';

/// The dialogs the screenplay editor page opens, and the event each one's answer becomes.
///
/// A widget only ever asks: it is the page that opens a confirmation or an options dialog, resolves
/// every localized word here — the last place with a [BuildContext] — and hands the blocs plain
/// events. An irreversible action is always confirmed through `OcptConfirmDialog`.
class OcptEditorDialogFlows {
  /// Private constructor: this class only exposes static members.
  OcptEditorDialogFlows._();

  /// Show the import confirmation dialog, then dispatch the import request if the user
  /// confirmed the replacement.
  static Future<void> importAndReplace(BuildContext context) async {
    final bloc = context.read<OcptEditorIoBloc>();
    final tr = Tr.of(context);
    final confirmed = await OcptConfirmDialog.show(
      context,
      title: tr.editorImportConfirmTitle,
      message: tr.editorImportConfirmMessage,
      cancelLabel: tr.editorImportConfirmCancelAction,
      confirmLabel: tr.editorImportConfirmReplaceAction,
      isDestructive: false,
    );
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(
      OcptEditorImportRequestedEvent(fileTypeLabel: Tr.of(context).editorImportFileTypeLabel),
    );
  }

  /// Show the page setup dialog, then dispatch the new page setup if the user applied it.
  static Future<void> pageSetup(BuildContext context) async {
    final bloc = context.read<OcptEditorBloc>();
    final setup = await OcptEditorPageSetupDialog.show(context, current: bloc.state.pageSetup);
    if (setup == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(OcptEditorPageSetupChangedEvent(pageSetup: setup));
  }

  /// Open the project settings page, then reload the page format (and repaginates) if the user
  /// changed anything there.
  ///
  /// Also tells `OcptWorkspaceBloc` to reload its episodes: the settings page's own `Episodes`
  /// card can add or delete one, which the workspace bloc otherwise only learns about from
  /// `OcptProjectsManager.currentProjectStream`, an event the episode CRUD does not fire.
  ///
  /// [reveal] names the card the page opens on, for the toolbar's `Add an episode…` button which
  /// promised one; the toolbar's plain settings action passes none and lands at the top.
  static Future<void> projectSettings(
    BuildContext context, {
    OcptProjectSettingsReveal? reveal,
  }) async {
    final bloc = context.read<OcptEditorBloc>();
    final spellCheckBloc = context.read<OcptEditorSpellCheckBloc>();
    final workspaceBloc = context.read<OcptWorkspaceBloc>();
    final hasChanged = await globalGetIt().get<OcptRouterManager>().push<bool>(
      OcptRoute.projectSettings,
      extra: reveal,
    );
    if (hasChanged != true) {
      return;
    }

    bloc.add(const OcptEditorProjectSettingsChangedEvent());
    spellCheckBloc.add(const OcptEditorSpellCheckDictionaryRefreshRequestedEvent());
    workspaceBloc.add(const OcptWorkspaceEpisodesReloadRequestedEvent());
  }

  /// Open the export panel, then dispatch the picked document's own request: the `.fountain`
  /// export event directly (it opens no options dialog of its own), or [_exportPdf], which
  /// opens the PDF export options dialog exactly as it always has.
  static Future<void> export(BuildContext context, Rect? shareAnchor) async {
    final tr = Tr.of(context);
    final picked = await OcptWorkspaceExportDialog.show<OcptEditorExportDocument>(
      context,
      title: tr.editorExportPanelTitle,
      message: tr.editorExportPanelMessage,
      entries: _exportEntries(context),
      isPreviewingVersion: context.read<OcptEditorBloc>().state.isPreviewingVersion,
    );
    if (picked == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    switch (picked) {
      case OcptWorkspaceExportDocumentPick<OcptEditorExportDocument>(:final document):
        switch (document) {
          case OcptEditorExportDocument.fountain:
            context.read<OcptEditorIoBloc>().add(
              OcptEditorExportRequestedEvent(
                fileTypeLabel: tr.editorImportFileTypeLabel,
                episodeTag: _episodeExportTag(context),
                shareAnchor: shareAnchor,
              ),
            );
          case OcptEditorExportDocument.pdf:
            await _exportPdf(context, shareAnchor);
        }
      case OcptWorkspaceExportProjectPackagePick<OcptEditorExportDocument>():
        _projectPackageExport(context);
    }
  }

  /// Show the title page dialog, then dispatch the edited fields if the user applied them.
  static Future<void> titlePage(BuildContext context) async {
    final bloc = context.read<OcptEditorBloc>();
    final fields = await OcptEditorTitlePageDialog.show(
      context,
      current: bloc.state.document?.titlePage,
    );
    if (fields == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(
      OcptEditorTitlePageChangedEvent(
        title: fields.title,
        credit: fields.credit,
        author: fields.author,
        draftDate: fields.draftDate,
        contact: fields.contact,
        source: fields.source,
      ),
    );
  }

  /// Ask whether to write the package even though some referenced files are gone, then dispatch
  /// the export if the user said to go on.
  ///
  /// Opened from the bloc's state rather than from the panel's own click, since only the bloc can
  /// read the project file the pre-flight scanned. The question is cleared from that state the
  /// moment this opens, so a later emission never stacks a second dialog behind this one.
  static Future<void> askAboutMissingPackagedFiles(
    BuildContext context,
    OcptProjectPackagePreflight preflight,
  ) async {
    final bloc = context.read<OcptEditorBloc>();
    final confirmed = await ocptAskAboutMissingPackagedFiles(context, preflight);
    if (confirmed != true) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(
      OcptProjectPackageExportConfirmedEvent(
        fileTypeLabel: Tr.of(context).projectPackageFileTypeLabel,
      ),
    );
  }

  /// Map [notice] to its localized, user-facing message.
  ///
  /// A succeeded export kind degrades to the generic "shared" message on mobile
  /// ([OcptEditorIoNotice.wasShared]): there is no path to name, the export having been handed to
  /// the OS share sheet rather than written to a location the user picked.
  static String ioNoticeMessage(BuildContext context, OcptEditorIoNotice notice) {
    final tr = Tr.of(context);

    return switch (notice.kind) {
      OcptEditorIoNoticeKind.exportSucceeded =>
        notice.wasShared
            ? tr.exportSharedMessage
            : tr.editorExportSuccessMessage(notice.path ?? ""),
      OcptEditorIoNoticeKind.exportFailed => tr.editorExportError,
      OcptEditorIoNoticeKind.importSucceeded => tr.editorImportSuccessMessage,
      OcptEditorIoNoticeKind.importFailed => tr.editorImportError,
      OcptEditorIoNoticeKind.importUnreadable => tr.editorImportUnreadableError,
      OcptEditorIoNoticeKind.pdfExportSucceeded =>
        notice.wasShared
            ? tr.exportSharedMessage
            : tr.editorExportPdfSuccessMessage(notice.path ?? ""),
      OcptEditorIoNoticeKind.pdfExportFailed => tr.editorExportPdfError,
    };
  }

  /// Build the two entries the toolbar's `Export` button offers: the screenplay's own Fountain
  /// source and the typeset PDF. Both are always available — see `OcptEditorExportDocument`'s own
  /// doc comment.
  static List<OcptWorkspaceExportEntry<OcptEditorExportDocument>> _exportEntries(
    BuildContext context,
  ) {
    final tr = Tr.of(context);

    return [
      OcptWorkspaceExportEntry<OcptEditorExportDocument>(
        value: OcptEditorExportDocument.fountain,
        title: tr.editorExportFountainTitle,
        description: tr.editorExportFountainDescription,
        formatLabel: ".fountain",
      ),
      OcptWorkspaceExportEntry<OcptEditorExportDocument>(
        value: OcptEditorExportDocument.pdf,
        title: tr.editorExportPdfTitle,
        description: tr.editorExportPdfDescription,
        formatLabel: "PDF",
      ),
    ];
  }

  /// Show the PDF export options dialog, then dispatch the export request if the user applied
  /// it.
  static Future<void> _exportPdf(BuildContext context, Rect? shareAnchor) async {
    final bloc = context.read<OcptEditorIoBloc>();
    final options = await OcptEditorExportPdfOptionsDialog.show(
      context,
      current: context.read<OcptEditorBloc>().state.pageSetup,
    );
    if (options == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    bloc.add(
      OcptEditorExportPdfRequestedEvent(
        options: options,
        fileTypeLabel: Tr.of(context).editorExportPdfFileTypeLabel,
        episodeTag: _episodeExportTag(context),
        shareAnchor: shareAnchor,
      ),
    );
  }

  /// Get the selected episode's own tag (`ep. 2`), or null while the open project holds one episode
  /// or
  /// none — read here, the last place with a [BuildContext] before an export event is dispatched,
  /// exactly as every other localized export payload already is.
  static String? _episodeExportTag(BuildContext context) {
    final workspaceState = context.read<OcptWorkspaceBloc>().state;
    return ocptWorkspaceEpisodeExportTagOf(
      context: context,
      episodes: workspaceState.episodes,
      selectedEpisodeId: workspaceState.selectedEpisodeId,
    );
  }

  /// Dispatch the project package export, resolving here — the last place with a
  /// [BuildContext] — the label the native save dialog carries.
  ///
  /// What happens next depends on what the project references: everything being there, the save
  /// dialog opens straight away; anything missing, the bloc asks back through its own state and
  /// [askAboutMissingPackagedFiles] is what puts that question on screen.
  static void _projectPackageExport(BuildContext context) {
    context.read<OcptEditorBloc>().add(
      OcptProjectPackageExportRequestedEvent(
        fileTypeLabel: Tr.of(context).projectPackageFileTypeLabel,
      ),
    );
  }
}

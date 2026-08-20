// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async' show unawaited;

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_file_compatibility.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_report.dart';
import 'package:open_cine_prod_tools/models/ocpt_project_package_target.dart';
import 'package:open_cine_prod_tools/types/ocpt_home_import_kind.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_file_verdict.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_package_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_import_status.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_event.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_state.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_home_empty_state.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_home_header.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_home_import_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_new_project_name_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_project_card.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_project_file_newer_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_project_package_skipped_files_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/workspace/blocs/ocpt_project_package_events.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_package_missing_files_confirm.dart';
import 'package:open_cine_prod_tools/ui/utils/ocpt_project_package_notice_message.dart';
import 'package:open_cine_prod_tools/ui/widgets/ocpt_confirm_dialog.dart';

/// Displays the project card grid: the app's real landing page.
///
/// Lets the user create a new project, open an existing one, or pick up a recently opened one
/// from the grid.
class HomePage extends StatelessWidget {
  /// Creates the home page.
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (context) => OcptHomeBloc(), child: const _HomeView());
}

/// The content of [HomePage], separated from it so [HomePage] only wires the [OcptHomeBloc] up
/// (RFL3).
class _HomeView extends StatelessWidget {
  /// Class constructor
  const _HomeView();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: BlocConsumer<OcptHomeBloc, OcptHomeState>(
      listener: _onStateChanged,
      builder: (context, state) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OcptHomeHeader(
                onNewProject: () => _requestNewProject(context),
                onOpenProject: () => _requestOpenProject(context),
                onImport: () => _requestImport(context),
                onOpenSettings: () => _requestOpenSettings(context),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: state.recentProjects.isEmpty
                    ? OcptHomeEmptyState(
                        onNewProject: () => _requestNewProject(context),
                        onOpenProject: () => _requestOpenProject(context),
                        onImport: () => _requestImport(context),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 280,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: state.recentProjects.length,
                        itemBuilder: (context, index) {
                          final entry = state.recentProjects[index];

                          return OcptProjectCard(
                            entry: entry,
                            onTap: () => context.read<OcptHomeBloc>().add(
                              OcptHomeOpenProjectRequestedEvent(
                                filePath: entry.project.path,
                                fileTypeLabel: Tr.of(context).homeOpenFileTypeLabel,
                              ),
                            ),
                            onExport: () => context.read<OcptHomeBloc>().add(
                              OcptProjectPackageExportRequestedEvent(
                                fileTypeLabel: Tr.of(context).projectPackageFileTypeLabel,
                                target: OcptProjectPackageTarget(
                                  filePath: entry.project.path,
                                  name: entry.project.name,
                                ),
                              ),
                            ),
                            onRemove: () => context.read<OcptHomeBloc>().add(
                              OcptHomeRemoveRecentProjectRequestedEvent(path: entry.project.path),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  /// States whatever [state] is holding for the user: the verdict on a project file whose format
  /// isn't this build's, the transient error of a failed create/open, a project card's export
  /// pre-flight asking about missing files, the outcome of that export, a failed project package
  /// import, and a landed one's report — each dismissed from the state as soon as it has been put
  /// on screen.
  void _onStateChanged(BuildContext context, OcptHomeState state) {
    final compatibility = state.pendingFileCompatibility;
    if (compatibility != null) {
      context.read<OcptHomeBloc>().add(const OcptHomeFileCompatibilityStatedEvent());
      unawaited(_stateFileCompatibility(context, compatibility));
    }

    final error = state.error;
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_errorMessage(context, error))));

      context.read<OcptHomeBloc>().add(const OcptHomeErrorDismissedEvent());
    }

    final packagePendingExport = state.projectPackagePendingExport;
    if (packagePendingExport != null) {
      context.read<OcptHomeBloc>().add(const OcptProjectPackageMissingFilesAskDismissedEvent());
      unawaited(_askAboutMissingPackagedFiles(context, packagePendingExport));
    }

    final packageNotice = state.projectPackageNotice;
    if (packageNotice != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(ocptProjectPackageNoticeMessage(context, packageNotice))),
        );
      context.read<OcptHomeBloc>().add(const OcptProjectPackageNoticeDismissedEvent());
    }

    final packageImportError = state.projectPackageImportError;
    if (packageImportError != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_importErrorMessage(context, packageImportError))));

      context.read<OcptHomeBloc>().add(const OcptHomeProjectPackageImportErrorDismissedEvent());
    }

    final screenplayImportError = state.screenplayImportError;
    if (screenplayImportError != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(_screenplayImportErrorMessage(context, screenplayImportError))),
        );

      context.read<OcptHomeBloc>().add(const OcptHomeScreenplayImportErrorDismissedEvent());
    }

    final packageImportReport = state.projectPackageImportReport;
    if (packageImportReport != null) {
      context.read<OcptHomeBloc>().add(const OcptHomeProjectPackageImportReportDismissedEvent());
      unawaited(_landImportedPackage(context, packageImportReport));
    }
  }

  /// States the skipped files a landed project package import carries, if any, then dispatches the
  /// open that finishes bringing it in.
  ///
  /// The dialog is shown **before** the open, on purpose — the plan's own arbitration: a SnackBar
  /// would be covered by the pushed workspace within the second, and nothing at all is said when
  /// [report] carries no skipped file, the project opening being the report then. The open reuses
  /// the very same compatibility gate every other door into a project file goes through: a package
  /// built by an older build lands as files here and *then* asks its migration question, exactly as
  /// tapping a recent project card would.
  Future<void> _landImportedPackage(
    BuildContext context,
    OcptProjectPackageImportReport report,
  ) async {
    if (report.skippedAssets.isNotEmpty) {
      await OcptProjectPackageSkippedFilesDialog.show(context, skippedAssets: report.skippedAssets);
    }
    if (!context.mounted) {
      return;
    }

    context.read<OcptHomeBloc>().add(
      OcptHomeOpenProjectRequestedEvent(
        filePath: report.projectFilePath,
        fileTypeLabel: Tr.of(context).homeOpenFileTypeLabel,
      ),
    );
  }

  /// Asks whether to write a card's package even though some referenced files are gone, then
  /// dispatches the export if the user said to go on.
  ///
  /// Mirrors every production mode's own `_askAboutMissingPackagedFiles` step for step: opened
  /// from the bloc's state rather than from the card's own click, since only the bloc can read the
  /// project file the pre-flight scanned, and the question is cleared from that state the moment
  /// this opens, so a later emission never stacks a second dialog behind this one.
  Future<void> _askAboutMissingPackagedFiles(
    BuildContext context,
    OcptProjectPackagePreflight preflight,
  ) async {
    final bloc = context.read<OcptHomeBloc>();
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

  /// Puts [compatibility] in front of the user: the migration to answer for an older file, the
  /// refusal for a newer one.
  ///
  /// The migration is confirmed through [OcptConfirmDialog] like every other irreversible action of
  /// this app, and it is the *page* that opens it — the bloc raised the question, it never words
  /// it.
  /// Confirming re-dispatches the very open that stopped here, this time allowed to migrate; the
  /// file's own path travels with the verdict, so the file that is updated is the one that was
  /// asked about.
  ///
  /// Not marked destructive: the project is brought forward rather than lost, and the copy the
  /// message names is kept precisely so nothing is.
  Future<void> _stateFileCompatibility(
    BuildContext context,
    OcptProjectFileCompatibility compatibility,
  ) async {
    switch (compatibility.verdict) {
      case OcptProjectFileVerdict.older:
        final tr = Tr.of(context);
        final bloc = context.read<OcptHomeBloc>();
        final fileTypeLabel = tr.homeOpenFileTypeLabel;

        final confirmed = await OcptConfirmDialog.show(
          context,
          title: tr.homeMigrateProjectTitle,
          message: tr.homeMigrateProjectMessage(
            compatibility.fileSchemaVersion,
            compatibility.appSchemaVersion,
            compatibility.suggestedBackupPath ?? "",
          ),
          cancelLabel: tr.homeMigrateProjectCancelAction,
          confirmLabel: tr.homeMigrateProjectConfirmAction,
          isDestructive: false,
        );
        if (confirmed != true) {
          return;
        }

        bloc.add(
          OcptHomeOpenProjectRequestedEvent(
            filePath: compatibility.filePath,
            fileTypeLabel: fileTypeLabel,
            allowMigration: true,
          ),
        );
      case OcptProjectFileVerdict.newer:
        await OcptProjectFileNewerDialog.show(context, compatibility: compatibility);
      case OcptProjectFileVerdict.current:
      case OcptProjectFileVerdict.unreadable:
        // Never raised: a file this build opens as it is has nothing to state.
        break;
    }
  }

  /// Maps [status] to its localized, user-facing message.
  String _errorMessage(BuildContext context, OcptProjectStatus status) {
    final tr = Tr.of(context);

    return switch (status) {
      OcptProjectStatus.ok => "",
      OcptProjectStatus.fileNotFound => tr.homeErrorFileNotFound,
      OcptProjectStatus.corruptedFile => tr.homeErrorCorruptedFile,
      OcptProjectStatus.migrationRequired => tr.homeErrorMigrationRequired,
      OcptProjectStatus.newerFormat => tr.homeErrorNewerFormat,
      OcptProjectStatus.alreadyOpen => tr.homeErrorAlreadyOpen,
      OcptProjectStatus.ioError => tr.homeErrorIoError,
    };
  }

  /// Maps [status] to its localized, user-facing message.
  ///
  /// [OcptProjectPackageStatus.ok] and [OcptProjectPackageStatus.sourceNotFound] are never raised
  /// by an import — the former is success, not an error, and the latter is
  /// `OcptProjectsManager.exportProjectPackage`'s own refusal for a project file gone missing
  /// between picking it and reading it, which an import's own picked `.ocptz` has no equivalent
  /// of. Both still need a branch for the switch to be exhaustive, so each falls back to the same
  /// generic sentence [OcptProjectPackageStatus.ioError] gets.
  String _importErrorMessage(BuildContext context, OcptProjectPackageStatus status) {
    final tr = Tr.of(context);

    return switch (status) {
      OcptProjectPackageStatus.ok || OcptProjectPackageStatus.sourceNotFound => "",
      OcptProjectPackageStatus.unreadableArchive => tr.homeImportErrorUnreadableArchive,
      OcptProjectPackageStatus.unsupportedPackageFormat => tr.homeImportErrorUnsupportedFormat,
      OcptProjectPackageStatus.destinationExists => tr.homeImportErrorDestinationExists,
      OcptProjectPackageStatus.ioError => tr.homeImportErrorIoError,
    };
  }

  /// Maps [status] to its localized, user-facing message.
  ///
  /// [OcptScreenplayImportStatus.ok] and [OcptScreenplayImportStatus.cancelled] never reach the
  /// state at all — the first is a created project, the second a silent no-op — but still need a
  /// branch for the switch to be exhaustive. [OcptScreenplayImportStatus.ioError] shares the one
  /// sentence [OcptScreenplayImportStatus.unreadableFile] gets: whether the bytes never came back
  /// or came back as something that is not a screenplay, what the user is told is the same, and
  /// nothing they could do differs.
  String _screenplayImportErrorMessage(BuildContext context, OcptScreenplayImportStatus status) {
    final tr = Tr.of(context);

    return switch (status) {
      OcptScreenplayImportStatus.ok || OcptScreenplayImportStatus.cancelled => "",
      OcptScreenplayImportStatus.unreadableFile ||
      OcptScreenplayImportStatus.ioError => tr.homeImportScreenplayUnreadableError,
    };
  }

  /// Asks the user for a new project's name, then dispatches the creation request.
  Future<void> _requestNewProject(BuildContext context) async {
    final bloc = context.read<OcptHomeBloc>();
    final name = await OcptNewProjectNameDialog.show(context);
    if (name == null) {
      return;
    }

    bloc.add(OcptHomeCreateProjectRequestedEvent(name: name));
  }

  /// Dispatches the open request that shows the open-file dialog.
  void _requestOpenProject(BuildContext context) {
    context.read<OcptHomeBloc>().add(
      OcptHomeOpenProjectRequestedEvent(fileTypeLabel: Tr.of(context).homeOpenFileTypeLabel),
    );
  }

  /// Opens the `Import…` modal, then dispatches whichever of the two import flows the user picked
  /// a card for — a cancelled modal is a silent no-op, exactly as every dialog of this app treats
  /// one.
  Future<void> _requestImport(BuildContext context) async {
    final kind = await OcptHomeImportDialog.show(context);
    if (kind == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    switch (kind) {
      case OcptHomeImportKind.project:
        _requestImportProjectPackage(context);
      case OcptHomeImportKind.screenplay:
        _requestImportScreenplay(context);
    }
  }

  /// Dispatches the import-screenplay request that shows the screenplay open-file dialog.
  void _requestImportScreenplay(BuildContext context) {
    context.read<OcptHomeBloc>().add(
      OcptHomeImportScreenplayRequestedEvent(
        screenplayFileTypeLabel: Tr.of(context).homeImportFileTypeLabel,
      ),
    );
  }

  /// Dispatches the import-project-package request that shows the `.ocptz` open-file dialog, then
  /// the destination folder picker.
  void _requestImportProjectPackage(BuildContext context) {
    final tr = Tr.of(context);

    context.read<OcptHomeBloc>().add(
      OcptHomeImportProjectPackageRequestedEvent(
        packageFileTypeLabel: tr.projectPackageFileTypeLabel,
        destinationConfirmButtonText: tr.homeImportProjectDestinationConfirmAction,
      ),
    );
  }

  /// Navigates to the settings page.
  ///
  /// Unlike the other actions above, this is a plain page push with no async work or result to
  /// wait on, so it goes straight through the router manager instead of round-tripping through
  /// [OcptHomeBloc].
  void _requestOpenSettings(BuildContext context) {
    unawaited(globalGetIt().get<OcptRouterManager>().push(OcptRoute.settings));
  }
}

// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:async' show unawaited;

import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_project_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_route.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_bloc.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_event.dart';
import 'package:open_cine_prod_tools/ui/pages/home/home_state.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_home_empty_state.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_home_header.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_new_project_name_dialog.dart';
import 'package:open_cine_prod_tools/ui/pages/home/widgets/ocpt_project_card.dart';

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
                onImportScreenplay: () => _requestImportScreenplay(context),
                onOpenSettings: () => _requestOpenSettings(context),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: state.recentProjects.isEmpty
                    ? OcptHomeEmptyState(
                        onNewProject: () => _requestNewProject(context),
                        onOpenProject: () => _requestOpenProject(context),
                        onImportScreenplay: () => _requestImportScreenplay(context),
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

  /// Shows the SnackBar for [state]'s transient error, if any, then dismisses it from the state.
  void _onStateChanged(BuildContext context, OcptHomeState state) {
    final error = state.error;
    if (error == null) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(_errorMessage(context, error))));

    context.read<OcptHomeBloc>().add(const OcptHomeErrorDismissedEvent());
  }

  /// Maps [status] to its localized, user-facing message.
  String _errorMessage(BuildContext context, OcptProjectStatus status) {
    final tr = Tr.of(context);

    return switch (status) {
      OcptProjectStatus.ok => "",
      OcptProjectStatus.fileNotFound => tr.homeErrorFileNotFound,
      OcptProjectStatus.corruptedFile => tr.homeErrorCorruptedFile,
      OcptProjectStatus.alreadyOpen => tr.homeErrorAlreadyOpen,
      OcptProjectStatus.ioError => tr.homeErrorIoError,
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

  /// Dispatches the import-screenplay request that shows the `.fountain` open-file dialog.
  void _requestImportScreenplay(BuildContext context) {
    context.read<OcptHomeBloc>().add(
      OcptHomeImportScreenplayRequestedEvent(
        fountainFileTypeLabel: Tr.of(context).homeImportFileTypeLabel,
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

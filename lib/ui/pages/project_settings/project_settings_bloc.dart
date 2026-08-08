// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_flutter_utility/act_flutter_utility.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/database/tables/ocpt_project_info_table.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_event.dart';
import 'package:open_cine_prod_tools/ui/pages/project_settings/project_settings_state.dart';

/// This is the bloc class for the project settings page.
///
/// It loads the current project's currency and page format from [OcptProjectsManager] on entry,
/// and writes each field back to the project the moment it changes — there is no separate save
/// step, exactly like the appearance and language sections of the app-wide settings page. The page
/// format is written through the very same `OcptProjectsManager.saveCurrentProjectPageFormat` the
/// screenplay editor's own page-setup dialog uses, so the two can never disagree.
class OcptProjectSettingsBloc extends BlocForMixin<OcptProjectSettingsState> {
  /// The manager used to read and write the current project's settings.
  final OcptProjectsManager _projectsManager;

  /// Class constructor
  OcptProjectSettingsBloc({OcptProjectsManager? projectsManager})
    : _projectsManager = projectsManager ?? globalGetIt().get<OcptProjectsManager>(),
      super(const OcptProjectSettingsState.init()) {
    add(const OcptProjectSettingsLoadRequestedEvent());
  }

  /// {@macro act_flutter_utility.BlocForMixin.registerMixinEvents}
  @override
  void registerMixinEvents() {
    super.registerMixinEvents();
    on<OcptProjectSettingsLoadRequestedEvent>(_onLoadRequested);
    on<OcptProjectSettingsCurrencyChangedEvent>(_onCurrencyChanged);
    on<OcptProjectSettingsPageFormatChangedEvent>(_onPageFormatChanged);
    on<OcptProjectSettingsMinimumRestMinutesChangedEvent>(_onMinimumRestMinutesChanged);
  }

  /// Loads the current project's currency and page format.
  ///
  /// The route that reaches this page is guarded exactly like the workspace's own: a project is
  /// always open by the time this runs. The fallbacks below only ever matter if that guard were
  /// ever bypassed, and mirror the ones every other reader of these two properties already uses.
  Future<void> _onLoadRequested(
    OcptProjectSettingsLoadRequestedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    final currencyCode = await _projectsManager.loadCurrentProjectCurrencyCode();
    final pageFormat = await _projectsManager.loadCurrentProjectPageFormat();
    final minimumRestMinutes = await _projectsManager.loadCurrentProjectMinimumRestMinutes();

    emitter(
      state.copyWith(
        isLoading: false,
        currencyCode: currencyCode ?? ocptDefaultCurrencyCode,
        pageFormat: pageFormat ?? OcptPageFormat.usLetter,
        minimumRestMinutes: minimumRestMinutes,
        clearMinimumRestMinutes: minimumRestMinutes == null,
      ),
    );
  }

  /// Writes the newly picked currency to the project, then reflects it in the state.
  Future<void> _onCurrencyChanged(
    OcptProjectSettingsCurrencyChangedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    await _projectsManager.saveCurrentProjectCurrencyCode(event.currencyCode);
    emitter(state.copyWith(currencyCode: event.currencyCode, hasChanged: true));
  }

  /// Writes the newly picked page format to the project, then reflects it in the state.
  Future<void> _onPageFormatChanged(
    OcptProjectSettingsPageFormatChangedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    await _projectsManager.saveCurrentProjectPageFormat(event.pageFormat);
    emitter(state.copyWith(pageFormat: event.pageFormat, hasChanged: true));
  }

  /// Writes the newly committed minimum rest to the project, then reflects it in the state.
  ///
  /// `hasChanged` is set here exactly as every other field of this page sets it: the schedule
  /// mode's own re-read of this figure (`OcptScheduleProjectSettingsChangedEvent`, fired when this
  /// page pops with it true) depends on that, not on a special case for this one field.
  Future<void> _onMinimumRestMinutesChanged(
    OcptProjectSettingsMinimumRestMinutesChangedEvent event,
    Emitter<OcptProjectSettingsState> emitter,
  ) async {
    await _projectsManager.saveCurrentProjectMinimumRestMinutes(event.minutes);
    emitter(
      state.copyWith(
        minimumRestMinutes: event.minutes,
        clearMinimumRestMinutes: event.minutes == null,
        hasChanged: true,
      ),
    );
  }
}

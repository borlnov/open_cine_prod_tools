// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_file_transfer_manager/act_file_transfer_manager.dart';
import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_intl/act_intl.dart';
import 'package:act_licenses_manager/act_licenses_manager.dart';
import 'package:act_logger_manager/act_logger_manager.dart';
import 'package:act_platform_manager/act_platform_manager.dart';
import 'package:act_themes_manager/act_themes_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:open_cine_prod_tools/generated/l10n.dart';
import 'package:open_cine_prod_tools/managers/export/ocpt_export_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_config_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_diagnostics_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_router_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_secrets_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_spell_check_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_relay_host_manager.dart';
import 'package:open_cine_prod_tools/managers/sync/ocpt_sync_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_app_theme.dart';
import 'package:open_cine_prod_tools/ui/pages/fatal_error_page.dart';

/// Owns every manager registered in the app and drives their life cycle.
class OcptGlobalManager extends AbsUiGlobalManager {
  /// Returns the singleton instance, creating it on first access.
  static OcptGlobalManager get instance {
    if (AbsGlobalManager.instance == null) {
      AbsGlobalManager.setInstance = OcptGlobalManager._create();
    }

    return AbsGlobalManager.instance! as OcptGlobalManager;
  }

  /// Creates the singleton instance.
  OcptGlobalManager._create() : super.create();

  /// {@macro act_global_manager.AbsGlobalManager.registerManagers}
  @override
  Future<void> registerManagers() async {
    registerManagerAsync<OcptConfigManager>(const OcptConfigManagerBuilder());
    registerManagerAsync<PlatformManager>(const PlatformBuilder());
    registerManagerAsync<LoggerManager>(ExtDefaultLoggerBuilder<OcptConfigManager>());
    registerManagerAsync<OcptDiagnosticsManager>(const OcptDiagnosticsManagerBuilder());
    registerManagerAsync<ActLicensesManager>(ActLicensesBuilder<OcptConfigManager>());
    registerManagerAsync<OcptPropertiesManager>(const OcptPropertiesManagerBuilder());
    registerManagerAsync<OcptSecretsManager>(OcptSecretsManagerBuilder());
    registerManagerAsync<LocalesManager>(
      LocalesManagerBuilder<OcptConfigManager, OcptPropertiesManager>(
        getSupportedLocales: () => Tr.delegate.supportedLocales,
      ),
    );
    registerManagerAsync<ActThemesManager>(
      ActThemesBuilder<OcptConfigManager, OcptPropertiesManager>(appThemes: OcptAppTheme.values),
    );
    registerManagerAsync<FileSaverManager>(const FileSaverBuilder());
    registerManagerAsync<FileSelectorManager>(const FileSelectorBuilder());
    registerManagerAsync<OcptProjectsManager>(const OcptProjectsManagerBuilder());
    registerManagerAsync<OcptSyncManager>(const OcptSyncManagerBuilder());
    registerManagerAsync<OcptRelayHostManager>(const OcptRelayHostManagerBuilder());
    registerManagerAsync<OcptExportManager>(const OcptExportManagerBuilder());
    registerManagerAsync<OcptSpellCheckManager>(const OcptSpellCheckManagerBuilder());
    registerManagerAsync<OcptRouterManager>(const OcptRouterManagerBuilder());
  }

  /// {@macro act_global_manager.MixinUiGlobalManager.buildFatalErrorPage}
  @override
  Widget? buildFatalErrorPage(Object error) => FatalErrorPage(error: error);
}

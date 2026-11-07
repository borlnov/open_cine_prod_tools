// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:fountain_kit/fountain_kit.dart';
import 'package:meta/meta.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';
import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/models/ocpt_open_project_model.dart';
import 'package:open_cine_prod_tools/models/ocpt_page_setup.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';

/// Read the page setup [project] is typeset with: the open project's own page format, paired with
/// the app-wide margins preference, as the screenplay editor's own bloc pairs them.
///
/// A version being previewed is laid out with the setup it was written against instead, which
/// travels on the open project model and is never written anywhere.
///
/// Answers the failure of the read of the page format as it came; a project that records no format
/// reads as US Letter.
@useResult
Future<OcptDatabaseResult<OcptPageSetup>> ocptLoadPageSetup({
  required OcptOpenProjectModel project,
  required OcptProjectsManager projectsManager,
  required OcptPropertiesManager propertiesManager,
}) async {
  final previewedPageSetup = project.previewedPageSetup;
  if (previewedPageSetup != null) {
    return OcptDatabaseResult(status: OcptDatabaseStatus.ok, value: previewedPageSetup);
  }

  final formatRead = await projectsManager.loadCurrentProjectPageFormat();
  if (formatRead.isError) {
    return OcptDatabaseResult(status: formatRead.status, extraInfo: formatRead.extraInfo);
  }

  return OcptDatabaseResult(
    status: OcptDatabaseStatus.ok,
    value: OcptPageSetup(
      format: formatRead.value ?? OcptPageFormat.usLetter,
      margins: await propertiesManager.pageMargins.load() ?? const FountainPageMargins.standard(),
    ),
  );
}

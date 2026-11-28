// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

// The one file allowed to import flutter_localizations, see test/material_ui_import_test.dart.
import 'package:flutter_localizations/flutter_localizations.dart' as framework;
import 'package:material_ui/material_ui.dart';

/// The localisation delegates of the design libraries, which every app root installs beside
/// `Tr.delegate`.
///
/// They are those of `material_ui` and `cupertino_ui` (with the widgets ones), plus the framework's
/// own Material localisations: super_editor still builds its Android toolbar from the framework's
/// Material, which asks for the framework's `MaterialLocalizations`, a type distinct from the one
/// `material_ui` provides, and throws when none is installed.
const List<LocalizationsDelegate<dynamic>> ocptDesignLocalizationsDelegates = [
  ...GlobalMaterialLocalizations.delegates,
  framework.GlobalMaterialLocalizations.delegate,
];

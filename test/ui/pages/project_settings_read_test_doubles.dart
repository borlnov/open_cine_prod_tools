// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:open_cine_prod_tools/managers/projects/ocpt_projects_manager.dart';
import 'package:open_cine_prod_tools/types/ocpt_database_status.dart';
import 'package:open_cine_prod_tools/types/ocpt_page_format.dart';
import 'package:open_cine_prod_tools/types/ocpt_screenplay_language.dart';

/// A projects manager that refuses the reads of the settings it is told to, and reads the others
/// as the real one does.
class RefusingSettingsProjectsManager extends OcptProjectsManager {
  /// The names of the settings whose read is refused: `pageFormat`, `currency`, `minimumRest`,
  /// `language`, `vatRate`, `mealPrice` and `buffetPrice`.
  final refused = <String>{};

  /// Class constructor
  RefusingSettingsProjectsManager({required super.propertiesManager})
    : super(appLanguageCode: () => "en");

  /// Answer the failure of a read that is refused.
  OcptDatabaseResult<T> failure<T>() => const OcptDatabaseResult(
    status: OcptDatabaseStatus.databaseError,
    extraInfo: "setting intentionally refused for the test",
  );

  /// Refuse the read when [name] is refused, otherwise do [read].
  Future<OcptDatabaseResult<T>> readUnlessRefused<T>(
    String name,
    Future<OcptDatabaseResult<T>> Function() read,
  ) async => refused.contains(name) ? failure<T>() : read();

  /// Refuse the read of the page format when told to.
  @override
  Future<OcptDatabaseResult<OcptPageFormat>> loadCurrentProjectPageFormat() =>
      readUnlessRefused("pageFormat", super.loadCurrentProjectPageFormat);

  /// Refuse the read of the currency when told to.
  @override
  Future<OcptDatabaseResult<String>> loadCurrentProjectCurrencyCode() =>
      readUnlessRefused("currency", super.loadCurrentProjectCurrencyCode);

  /// Refuse the read of the minimum rest when told to.
  @override
  Future<OcptDatabaseResult<int>> loadCurrentProjectMinimumRestMinutes() =>
      readUnlessRefused("minimumRest", super.loadCurrentProjectMinimumRestMinutes);

  /// Refuse the read of the screenplay language when told to.
  @override
  Future<OcptDatabaseResult<OcptScreenplayLanguage>> loadCurrentProjectScreenplayLanguage() =>
      readUnlessRefused("language", super.loadCurrentProjectScreenplayLanguage);

  /// Refuse the read of the default VAT rate when told to.
  @override
  Future<OcptDatabaseResult<int>> loadCurrentProjectDefaultVatRateBasisPoints() =>
      readUnlessRefused("vatRate", super.loadCurrentProjectDefaultVatRateBasisPoints);

  /// Refuse the read of the meal price when told to.
  @override
  Future<OcptDatabaseResult<int>> loadCurrentProjectMealPriceCents() =>
      readUnlessRefused("mealPrice", super.loadCurrentProjectMealPriceCents);

  /// Refuse the read of the buffet price when told to.
  @override
  Future<OcptDatabaseResult<int>> loadCurrentProjectSnackPriceCents() =>
      readUnlessRefused("buffetPrice", super.loadCurrentProjectSnackPriceCents);
}

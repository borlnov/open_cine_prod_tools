// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:act_global_manager/act_global_manager.dart';
import 'package:act_local_storage_manager/act_local_storage_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_config_manager.dart';
import 'package:open_cine_prod_tools/managers/ocpt_properties_manager.dart';

/// Builds the [OcptSecretsManager] instance registered by the global manager.
class OcptSecretsManagerBuilder
    extends AbstractSecretsBuilder<OcptPropertiesManager, OcptConfigManager, OcptSecretsManager> {
  /// Class constructor
  OcptSecretsManagerBuilder()
    : super(
        () => OcptSecretsManager(
          propertiesGetter: () => globalGetIt().get<OcptPropertiesManager>(),
          confGetter: () => globalGetIt().get<OcptConfigManager>(),
        ),
      );
}

/// The app's own confidential-data storage, wrapping `act_local_storage_manager`'s
/// [AbstractSecretsManager] (itself wrapping `flutter_secure_storage`).
///
/// The one secret this app stores today is a project's relay pairing token
/// (`docs/plans/relay.md`, M4, Phase B) — never the relay base URL, which is not a secret and lives
/// in `sync_pairings` instead, nor the enrolment secret, which is a create-time-only value used
/// once by the transport and never persisted at all. A device can pair more than one project with a
/// relay over its lifetime, so [loadProjectToken], [saveProjectToken] and [deleteProjectToken] all
/// key the token by the project id rather than exposing a single fixed secret.
class OcptSecretsManager extends AbstractSecretsManager {
  /// Class constructor
  OcptSecretsManager({required super.propertiesGetter, required super.confGetter});

  /// The project token stored for [projectId], or null when none has ever been stored — the state
  /// the pairing service treats as "not paired" (see `OcptPairingService`'s own doc comment).
  Future<String?> loadProjectToken(String projectId) =>
      SecretItem<String>(_projectTokenKey(projectId)).load();

  /// Stores [token] as the project token for [projectId], replacing whatever was stored before.
  Future<void> saveProjectToken({required String projectId, required String token}) async {
    await SecretItem<String>(_projectTokenKey(projectId)).store(token);
  }

  /// Deletes the project token stored for [projectId], if any.
  Future<void> deleteProjectToken(String projectId) =>
      SecretItem<String>(_projectTokenKey(projectId)).delete();

  /// The secure-storage key [projectId]'s own token is stored under.
  static String _projectTokenKey(String projectId) => 'PROJECT_TOKEN_$projectId';
}

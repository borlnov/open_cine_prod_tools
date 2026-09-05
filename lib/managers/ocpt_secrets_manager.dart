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
/// This app stores two secrets today. A project's relay pairing token
/// (`docs/plans/relay.md`, M4, Phase B) — never the relay base URL, which is not a secret and lives
/// in `sync_pairings` instead, nor the enrolment secret a joiner presents once, which is a
/// create-time-only value used by the transport and never persisted at all. A device can pair more
/// than one project with a relay over its lifetime, so [loadProjectToken], [saveProjectToken] and
/// [deleteProjectToken] all key the token by the project id rather than exposing a single fixed
/// secret. The second is a project's own **hosting enrolment secret** (`OcptRelayHostManager`): a
/// stable per-project value minted once so the "Héberger sur ce poste" enrolment QR stays the same
/// across restarts; it grants project creation on the hosted relay, so it lives in secure storage
/// here, never in the `.ocpt`.
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

  /// The hosting enrolment secret stored for [projectId], or null when none has ever been minted —
  /// the state `OcptRelayHostManager.startHosting` treats as "mint one now".
  Future<String?> loadHostingEnrolmentSecret(String projectId) =>
      SecretItem<String>(_hostingEnrolmentSecretKey(projectId)).load();

  /// Stores [secret] as the hosting enrolment secret for [projectId], replacing whatever was
  /// stored before.
  Future<void> saveHostingEnrolmentSecret({required String projectId, required String secret}) async {
    await SecretItem<String>(_hostingEnrolmentSecretKey(projectId)).store(secret);
  }

  /// The secure-storage key [projectId]'s own token is stored under.
  static String _projectTokenKey(String projectId) => 'PROJECT_TOKEN_$projectId';

  /// The secure-storage key [projectId]'s own hosting enrolment secret is stored under.
  static String _hostingEnrolmentSecretKey(String projectId) => 'HOSTING_ENROLMENT_SECRET_$projectId';
}

// SPDX-FileCopyrightText: 2025 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: MIT

import 'package:bro_firebase_core/bro_firebase_core.dart';
import 'package:open_cine_prod_tools/generated/firebase_options.dart';

/// Builder of the [FirebaseManager] class
class FirebaseManagerBuilder extends AbsFirebaseBuilder<FirebaseManager> {
  /// Class constructor
  const FirebaseManagerBuilder() : super();

  /// {@macro bro_abstract_manager.AbsManagerBuilder.create}
  @override
  FirebaseManager create() => FirebaseManager();

  /// {@macro bro_abstract_manager.AbsManagerBuilder.getDependencies}
  @override
  Iterable<Type> getDependencies() => [];
}

/// This is the firebase manager of the app
class FirebaseManager extends AbsFirebaseManager {
  /// {@macro abs_firebase_manager.AbsFirebaseManager.getFirebaseOptions}
  @override
  Future<InitFirebaseConfig> getFirebaseOptions() async => InitFirebaseConfig(
        firebaseOptions: DefaultFirebaseOptions.currentPlatform,
      );
}

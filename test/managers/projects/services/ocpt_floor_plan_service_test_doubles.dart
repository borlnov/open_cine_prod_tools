// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';

/// The fixed device id every stamp this file's writes carry.
const deviceId = "device-1";

/// The device id provider the services under test are built with, answering [deviceId].
Future<String> testDeviceId() async => deviceId;

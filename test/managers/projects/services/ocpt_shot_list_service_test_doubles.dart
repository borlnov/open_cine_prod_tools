// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:fountain_kit/fountain_kit.dart';

/// Parses [source] with the real Fountain parser, so scene reconciliation is exercised against a
/// realistic document rather than a hand-built one.
FountainDocument parse(String source) => const FountainParser().parse(source);

/// The fixed device id every stamp this file's writes carry, so a stamping assertion can compare
/// against a known value rather than whatever `OcptPropertiesManager` would otherwise mint.
const deviceId = "device-1";

/// The device id provider the services under test are built with, answering [deviceId].
Future<String> testDeviceId() async => deviceId;

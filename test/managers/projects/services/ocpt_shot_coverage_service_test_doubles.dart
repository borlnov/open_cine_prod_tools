// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_cine_prod_tools/managers/projects/services/ocpt_shot_coverage_service.dart';

/// The digest [OcptShotCoverageService] is expected to compute for [text].
String testDigestOf(String text) => sha256.convert(utf8.encode(text)).toString();

/// The fixed device id every stamp this file's writes carry.
const deviceId = "device-1";

/// The device id provider the services under test are built with, answering [deviceId].
Future<String> testDeviceId() async => deviceId;

<!--
SPDX-FileCopyrightText: 2026 Benoit Rolandeau <benoit.rolandeau@allcircuits.com>

SPDX-License-Identifier: LicenseRef-ALLCircuits-ACT-1.1
-->

# ACT FFI Utility  <!-- omit from toc -->

## Table of contents

- [Table of contents](#table-of-contents)
- [Presentation](#presentation)
- [Getting started](#getting-started)

## Presentation

Contains useful elements for FFI bindings such as common types, utilities, etc.

## Getting started

This package is used by flutter applications to communicate with runtime libraries. We also use
it to generate the FFI bindings for the runtime library.

To generate the FFI bindings for the runtime library, follow the instructions in
[ffigen's documentation](https://pub.dev/packages/ffigen).

You will have to create a `ffigen.dart` file in the `<app-root>/tool` folder of your flutter
application.

We advise you to generate the runtime bindings classes in the `lib/generated/runtime` folder of your
flutter application. The `generated` folder is a common convention to indicate that the content of
the folder is generated and should not be manually edited. Moreover, the folder isn't added to
version control.

You have to verify that the CI you use will call the `ffigen` command to generate the bindings
before building the flutter application.

```shell
dart run tool/ffigen.dart
```

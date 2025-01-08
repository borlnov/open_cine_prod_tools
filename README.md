<!--
SPDX-FileCopyrightText: 2024 Benoit Rolandeau <borlnov.obsessio@gmail.com>

SPDX-License-Identifier: MIT
-->

# Open Source Cinema Production Tools <!-- omit from toc -->

## Table of contents

- [Table of contents](#table-of-contents)
- [Introduction](#introduction)
- [Platforms](#platforms)
- [Quick start](#quick-start)
  - [Firebase](#firebase)
    - [Introduction](#introduction-1)
    - [Install firebase tools](#install-firebase-tools)
    - [Configure the firebase project](#configure-the-firebase-project)

## Introduction

This is the HMI part of the "Open Source Cinema Production Tools" application.

## Platforms

The application should be available on the following platforms:

| Platform | Is it planned to work on?                                    | Is it tested?                          |
| -------- | ------------------------------------------------------------ | -------------------------------------- |
| Android  | ✅ Yes                                                        | ✅ Yes                                  |
| iOS      | ✅ Yes (_only in a second time, if I find some testers_)      | ❌ No (_I haven't an iPhone to test_)   |
| Linux    | ✅ Yes                                                        | ❌ No (_I don't have the time for now_) |
| macOS    | ✅ Yes (_only in a second time, if I find some testers_)      | ❌ No (_I haven't a mac to test_)       |
| Web      | ❌ No (_I don't know how to developp on Flutter Web for now_) | ❌ No                                   |
| Windows  | ✅ Yes                                                        | ✅ Yes                                  |

## Quick start

### Firebase

#### Introduction

This application uses firebase, so you need to create a firebase project. You can follow the doc
here: [create a firebase project](https://firebase.google.com/docs/flutter/setup#create-firebase-project).

We don't add the firebase configuration file in the repository because if you want to rebuild the
application for you, you need to create your own firebase project.

#### Install firebase tools

This application uses firebase, so you need to install the firebase tools:

- `firebase`
- `flutterfire_cli`

You can follow the doc here:
[install tools](https://firebase.google.com/docs/flutter/setup?hl=fr&platform=android#install-cli-tools).

#### Configure the firebase project

After having installed the firebase tools and login to your account, you need to configure the
firebase project.

We export the `firebase_options.dart` file to the `lib/generated` directory, because we don't want
to add this file in the repository. Therefore, each time you want to configure the project, you have
to call (_from the root folder of the project_):

```bash
flutterfire configure --out lib/generated/firebase_options.dart
```

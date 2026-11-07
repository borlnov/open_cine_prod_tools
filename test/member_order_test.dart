// SPDX-FileCopyrightText: 2026 Benoit Rolandeau <borlnov.obsessio@gmail.com>
//
// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:flutter_test/flutter_test.dart';

/// The names of the methods that release what an object holds, in the order they close a class.
const _releaseMethods = ["close", "dispose", "disposeLifeCycle"];

/// The place of [member] in the order a class reads in: public then private constants, other
/// statics, instance fields, getters and setters, constructors (the unnamed one, the named ones,
/// the factories), public then private methods, public then private static methods, the `props`
/// getter, then the release methods.
int _rankOf(ClassMember member) {
  if (member is FieldDeclaration) {
    final isPrivate = member.fields.variables.first.name.lexeme.startsWith("_");
    if (member.isStatic) {
      if (member.fields.isConst) {
        return isPrivate ? 1 : 0;
      }
      return isPrivate ? 3 : 2;
    }
    return isPrivate ? 5 : 4;
  }

  if (member is ConstructorDeclaration) {
    if (member.name == null) {
      return 8;
    }
    return member.factoryKeyword != null ? 10 : 9;
  }

  if (member is MethodDeclaration) {
    final name = member.name.lexeme;
    final isPrivate = name.startsWith("_");
    if (member.isGetter || member.isSetter) {
      if (!member.isStatic && member.isGetter && name == "props") {
        return 15;
      }
      return isPrivate ? 7 : 6;
    }
    if (!member.isStatic && _releaseMethods.contains(name)) {
      return 16 + _releaseMethods.indexOf(name);
    }
    if (member.isStatic) {
      return isPrivate ? 14 : 13;
    }
    return isPrivate ? 12 : 11;
  }

  return 11;
}

/// A readable name for [member], for the failure message.
String _nameOf(ClassMember member) {
  if (member is FieldDeclaration) {
    return member.fields.variables.first.name.lexeme;
  }
  if (member is ConstructorDeclaration) {
    return "${member.typeName?.name}${member.name == null ? "" : ".${member.name!.lexeme}"}";
  }
  if (member is MethodDeclaration) {
    return member.name.lexeme;
  }
  return member.runtimeType.toString();
}

/// Lists the members of every class, mixin, enum and extension of a unit.
class _MemberLists {
  /// The members of each container, named after it.
  final containers = <String, List<ClassMember>>{};

  /// Collects the members of [unit]'s containers.
  _MemberLists(CompilationUnit unit) {
    for (final declaration in unit.declarations) {
      switch (declaration) {
        case ClassDeclaration(:final namePart, :final body) when body is BlockClassBody:
          containers[namePart.typeName.lexeme] = body.members;
        case MixinDeclaration(:final name, :final body):
          containers[name.lexeme] = body.members;
        case ExtensionDeclaration(:final name, :final body):
          containers[name?.lexeme ?? "<unnamed extension>"] = body.members;
        case ExtensionTypeDeclaration(:final primaryConstructor, :final body)
            when body is BlockClassBody:
          containers[primaryConstructor.typeName.lexeme] = body.members;
        case EnumDeclaration(:final namePart, :final body):
          containers[namePart.typeName.lexeme] = body.members;
        default:
      }
    }
  }
}

/// Members read in a fixed order: the constants, the statics, the fields, the accessors, the
/// constructors, the methods, then `props` and the methods releasing the object's resources, so
/// that a reader knows where to look for what a class holds. A member overridden takes the place
/// of its kind, and an enum's values stay first.
///
/// This parses every Dart file of the app, of the tests, of the tools and of each package, and
/// fails on a member that comes after one of a later kind, naming it.
void main() {
  final roots = [
    Directory("lib"),
    Directory("test"),
    Directory("tool"),
    for (final package in Directory("packages").listSync().whereType<Directory>())
      for (final folder in ["lib", "test", "bin"]) Directory("${package.path}/$folder"),
  ].where((directory) => directory.existsSync());

  final files = [
    for (final root in roots)
      ...root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith(".dart") && !file.path.endsWith(".g.dart"))
          .where((file) => !file.path.contains("/generated/")),
  ]..sort((a, b) => a.path.compareTo(b.path));

  // One test per folder: the first two segments of a path, as "lib/ui" or "packages/spell_kit".
  final folders = <String, List<File>>{};
  for (final file in files) {
    final segments = file.path.split("/");
    final key = segments.length > 2 ? segments.take(2).join("/") : segments.first;
    folders.putIfAbsent(key, () => []).add(file);
  }

  test("the sources were found", () {
    expect(files, isNotEmpty);
  });

  folders.forEach((folder, folderFiles) {
    test("$folder declares its class members in kind order", () {
      final offences = <String>[];
      for (final file in folderFiles) {
        final parsed = parseFile(
          path: file.absolute.path,
          featureSet: FeatureSet.latestLanguageVersion(),
        );
        _MemberLists(parsed.unit).containers.forEach((container, members) {
          for (var i = 1; i < members.length; i++) {
            if (_rankOf(members[i]) < _rankOf(members[i - 1])) {
              final line = parsed.lineInfo.getLocation(
                members[i].firstTokenAfterCommentAndMetadata.offset,
              );
              offences.add(
                "${file.path}:${line.lineNumber} $container.${_nameOf(members[i])} comes after "
                "${_nameOf(members[i - 1])}",
              );
            }
          }
        });
      }

      expect(
        offences,
        isEmpty,
        reason:
            "Members go in this order: public then private static constants, other statics, "
            "instance fields, getters and setters, constructors, public then private methods, "
            "public then private static methods, props, then close, dispose and disposeLifeCycle.",
      );
    });
  });
}

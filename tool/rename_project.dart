// tool/rename_project.dart
//
// Renames the root app package (`flutter_agentic_template`, the composition
// root — see AGENTS.md section 1) to a new Dart package name.
//
// Usage:
//   fvm dart run tool/rename_project.dart --name new_package_name [--dry-run]
//
// This is step 1 of `.agents/skills/bootstrap-project/SKILL.md`, meant to be
// run exactly once, immediately after cloning the template. It rewrites:
//   - The root `pubspec.yaml`'s top-level `name:` field.
//   - Every `import 'package:flutter_agentic_template/...'` under the root
//     `lib/` and `test/` directories, to `import 'package:new_package_name/...'`.
//
// `packages/domain`, `packages/data` and `packages/ui` are deliberately NOT
// touched — their names are generic on purpose and are never renamed.
//
// `--dry-run` prints exactly what would change without writing anything, so
// you can review the plan before committing to it.
//
// What this script does NOT do (see the reminder it prints at the end, and
// `.agents/skills/bootstrap-project/SKILL.md` steps 3-6): the Android
// `applicationId`/`namespace` (`android/app/build.gradle.kts`), the iOS
// bundle id (`ios/Runner.xcodeproj/project.pbxproj`) and its flavor suffix/
// display name (`ios/Flutter/flavor-dev.xcconfig`,
// `ios/Flutter/flavor-prod.xcconfig`), and the app's display name in
// `packages/ui/lib/l10n/app_en.arb` / `app_es.arb` (`appTitle` key) all need
// hand edits — those files are easy for tooling to corrupt silently, so the
// skill has you do them by hand and verify with `grep` after each edit.

import 'dart:io';

/// A valid Dart package name: lowercase letters, digits and underscores,
/// starting with a lowercase letter. See
/// https://dart.dev/tools/pub/pubspec#name.
final RegExp _validPackageName = RegExp(r'^[a-z][a-z0-9_]*$');

/// Matches the top-level `name:` field in a pubspec.yaml (anchored to the
/// start of a line so a nested `name:` under `flutter_launcher_icons:` or
/// similar is never touched).
final RegExp _pubspecNamePattern = RegExp(r'^name:\s*(\S+)\s*$', multiLine: true);

/// The two root directories whose `.dart` files may reference the app
/// package by name. `packages/*` is intentionally excluded — those packages
/// keep their own fixed names.
const List<String> _scannedDirs = ['lib', 'test'];

void main(List<String> args) {
  final options = _Options.parse(args);
  if (options == null) {
    exit(1);
  }

  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr
      ..writeln('error: pubspec.yaml not found in the current directory.')
      ..writeln('Run this script from the repo root (fvm dart run tool/rename_project.dart ...).');
    exit(1);
  }

  final pubspecContent = pubspecFile.readAsStringSync();
  final oldName = currentPackageName(pubspecContent);
  if (oldName == null) {
    stderr.writeln("error: could not find a top-level 'name:' field in pubspec.yaml.");
    exit(1);
  }

  if (oldName == options.newName) {
    stdout.writeln("Nothing to do: the package is already named '${options.newName}'.");
    return;
  }

  final modePrefix = options.dryRun ? '[dry run] ' : '';
  stdout
    ..writeln("${modePrefix}Renaming package '$oldName' -> '${options.newName}'")
    ..writeln();

  // --- pubspec.yaml ---------------------------------------------------
  final newPubspecContent = replacePackageName(pubspecContent, options.newName);
  if (options.dryRun) {
    stdout.writeln('Would update pubspec.yaml: name: $oldName -> name: ${options.newName}');
  } else {
    pubspecFile.writeAsStringSync(newPubspecContent);
    stdout.writeln('Updated pubspec.yaml: name: $oldName -> name: ${options.newName}');
  }

  // --- lib/ and test/ imports ------------------------------------------
  final changes = renameImportsInDartFiles(
    directories: _scannedDirs.map(Directory.new).toList(),
    oldName: oldName,
    newName: options.newName,
    dryRun: options.dryRun,
  );

  stdout.writeln();
  if (changes.isEmpty) {
    stdout.writeln("No 'package:$oldName/' imports found under lib/ or test/.");
  } else {
    final verb = options.dryRun ? 'Would change' : 'Changed';
    stdout.writeln('$verb ${changes.length} file(s):');
    for (final change in changes) {
      final plural = change.replacementCount == 1 ? '' : 's';
      stdout.writeln('  ${change.path} (${change.replacementCount} replacement$plural)');
    }
  }

  _printManualStepsReminder(options.newName);
}

/// Parsed and validated command-line options.
class _Options {
  const _Options({required this.newName, required this.dryRun});

  final String newName;
  final bool dryRun;

  /// Parses [args], printing usage/validation errors to stderr and
  /// returning `null` if [args] is invalid.
  static _Options? parse(List<String> args) {
    String? name;
    var dryRun = false;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--dry-run') {
        dryRun = true;
      } else if (arg == '--name') {
        if (i + 1 >= args.length) {
          stderr.writeln('error: --name requires a value.');
          _printUsage();
          return null;
        }
        name = args[++i];
      } else if (arg.startsWith('--name=')) {
        name = arg.substring('--name='.length);
      } else {
        stderr.writeln("error: unrecognized argument '$arg'.");
        _printUsage();
        return null;
      }
    }

    if (name == null || name.isEmpty) {
      stderr.writeln('error: --name is required.');
      _printUsage();
      return null;
    }

    if (!_validPackageName.hasMatch(name)) {
      stderr.writeln(
        "error: '$name' is not a valid Dart package name — it must be lowercase, "
        'start with a letter, and contain only letters, digits and underscores '
        '(e.g. my_new_app).',
      );
      return null;
    }

    return _Options(newName: name, dryRun: dryRun);
  }

  static void _printUsage() {
    stderr.writeln(
      'Usage: fvm dart run tool/rename_project.dart --name new_package_name [--dry-run]',
    );
  }
}

/// Extracts the current top-level `name:` field from a pubspec.yaml's raw
/// [content], or `null` if none is found. A simple string search is enough
/// here — no YAML parser is needed for a single scalar field.
String? currentPackageName(String content) {
  final match = _pubspecNamePattern.firstMatch(content);
  if (match == null) return null;
  return match.group(1)!.trim();
}

/// Returns [content] with its top-level `name:` field's value replaced by
/// [newName], leaving every other line untouched.
String replacePackageName(String content, String newName) {
  return content.replaceFirstMapped(_pubspecNamePattern, (match) => 'name: $newName');
}

/// One file whose `package:$oldName/` imports were rewritten (or, in
/// `--dry-run` mode, would be rewritten).
class FileChange {
  const FileChange({required this.path, required this.replacementCount});

  final String path;
  final int replacementCount;
}

/// Recursively rewrites every `import 'package:$oldName/...'` (and any
/// other `package:$oldName/` reference, e.g. in an `export`) under each of
/// [directories] to `package:$newName/`. Returns one [FileChange] per file
/// that contained at least one match, sorted by path for deterministic
/// output. Nothing is written to disk when [dryRun] is `true`.
List<FileChange> renameImportsInDartFiles({
  required List<Directory> directories,
  required String oldName,
  required String newName,
  required bool dryRun,
}) {
  final oldImportPrefix = 'package:$oldName/';
  final newImportPrefix = 'package:$newName/';
  final changes = <FileChange>[];

  final files = <File>[];
  for (final dir in directories) {
    if (!dir.existsSync()) continue;
    files.addAll(
      dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')),
    );
  }
  files.sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final content = file.readAsStringSync();
    final replacementCount = oldImportPrefix.allMatches(content).length;
    if (replacementCount == 0) continue;

    if (!dryRun) {
      file.writeAsStringSync(content.replaceAll(oldImportPrefix, newImportPrefix));
    }
    changes.add(FileChange(path: file.path, replacementCount: replacementCount));
  }

  return changes;
}

void _printManualStepsReminder(String newName) {
  final divider = '-' * 78;
  stdout
    ..writeln()
    ..writeln(divider)
    ..writeln('This script does NOT touch the following — edit them by hand, then verify')
    ..writeln('with grep (see .agents/skills/bootstrap-project/SKILL.md steps 3-5):')
    ..writeln('  - Android applicationId/namespace: android/app/build.gradle.kts')
    ..writeln('  - iOS bundle id: ios/Runner.xcodeproj/project.pbxproj')
    ..writeln('  - iOS flavor suffix/display name: ios/Flutter/flavor-dev.xcconfig,')
    ..writeln('    ios/Flutter/flavor-prod.xcconfig')
    ..writeln('  - App display name: packages/ui/lib/l10n/app_en.arb and app_es.arb')
    ..writeln("    ('appTitle' key), plus the Android/iOS display-name strings above.")
    ..writeln(divider)
    ..writeln('After the manual steps: fvm flutter pub get && fvm dart run tool/quality_gate.dart');
}

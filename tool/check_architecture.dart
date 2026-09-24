// tool/check_architecture.dart
//
// Enforces this repo's Clean Architecture boundaries (AGENTS.md sections 2,
// 13 and 20) with plain line-based regex scanning of `import` statements —
// deliberately no `package:analyzer` dependency, so this script has zero
// pubspec footprint and stays fast to run as part of every quality gate.
//
// Usage:
//   fvm dart run tool/check_architecture.dart
//
// What it checks, walking `lib/`, `packages/domain/lib/`, `packages/data/lib/`
// and `packages/ui/lib/` (skipping `test/`, `build/`, `*.g.dart` and the
// generated `packages/ui/lib/src/l10n/app_localizations*.dart` files):
//   1. `packages/domain` never imports `flutter`, `dart:ui`, `dart:io`,
//      `package:data` or `package:ui` — domain is pure Dart and innermost.
//   2. `packages/data` never imports `flutter` or `package:ui`.
//   3. `packages/ui` never imports `package:data` — the one absolute rule.
//   4. No file anywhere imports `package:get_it` or `package:injectable`
//      (forbidden service locators — manual constructor injection only).
//   5. No file reaches into another package's `src/` directly (e.g.
//      `package:domain/src/entities/task.dart` from `packages/ui` or from
//      the app root) instead of going through that package's public barrel
//      (`package:domain/domain.dart`). A file importing its own package's
//      `src/` via a `package:` URI is not this rule's concern — within a
//      package, imports should be relative, but a relative import can never
//      literally cross a package boundary, so there is nothing further to
//      detect there; see AGENTS.md section 13.
//
// Exit code: 0 if clean, 1 if any violation is found. This script is one
// step of `tool/quality_gate.dart` (AGENTS.md section 17).

import 'dart:io';

/// Which layer/package a `.dart` file belongs to, based on its path. `root`
/// is the composition root (`lib/`), which is allowed to import all three
/// packages and is only checked against the repo-wide rules (4 and 5).
enum PackageKind { domain, data, ui, root }

/// A single reported problem: where it was found and what to fix.
class Violation {
  const Violation({
    required this.filePath,
    required this.line,
    required this.message,
    required this.section,
  });

  final String filePath;
  final int line;
  final String message;
  final int section;

  @override
  String toString() => '$filePath:$line: $message — see AGENTS.md section $section';
}

/// Directories (relative to the repo root) this checker walks, keyed by the
/// [PackageKind] every `.dart` file found underneath belongs to.
const Map<String, PackageKind> _walkedDirs = {
  'lib': PackageKind.root,
  'packages/domain/lib': PackageKind.domain,
  'packages/data/lib': PackageKind.data,
  'packages/ui/lib': PackageKind.ui,
};

/// Matches an `import` directive and captures its URI. Combinators
/// (`show`/`hide`) or an `as` clause may follow on the same or a wrapped
/// line, but the quoted URI itself always sits on the `import` line.
final RegExp _importPattern = RegExp(r'''^\s*import\s+['"]([^'"]+)['"]''');

/// Matches a `package:` import that reaches directly into a package's
/// `src/` directory, e.g. `package:domain/src/entities/task.dart`.
final RegExp _srcImportPattern = RegExp('^package:(domain|data|ui)/src/');

/// Base import URIs (without a trailing slash) `packages/domain` may never
/// import. Matched as an exact URI or as a `$base/...` prefix, so
/// `package:flutter` does not falsely match `package:flutter_bloc`.
const List<String> _domainForbidden = [
  'package:flutter',
  'dart:ui',
  'dart:io',
  'package:data',
  'package:ui',
];

/// Base import URIs `packages/data` may never import.
const List<String> _dataForbidden = ['package:flutter', 'package:ui'];

/// Base import URIs `packages/ui` may never import — the one absolute rule.
const List<String> _uiForbidden = ['package:data'];

/// Forbidden service-locator packages, banned in every layer.
const List<String> _serviceLocatorForbidden = ['package:get_it', 'package:injectable'];

void main(List<String> args) {
  final violations = checkArchitecture(Directory.current);
  // A cascade here (`violations..forEach(stdout.writeln)`) would still need
  // its own `final` binding for the `isEmpty` check below, so it wouldn't
  // actually remove a line — kept as two statements for readability.
  // ignore: cascade_invocations
  violations.forEach(stdout.writeln);

  if (violations.isEmpty) {
    stdout.writeln('Architecture check: passed');
    exit(0);
  } else {
    stdout.writeln('Architecture check: ${violations.length} violation(s) found');
    exit(1);
  }
}

/// Walks every configured directory under [repoRoot] and collects
/// violations across all `.dart` files found. This is the entry point
/// `main()` uses; tests instead call [analyzeFile] directly against
/// fixture source strings, or build a small directory tree under a temp
/// dir and call this function against it.
List<Violation> checkArchitecture(Directory repoRoot) {
  final violations = <Violation>[];

  for (final entry in _walkedDirs.entries) {
    final dir = Directory('${repoRoot.path}/${entry.key}');
    if (!dir.existsSync()) continue;

    for (final file in _dartFilesUnder(dir)) {
      final relativePath = _relativePath(repoRoot, file);
      if (_isSkipped(relativePath)) continue;

      final content = file.readAsStringSync();
      violations.addAll(analyzeFile(relativePath, content, entry.value));
    }
  }

  return violations;
}

/// Lists every `.dart` file recursively under [dir], sorted alphabetically
/// so output is deterministic across runs and across platforms.
List<File> _dartFilesUnder(Directory dir) {
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

/// Strips [repoRoot]'s path off [file], returning a forward-slash relative
/// path for readable, OS-independent output and pattern matching.
String _relativePath(Directory repoRoot, File file) {
  // Search pattern is a literal backslash (Windows path separator);
  // written as an escape, not a raw string, so it isn't misread as an
  // empty match.
  // ignore: use_raw_strings
  final rootPath = repoRoot.path.replaceAll('\\', '/');
  // Same reasoning as rootPath above.
  // ignore: use_raw_strings
  final filePath = file.path.replaceAll('\\', '/');
  if (filePath.startsWith('$rootPath/')) {
    return filePath.substring(rootPath.length + 1);
  }
  return filePath;
}

/// True for paths this checker deliberately ignores: tests, build output,
/// generated code (`*.g.dart`), and the generated localization files.
bool _isSkipped(String relativePath) {
  // Same reasoning as _relativePath above: a literal backslash search
  // pattern, kept as an escape rather than a raw string.
  // ignore: use_raw_strings
  final normalized = relativePath.replaceAll('\\', '/');
  if (normalized.startsWith('test/') || normalized.contains('/test/')) return true;
  if (normalized.startsWith('build/') || normalized.contains('/build/')) return true;
  if (normalized.endsWith('.g.dart')) return true;
  if (normalized.contains('packages/ui/lib/src/l10n/app_localizations') &&
      normalized.endsWith('.dart')) {
    return true;
  }
  return false;
}

/// Scans [content] (the source of the file at [relativePath], belonging to
/// [kind]) line by line for `import` statements and returns every
/// violation found. This is the core, filesystem-free unit the test suite
/// drives directly with fixture strings.
List<Violation> analyzeFile(String relativePath, String content, PackageKind kind) {
  final violations = <Violation>[];
  final lines = content.split('\n');

  for (var i = 0; i < lines.length; i++) {
    final match = _importPattern.firstMatch(lines[i]);
    if (match == null) continue;

    final importUri = match.group(1)!;
    final lineNumber = i + 1;

    final serviceLocatorViolation = _checkServiceLocator(relativePath, lineNumber, importUri);
    if (serviceLocatorViolation != null) violations.add(serviceLocatorViolation);

    final layerViolation = _checkLayerRule(relativePath, lineNumber, importUri, kind);
    if (layerViolation != null) violations.add(layerViolation);

    final srcReachInViolation = _checkSrcReachIn(relativePath, lineNumber, importUri, kind);
    if (srcReachInViolation != null) violations.add(srcReachInViolation);
  }

  return violations;
}

/// True if [importUri] is exactly [base] or sits under it (`$base/...`) —
/// avoids `package:flutter` falsely matching `package:flutter_bloc`.
bool _isOrUnder(String importUri, String base) {
  return importUri == base || importUri.startsWith('$base/');
}

Violation? _checkServiceLocator(String path, int line, String importUri) {
  for (final forbidden in _serviceLocatorForbidden) {
    if (_isOrUnder(importUri, forbidden)) {
      return Violation(
        filePath: path,
        line: line,
        message:
            "forbidden service locator import '$importUri' — this repo uses manual "
            'constructor injection only, wired in lib/bootstrap.dart',
        section: 20,
      );
    }
  }
  return null;
}

Violation? _checkLayerRule(String path, int line, String importUri, PackageKind kind) {
  switch (kind) {
    case PackageKind.domain:
      for (final forbidden in _domainForbidden) {
        if (_isOrUnder(importUri, forbidden)) {
          return Violation(
            filePath: path,
            line: line,
            message:
                "packages/domain must not import '$importUri' — domain is pure Dart "
                'with no Flutter, dart:io or data/ui dependency',
            section: 2,
          );
        }
      }
      return null;
    case PackageKind.data:
      for (final forbidden in _dataForbidden) {
        if (_isOrUnder(importUri, forbidden)) {
          return Violation(
            filePath: path,
            line: line,
            message:
                "packages/data must not import '$importUri' — data has no Flutter "
                'dependency and must never import ui',
            section: 2,
          );
        }
      }
      return null;
    case PackageKind.ui:
      for (final forbidden in _uiForbidden) {
        if (_isOrUnder(importUri, forbidden)) {
          return Violation(
            filePath: path,
            line: line,
            message:
                "packages/ui must not import '$importUri' — ui must never depend on "
                'data (the one absolute rule)',
            section: 2,
          );
        }
      }
      return null;
    case PackageKind.root:
      return null;
  }
}

Violation? _checkSrcReachIn(String path, int line, String importUri, PackageKind kind) {
  final match = _srcImportPattern.firstMatch(importUri);
  if (match == null) return null;

  final importedPackage = match.group(1)!;
  final owningPackage = kind == PackageKind.root ? null : kind.name;
  if (owningPackage == importedPackage) return null;

  return Violation(
    filePath: path,
    line: line,
    message:
        "import '$importUri' reaches into $importedPackage's src/ directly from "
        'outside that package — use its public barrel package:$importedPackage/'
        '$importedPackage.dart instead',
    section: 2,
  );
}

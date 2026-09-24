// tool/test/check_architecture_test.dart
//
// Fixture-based tests for `tool/check_architecture.dart`. This is a plain
// `package:test` suite (NOT `flutter_test`) — `check_architecture.dart` has
// no Flutter dependency, and `package:test` is already resolvable at the
// workspace root because `packages/domain` declares it as a `dev_dependency`
// and this repo is a single Dart pub workspace, so every member shares one
// resolved package graph.
//
// Run it with:
//   fvm dart test tool/test/check_architecture_test.dart
//
// Two styles of test are used:
//   - Direct calls to `analyzeFile` with fixture source strings — fast,
//     filesystem-free checks of the per-line import rules.
//   - A small on-disk fixture tree under a `Directory.systemTemp` temp dir,
//     exercised through `checkArchitecture`, to also prove the directory
//     walk, package-kind routing and skip rules work end to end.

import 'dart:io';

import 'package:test/test.dart';

import '../check_architecture.dart';

void main() {
  group('analyzeFile — domain', () {
    test('flags a domain file importing package:flutter', () {
      const content = "import 'package:flutter/material.dart';\n\nclass Foo {}\n";

      final violations = analyzeFile(
        'packages/domain/lib/src/entities/foo.dart',
        content,
        PackageKind.domain,
      );

      expect(violations, hasLength(1));
      expect(violations.single.line, 1);
      expect(violations.single.section, 2);
      expect(violations.single.message, contains('package:flutter/material.dart'));
    });

    test('does not flag a clean domain file', () {
      const content =
          "import 'package:equatable/equatable.dart';\n\n"
          "import '../failures/failures.dart';\n\n"
          'class Foo extends Equatable {}\n';

      final violations = analyzeFile(
        'packages/domain/lib/src/entities/foo.dart',
        content,
        PackageKind.domain,
      );

      expect(violations, isEmpty);
    });

    test('flags dart:io and dart:ui but not an unrelated dart: import', () {
      const content =
          "import 'dart:io';\n"
          "import 'dart:ui';\n"
          "import 'dart:async';\n";

      final violations = analyzeFile('packages/domain/lib/src/x.dart', content, PackageKind.domain);

      expect(violations, hasLength(2));
    });
  });

  group('analyzeFile — ui', () {
    test('flags a ui file importing package:data', () {
      const content = "import 'package:data/data.dart';\n\nclass FooCubit {}\n";

      final violations = analyzeFile(
        'packages/ui/lib/src/app_blocs/foo_cubit.dart',
        content,
        PackageKind.ui,
      );

      expect(violations, hasLength(1));
      expect(violations.single.section, 2);
      expect(violations.single.message, contains('ui must never depend on'));
    });

    test('does not flag a ui file importing package:domain', () {
      const content =
          "import 'package:domain/domain.dart';\n"
          "import 'package:flutter/material.dart';\n";

      final violations = analyzeFile(
        'packages/ui/lib/src/app_blocs/foo_cubit.dart',
        content,
        PackageKind.ui,
      );

      expect(violations, isEmpty);
    });
  });

  group('analyzeFile — service locators', () {
    test('flags an import of package:get_it anywhere, regardless of layer', () {
      const content = "import 'package:get_it/get_it.dart';\n";

      for (final kind in PackageKind.values) {
        final violations = analyzeFile('some/file.dart', content, kind);
        expect(violations, hasLength(1), reason: 'kind: $kind');
        expect(violations.single.section, 20);
      }
    });

    test('flags an import of package:injectable', () {
      const content = "import 'package:injectable/injectable.dart';\n";

      final violations = analyzeFile('packages/data/lib/src/x.dart', content, PackageKind.data);

      expect(violations, hasLength(1));
      expect(violations.single.section, 20);
    });
  });

  group('analyzeFile — clean file', () {
    test('a fully clean file reports no violations', () {
      const content =
          "import 'package:flutter/material.dart';\n"
          "import 'package:domain/domain.dart';\n\n"
          "import '../theme/theme.dart';\n\n"
          'class HomeScreen extends StatelessWidget {\n'
          '  @override\n'
          '  Widget build(BuildContext context) => const SizedBox();\n'
          '}\n';

      final violations = analyzeFile(
        'packages/ui/lib/src/features/home/presentation/home_screen.dart',
        content,
        PackageKind.ui,
      );

      expect(violations, isEmpty);
    });
  });

  group('analyzeFile — src reach-in', () {
    test('flags a ui file reaching into package:domain/src/ directly', () {
      const content = "import 'package:domain/src/entities/task.dart';\n";

      final violations = analyzeFile('packages/ui/lib/src/x.dart', content, PackageKind.ui);

      expect(violations, hasLength(1));
      expect(violations.single.message, contains("domain's src/"));
    });

    test('flags the app root reaching into package:data/src/ directly', () {
      const content = "import 'package:data/src/data_providers/data_providers.dart';\n";

      final violations = analyzeFile('lib/bootstrap.dart', content, PackageKind.root);

      expect(violations, hasLength(1));
    });

    test('does not flag a package:domain/domain.dart barrel import from ui', () {
      const content = "import 'package:domain/domain.dart';\n";

      final violations = analyzeFile('packages/ui/lib/src/x.dart', content, PackageKind.ui);

      expect(violations, isEmpty);
    });
  });

  group('checkArchitecture — on-disk fixture tree', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('check_architecture_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('walks packages/domain/lib and flags a flutter import', () {
      File('${tempDir.path}/packages/domain/lib/src/entities/foo.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync("import 'package:flutter/widgets.dart';\n");

      final violations = checkArchitecture(tempDir);

      expect(violations, hasLength(1));
      expect(violations.single.filePath, 'packages/domain/lib/src/entities/foo.dart');
    });

    test('walks packages/ui/lib and flags a data import', () {
      File('${tempDir.path}/packages/ui/lib/src/app_blocs/foo_cubit.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync("import 'package:data/data.dart';\n");

      final violations = checkArchitecture(tempDir);

      expect(violations, hasLength(1));
    });

    test('skips generated app_localizations files under packages/ui/lib/src/l10n', () {
      File('${tempDir.path}/packages/ui/lib/src/l10n/app_localizations_en.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          "import 'package:flutter/widgets.dart';\nimport 'package:data/data.dart';\n",
        );

      final violations = checkArchitecture(tempDir);

      expect(violations, isEmpty);
    });

    test('skips *.g.dart generated files', () {
      File('${tempDir.path}/packages/data/lib/src/models/foo.g.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync("import 'package:flutter/widgets.dart';\n");

      final violations = checkArchitecture(tempDir);

      expect(violations, isEmpty);
    });

    test('an entirely clean fixture tree reports no violations', () {
      File('${tempDir.path}/packages/domain/lib/src/entities/foo.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync("import 'package:equatable/equatable.dart';\n");

      File('${tempDir.path}/packages/ui/lib/src/app_blocs/foo_cubit.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          "import 'package:domain/domain.dart';\nimport 'package:flutter/material.dart';\n",
        );

      final violations = checkArchitecture(tempDir);

      expect(violations, isEmpty);
    });
  });
}

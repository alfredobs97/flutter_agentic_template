// tool/quality_gate.dart
//
// The single command that answers "is this change done" (AGENTS.md section
// 18, Definition of Done). Runs every check the repo cares about and prints
// one pass/fail summary at the end.
//
// Usage:
//   fvm dart run tool/quality_gate.dart [--skip-tests]
//
// --skip-tests skips step 5 (the full test suite) for faster local
// iteration while writing code — it must NOT be used before declaring a
// task done; the Definition of Done requires every step, including tests,
// to pass.
//
// Steps, run in this order, from the repo root:
//   1. fvm dart format -l 100 --output=none --set-exit-if-changed .
//   2. fvm flutter analyze --fatal-infos
//   3. fvm dart run tool/check_architecture.dart
//   4. fvm dart run tool/sync_ai_config.dart --check
//   5. Tests (skipped with --skip-tests):
//      - fvm dart test tool/test              (tool/*.dart's own test suite —
//                                               see the note below)
//      - fvm flutter test                     (repo root)
//      - fvm dart test                        (packages/domain — pure Dart)
//      - fvm flutter test                     (packages/data)
//      - fvm flutter test                     (packages/ui)
//
// `tool/test/` (fixture tests for tool/check_architecture.dart and
// tool/sync_ai_config.dart) is deliberately run here rather than relying on
// `fvm flutter test` at the repo root to find it — Flutter's test runner
// only discovers `test/`, not `tool/test/`, so without this explicit step
// those two scripts' own tests would never run as part of "is this change
// done", and could silently break with nothing catching it.
//
// Unlike a typical CI script that stops at the first red step, this one
// runs every step regardless of earlier failures and reports all of them
// together — the same contract `ai/agents/quality-guardian.yaml` asks that
// agent to follow: a caller gets one full picture of what is wrong in a
// single run, rather than fixing one failure only to discover the next one
// on the following run.
//
// Exit code: 0 only if every step passed; 1 if any step failed.

import 'dart:io';

/// The result of running one quality-gate step.
class _StepResult {
  const _StepResult({
    required this.name,
    required this.passed,
    required this.stdout,
    required this.stderr,
    required this.command,
  });

  final String name;
  final bool passed;
  final String stdout;
  final String stderr;

  /// The command line that was run, for display in a failure report.
  final String command;
}

/// One step to run: a human-readable [name], the [executable] and its
/// [arguments], and the [workingDirectory] it runs in (relative to the repo
/// root; `null` means the repo root itself).
class _Step {
  const _Step({
    required this.name,
    required this.executable,
    required this.arguments,
    this.workingDirectory,
  });

  final String name;
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;

  String get command => '$executable ${arguments.join(' ')}';
}

Future<void> main(List<String> args) async {
  final skipTests = args.contains('--skip-tests');

  final steps = <_Step>[
    const _Step(
      name: 'Format check',
      executable: 'fvm',
      arguments: ['dart', 'format', '-l', '100', '--output=none', '--set-exit-if-changed', '.'],
    ),
    const _Step(
      name: 'Analyze',
      executable: 'fvm',
      arguments: ['flutter', 'analyze', '--fatal-infos'],
    ),
    const _Step(
      name: 'Architecture boundaries',
      executable: 'fvm',
      arguments: ['dart', 'run', 'tool/check_architecture.dart'],
    ),
    const _Step(
      name: 'AI config sync',
      executable: 'fvm',
      arguments: ['dart', 'run', 'tool/sync_ai_config.dart', '--check'],
    ),
    if (!skipTests) ...[
      const _Step(
        name: 'Tests (tool/)',
        executable: 'fvm',
        arguments: ['dart', 'test', 'tool/test'],
      ),
      const _Step(name: 'Tests (root)', executable: 'fvm', arguments: ['flutter', 'test']),
      const _Step(
        name: 'Tests (packages/domain)',
        executable: 'fvm',
        arguments: ['dart', 'test'],
        workingDirectory: 'packages/domain',
      ),
      const _Step(
        name: 'Tests (packages/data)',
        executable: 'fvm',
        arguments: ['flutter', 'test'],
        workingDirectory: 'packages/data',
      ),
      const _Step(
        name: 'Tests (packages/ui)',
        executable: 'fvm',
        arguments: ['flutter', 'test'],
        workingDirectory: 'packages/ui',
      ),
    ],
  ];

  if (skipTests) {
    stdout
      ..writeln(
        '--skip-tests set: skipping the test suite (do NOT use this before calling a '
        'task done).',
      )
      ..writeln();
  }

  final results = <_StepResult>[];
  for (final step in steps) {
    stdout.writeln(
      'Running: ${step.name} (${step.command})${_workingDirSuffix(step.workingDirectory)}',
    );
    results.add(await _runStep(step));
  }

  _printSummary(results);

  final allPassed = results.every((r) => r.passed);
  exit(allPassed ? 0 : 1);
}

String _workingDirSuffix(String? workingDirectory) {
  return workingDirectory == null ? '' : ' in $workingDirectory/';
}

/// Runs [step] as a subprocess, capturing its stdout/stderr rather than
/// streaming them live — output is only shown for a FAILED step, in the
/// final summary, so a passing run stays quiet and a failing one shows
/// exactly what went wrong.
Future<_StepResult> _runStep(_Step step) async {
  final result = await Process.run(
    step.executable,
    step.arguments,
    workingDirectory: step.workingDirectory,
    runInShell: true,
  );

  return _StepResult(
    name: step.name,
    passed: result.exitCode == 0,
    stdout: result.stdout.toString(),
    stderr: result.stderr.toString(),
    command: step.command,
  );
}

void _printSummary(List<_StepResult> results) {
  final divider = '=' * 78;
  stdout
    ..writeln()
    ..writeln(divider)
    ..writeln('Quality gate summary')
    ..writeln(divider);

  final nameWidth = results.map((r) => r.name.length).reduce((a, b) => a > b ? a : b);
  for (final result in results) {
    final status = result.passed ? 'PASS' : 'FAIL';
    stdout.writeln('${result.name.padRight(nameWidth)}  $status');
  }

  final failed = results.where((r) => !r.passed).toList();
  if (failed.isEmpty) {
    stdout
      ..writeln()
      ..writeln('All steps passed.');
    return;
  }

  stdout
    ..writeln()
    ..writeln('${failed.length} step(s) failed — full output below.');
  final sectionDivider = '-' * 78;
  for (final result in failed) {
    stdout
      ..writeln()
      ..writeln(sectionDivider)
      ..writeln('FAILED: ${result.name} (${result.command})')
      ..writeln(sectionDivider);
    if (result.stdout.trim().isNotEmpty) {
      stdout.writeln(result.stdout.trimRight());
    }
    if (result.stderr.trim().isNotEmpty) {
      stdout.writeln(result.stderr.trimRight());
    }
  }
}

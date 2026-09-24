// tool/test/sync_ai_config_test.dart
//
// Fixture-based tests for `tool/sync_ai_config.dart`. Plain `package:test`
// (NOT `flutter_test`) for the same reason `check_architecture_test.dart`
// is — the script has no Flutter dependency, and `package:test` is already
// resolvable at the workspace root.
//
// Run it with:
//   fvm dart test tool/test/sync_ai_config_test.dart
//
// Covers the three pieces of `tool/sync_ai_config.dart` that are specific
// to OpenCode/Pi harness support and easy to silently regress:
//   - `skillValidationErrors` — the Agent Skills naming spec OpenCode
//     enforces (silently) and Pi warns on.
//   - `openCodePermissionFor` — the access-level -> permission mapping that
//     makes each agent's "do not delegate" rule structural in OpenCode.
//   - `renderOpenCodeConfig` — the shape of the generated `mcp` block.
import 'package:test/test.dart';

import '../sync_ai_config.dart';

void main() {
  group('skillValidationErrors', () {
    String validSkillMd({String name = 'my-skill', String description = 'A valid skill.'}) =>
        '---\n'
        'name: $name\n'
        'description: $description\n'
        '---\n\n'
        '# My skill\n';

    test('accepts a lowercase, hyphenated name matching its folder', () {
      final errors = skillValidationErrors(
        folderName: 'my-skill',
        skillMdContent: validSkillMd(),
      );

      expect(errors, isEmpty);
    });

    test('rejects a name containing an underscore', () {
      final errors = skillValidationErrors(
        folderName: 'flutter_fvm',
        skillMdContent: validSkillMd(name: 'flutter_fvm'),
      );

      expect(errors, isNotEmpty);
      expect(
        errors,
        contains(contains(r'name "flutter_fvm" must match ^[a-z0-9]+(-[a-z0-9]+)*$')),
      );
    });

    test('rejects a name that does not match its folder name', () {
      final errors = skillValidationErrors(
        folderName: 'my-skill',
        skillMdContent: validSkillMd(name: 'a-different-name'),
      );

      expect(
        errors,
        contains(contains('must match its folder name "my-skill"')),
      );
    });

    test('rejects an empty description', () {
      final errors = skillValidationErrors(
        folderName: 'my-skill',
        skillMdContent: '---\nname: my-skill\ndescription: \n---\n\n# My skill\n',
      );

      expect(errors, contains(contains('description must not be empty')));
    });

    test('rejects a description longer than 1024 characters', () {
      final longDescription = 'a' * 1025;
      final errors = skillValidationErrors(
        folderName: 'my-skill',
        skillMdContent: validSkillMd(description: longDescription),
      );

      expect(errors, contains(contains('must be 1024 or fewer')));
    });

    test('reports missing frontmatter instead of throwing', () {
      final errors = skillValidationErrors(
        folderName: 'my-skill',
        skillMdContent: '# Not a skill file\n',
      );

      expect(errors, contains(contains('missing or malformed YAML frontmatter')));
    });

    test('reports a YAML parse error instead of throwing out of the generator', () {
      // An unquoted colon inside a scalar value is invalid YAML — this must
      // surface as one validation error for this skill, not crash
      // tool/sync_ai_config.dart before it renders anything for every other
      // skill.
      final errors = skillValidationErrors(
        folderName: 'my-skill',
        skillMdContent:
            '---\n'
            'name: my-skill\n'
            'description: Use when: you need X\n'
            '---\n\n'
            '# My skill\n',
      );

      expect(errors, contains(contains('malformed YAML frontmatter')));
    });
  });

  group('openCodePermissionFor', () {
    test('read-only denies edit, task and webfetch', () {
      expect(openCodePermissionFor('read-only'), {
        'edit': 'deny',
        'task': 'deny',
        'webfetch': 'deny',
      });
    });

    test('run-only renders identically to read-only', () {
      expect(openCodePermissionFor('run-only'), openCodePermissionFor('read-only'));
    });

    test('write only denies task, so delegation is blocked but editing is not', () {
      expect(openCodePermissionFor('write'), {'task': 'deny'});
    });

    test('throws on an unknown access level', () {
      expect(() => openCodePermissionFor('bogus'), throwsArgumentError);
    });
  });

  group('renderOpenCodeAgent', () {
    test('a read-only agent has no model field and denies edit/task', () {
      final agent = AgentDef(
        name: 'reviewer',
        description: 'An adversarial reviewer.',
        access: 'read-only',
        tier: 'standard',
        skills: const [],
        prompt: 'You review code.',
      );

      final rendered = renderOpenCodeAgent(agent);

      expect(rendered, contains('name: reviewer'));
      expect(rendered, contains('mode: subagent'));
      expect(rendered, contains('edit: deny'));
      expect(rendered, contains('task: deny'));
      expect(rendered, isNot(contains('model:')));
    });
  });

  group('renderOpenCodeConfig', () {
    test('renders a local MCP server as a command array with env expansion', () {
      final servers = [
        McpServer(
          name: 'dart',
          description: 'The Dart MCP server.',
          command: 'fvm',
          args: const ['dart', 'mcp-server'],
          envVarNames: const ['SOME_TOKEN'],
          enabledByDefault: true,
        ),
      ];

      final rendered = renderOpenCodeConfig(servers);

      expect(rendered, contains(r'"$schema": "https://opencode.ai/config.json"'));
      expect(rendered, contains('"type": "local"'));
      expect(rendered, contains('"command": ["fvm", "dart", "mcp-server"]'));
      expect(rendered, contains('"environment": {"SOME_TOKEN": "{env:SOME_TOKEN}"}'));
      expect(rendered, contains('"enabled": true'));
      expect(rendered, contains('"formatter"'));
      expect(rendered, contains('"dart"'));
      expect(rendered, contains(r'"$FILE"'));
    });

    test('a disabled-by-default server renders enabled: false', () {
      final servers = [
        McpServer(
          name: 'figma',
          description: 'Optional Figma MCP server.',
          command: 'npx',
          args: const ['-y', 'mcp-remote', 'https://mcp.figma.com/mcp'],
          envVarNames: const [],
          enabledByDefault: false,
        ),
      ];

      final rendered = renderOpenCodeConfig(servers);

      expect(rendered, contains('"enabled": false'));
      expect(rendered, isNot(contains('"environment"')));
    });
  });
}

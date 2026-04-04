// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // Scope is required for all commits
    'scope-empty': [2, 'never'],
    // Enforce type-enum to match project standards
    'type-enum': [
      2,
      'always',
      [
        'feat',
        'fix',
        'docs',
        'style',
        'refactor',
        'perf',
        'test',
        'build',
        'ci',
        'chore',
        'revert',
        'merge',
      ],
    ],
    // Scopes should use forward slashes for multiple scopes (no hyphens)
    'scope-case': [2, 'always', 'lower-case'],
    // Subject should not start with uppercase
    'subject-case': [0],
    // Subject should not be empty
    'subject-empty': [2, 'never'],
    // Subject should not end with period
    'subject-full-stop': [2, 'never', '.'],
    // Header max length: 100 chars (more lenient for complex scopes)
    'header-max-length': [2, 'always', 100],
  },
};

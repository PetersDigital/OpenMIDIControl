#!/usr/bin/env python3
"""
Interactive Conventional Commit Helper

Guides users through creating valid conventional commit messages that comply
with commitlint standards. Ensures all commits are properly formatted for
automated changelog and release notes generation.

Usage:
    python scripts/commit.py                    # Interactive mode
    python scripts/commit.py "feat(ui): add button"  # Direct commit
    python scripts/commit.py --no-verify        # Bypass git hooks
"""

# Copyright (c) 2026 Peters Digital
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import subprocess
import sys
import re
from pathlib import Path
from tempfile import NamedTemporaryFile
from typing import Optional, List, Tuple, Dict


class Colors:
    """ANSI color codes for terminal output."""
    CYAN = '\033[96m'
    YELLOW = '\033[93m'
    GREEN = '\033[92m'
    RED = '\033[91m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    RESET = '\033[0m'


# Conventional commit types with descriptions
COMMIT_TYPES: Dict[str, str] = {
    'feat': '✨ A new feature',
    'fix': '🐛 A bug fix',
    'docs': '📚 Documentation only changes',
    'style': '💄 Changes that do not affect the meaning of the code',
    'refactor': '♻️ A code change that neither fixes a bug nor adds a feature',
    'perf': '⚡ A code change that improves performance',
    'test': '✅ Adding missing tests or correcting existing tests',
    'build': '📦 Changes that affect the build system or external dependencies',
    'ci': '🔧 Changes to CI configuration files and scripts',
    'chore': '🔖 Other changes that do not modify src or test files',
    'revert': '⏪ Reverts a previous commit',
    'merge': '🔀 Merge commit for milestone releases',
}

# Standard scopes for the project
PROJECT_SCOPES: Dict[str, str] = {
    # Core app
    'android': 'Android native Kotlin layer',
    'android/midi': 'Android native MIDI layer',
    'android/ui': 'Android-specific UI code',
    'ui': 'Flutter UI components',
    'ui/midi': 'Dart MIDI service layer',
    'ui/fader': 'Fader widgets',
    'core': 'Core app logic',
    'core/midi': 'Core MIDI models (MidiEvent)',
    'core/state': 'State management (ControlState, Riverpod)',
    'midi': 'General MIDI functionality',
    'midi/router': 'MIDI routing engine',

    # CI/CD & Tooling
    'ci': 'CI/CD workflows',
    'ci/actions': 'GitHub Actions composite actions',
    'scripts': 'Development scripts',
    'deps': 'Dependencies',
    'docs': 'Documentation',
    'config': 'Configuration files',
    'git': 'Git configuration',
    'lint': 'Linting and code quality',

    # Testing
    'test': 'Test files',
    'test/unit': 'Unit tests',
    'test/widget': 'Widget tests',
    'test/hitl': 'Hardware-in-the-Loop tests',

    # Merge commits (branch patterns)
    'main/release': 'Merge release branch to main',
    'dev/main': 'Merge dev branch to main',
    'dev/release': 'Merge dev to release branch',
    'feature/main': 'Merge feature branch to main',
    'hotfix/main': 'Merge hotfix branch to main',
    'beta/main': 'Merge beta to main',
}

# Conventional commit regex for local validation
CONVENTIONAL_REGEX = r'^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert|merge)(\([a-zA-Z0-9/_-]+\))?: .+'

# Common CI workflow markers
CI_MARKERS = [
    '[skip ci]',
    '[ci skip]',
    '[wip]',
    '[skip-build]',
    '[skip-release]',
    '[build]',
    '[dev]',
    '[beta]',
]


def print_header(text: str) -> None:
    """Print a colored header."""
    print(f"\n{Colors.CYAN}{'=' * 60}{Colors.RESET}")
    print(f"{Colors.CYAN}{Colors.BOLD}{text:^60}{Colors.RESET}")
    print(f"{Colors.CYAN}{'=' * 60}{Colors.RESET}\n")


def print_success(text: str) -> None:
    """Print a success message."""
    print(f"  {Colors.GREEN}[v]{Colors.RESET} {text}")


def print_error(text: str) -> None:
    """Print an error message."""
    print(f"  {Colors.RED}[x]{Colors.RESET} {text}")


def print_warn(text: str) -> None:
    """Print a warning message."""
    print(f"  {Colors.YELLOW}[!]{Colors.RESET} {text}")


def print_info(text: str) -> None:
    """Print an info message."""
    print(f"  {Colors.CYAN}[i]{Colors.RESET} {text}")


def run_command(cmd: List[str]) -> Tuple[bool, str]:
    """Run a shell command and return success status and output."""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True
        )
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        return False, f"{e.stderr}\n{e.output}"
    except FileNotFoundError:
        return False, f"Command not found: {cmd[0]}"


def select_from_list(items: List[Tuple[str, str]], title: str) -> Optional[str]:
    """Present a numbered list for user selection."""
    print(f"\n{Colors.BOLD}{title}{Colors.RESET}\n")

    for i, (key, desc) in enumerate(items, 1):
        print(f"  {Colors.GREEN}{i:2d}.{Colors.RESET} {Colors.BOLD}{key:<20}{Colors.RESET} {desc}")

    print(f"\n  {Colors.YELLOW}0.{Colors.RESET} Skip (no {title.lower().split()[-1]})")

    while True:
        try:
            choice = input(f"\n{Colors.CYAN}Select (1-{len(items)}, or 0 to skip): {Colors.RESET}").strip()

            if choice == '0':
                return None

            idx = int(choice) - 1
            if 0 <= idx < len(items):
                return items[idx][0]
            else:
                print_error(f"Invalid selection. Please enter 1-{len(items)} or 0.")
        except ValueError:
            print_error("Invalid input. Please enter a number.")


def select_scope(items: List[Tuple[str, str]], suggested: Optional[str] = None) -> Optional[str]:
    """Present a numbered list for scope selection with custom input option."""
    print(f"\n{Colors.BOLD}Scope (Optional){Colors.RESET}\n")

    if suggested:
        print(f"  {Colors.CYAN}Suggested: {suggested}{Colors.RESET}\n")

    for i, (key, desc) in enumerate(items, 1):
        print(f"  {Colors.GREEN}{i:3d}.{Colors.RESET} {Colors.BOLD}{key:<20}{Colors.RESET} {desc}")

    print(f"  {Colors.YELLOW}  0.{Colors.RESET} Enter custom scope")

    while True:
        choice = input(f"\n{Colors.CYAN}Select (1-{len(items)}, or 0 for custom): {Colors.RESET}").strip()

        if choice == '0':
            custom = input(f"{Colors.CYAN}Enter custom scope (lowercase, use / for nesting, e.g., 'ui/settings'): {Colors.RESET}").strip().lower()
            # Validate scope: lowercase, alphanumeric + slashes + underscores + hyphens
            if custom and re.match(r'^[a-z0-9/_-]+$', custom):
                if '/' in custom and '-' in custom.split('/')[-1]:
                    print_warn("Prefer '/' over '-' for nested scopes. Continuing anyway.")
                return custom
            elif custom:
                print_error("Invalid scope. Use only lowercase letters, numbers, '/', '_', or '-'.")
                if input(f"{Colors.CYAN}Continue anyway? (y/N): {Colors.RESET}").strip().lower() == 'y':
                    return custom
            continue

        try:
            idx = int(choice) - 1
            if 0 <= idx < len(items):
                return items[idx][0]
            else:
                print_error(f"Invalid selection. Please enter 1-{len(items)} or 0.")
        except ValueError:
            print_error("Invalid input. Please enter a number.")


def get_commitlint_cmd() -> Optional[List[str]]:
    """Find available commitlint command."""
    commands = [
        ['npx', '--no-install', 'commitlint'],
        ['pnpm', 'commitlint'],
        ['yarn', 'commitlint'],
        ['npx', 'commitlint'],  # Fallback: allows install
    ]

    for cmd in commands:
        success, _ = run_command(cmd + ['--version'])
        if success:
            return cmd

    return None


def get_user_scopes() -> List[Tuple[str, str]]:
    """Load custom scopes from commitlint.config.js if available."""
    config_path = Path("commitlint.config.js")

    if config_path.exists():
        try:
            content = config_path.read_text(encoding='utf-8')
            scopes_match = re.search(r'scopes:\s*\[(.*?)\]', content, re.DOTALL)
            if scopes_match:
                scopes_str = scopes_match.group(1)
                scopes = re.findall(r"['\"]([^'\"]+)['\"]", scopes_str)
                if scopes:
                    return [(scope, PROJECT_SCOPES.get(scope, 'Custom scope'))
                           for scope in scopes]
        except Exception:
            pass

    return list(PROJECT_SCOPES.items())


def get_user_types() -> List[Tuple[str, str]]:
    """Load commit types from commitlint.config.js if available."""
    config_path = Path("commitlint.config.js")

    if config_path.exists():
        try:
            content = config_path.read_text(encoding='utf-8')
            types_match = re.search(r'types:\s*\{(.*?)\}', content, re.DOTALL)
            if types_match:
                types_str = types_match.group(1)
                types = re.findall(r"['\"]([^'\"]+)['\"]", types_str)
                if types:
                    return [(t, COMMIT_TYPES.get(t, 'Custom type')) for t in types]
        except Exception:
            pass

    return list(COMMIT_TYPES.items())


def validate_description(desc: str) -> Optional[str]:
    """Validate description follows conventional commit rules."""
    if not desc:
        return "Description cannot be empty"

    if desc[0].isupper():
        return "Description should start with lowercase"

    if desc.endswith('.'):
        return "Description should not end with a period"

    if len(desc) > 72:
        return f"Description exceeds 72 characters ({len(desc)} chars)"

    return None


def validate_commit_message_local(message: str) -> Tuple[bool, str]:
    """Local validation using regex (fast, no dependencies)."""
    if not re.match(CONVENTIONAL_REGEX, message):
        return False, "Invalid conventional commit format. Expected: type(scope): description"
    return True, "Local validation passed"


def validate_commit_message(message: str) -> Tuple[bool, str]:
    """Validate a commit message against commitlint with local fallback."""
    # First, do local validation (always runs)
    is_valid, local_msg = validate_commit_message_local(message)
    if not is_valid:
        return False, local_msg

    # Then try commitlint if available
    commitlint_cmd = get_commitlint_cmd()
    if not commitlint_cmd:
        print_warn("commitlint not available, using local validation only")
        return True, "Valid (local validation)"

    # Use temp file for commitlint
    with NamedTemporaryFile(mode='w', suffix='.txt', delete=False, encoding='utf-8') as f:
        f.write(message)
        temp_path = f.name

    try:
        success, output = run_command(commitlint_cmd + ['--edit', temp_path])
        if success:
            return True, "Commit message is valid!"
        else:
            return False, output
    finally:
        Path(temp_path).unlink(missing_ok=True)


def create_commit_message(commit_type: str, scope: Optional[str], description: str) -> str:
    """Create a conventional commit message."""
    if scope:
        return f"{commit_type}({scope}): {description}"
    else:
        return f"{commit_type}: {description}"


def commit_with_message(commit_msg: str, no_verify: bool = False) -> Tuple[bool, str]:
    """Commit with proper multiline message handling."""
    parts = commit_msg.split("\n\n")
    cmd = ['git', 'commit']

    if no_verify:
        cmd.append('--no-verify')

    for part in parts:
        cmd.extend(['-m', part])

    return run_command(cmd)


def get_staged_files() -> str:
    """Get list of staged files."""
    success, files = run_command(['git', 'diff', '--cached', '--name-only'])
    return files if success else ""


def has_staged_changes() -> bool:
    """Check if there are staged changes."""
    success, files = run_command(['git', 'diff', '--cached', '--name-only'])
    return success and bool(files.strip())


def suggest_scope() -> Optional[str]:
    """Auto-suggest scope based on staged files."""
    files = get_staged_files()
    if not files:
        return None

    # Map file patterns to scopes
    scope_mappings = [
        ('app/android/', 'android'),
        ('app/lib/ui/', 'ui'),
        ('app/lib/core/', 'core'),
        ('scripts/', 'scripts'),
        ('.github/', 'ci'),
        ('app/test/', 'test'),
        ('app/pubspec.yaml', 'deps'),
    ]

    for pattern, scope in scope_mappings:
        if pattern in files:
            return scope

    return None


def interactive_mode(no_verify: bool = False) -> int:
    """Run the interactive commit helper."""
    print_header("Conventional Commit Helper")

    # Check if we're in a git repository
    success, _ = run_command(['git', 'rev-parse', '--git-dir'])
    if not success:
        print_error("Not a git repository")
        return 1

    # Check for staged changes
    if not has_staged_changes():
        print_warn("No staged changes found")
        if input(f"\n{Colors.CYAN}Stage all changes? (y/N): {Colors.RESET}").strip().lower() == 'y':
            run_command(['git', 'add', '-A'])
            if not has_staged_changes():
                print_error("Still no changes to commit")
                return 1
        else:
            print_info("Stage changes with 'git add <file>' first")
            return 1

    # Auto-suggest scope
    suggested_scope = suggest_scope()
    if suggested_scope:
        print_info(f"Suggested scope: {suggested_scope}")

    # Step 1: Select commit type
    types = get_user_types()
    commit_type = select_from_list(types, "Commit Type")

    if not commit_type:
        print_error("Commit type is required")
        return 1

    # Step 2: Select scope (with suggestion + custom option)
    scopes = get_user_scopes()
    scope = select_scope(scopes, suggested_scope)

    # Step 3: Enter description with local validation
    print(f"\n{Colors.BOLD}Commit Description{Colors.RESET}")
    print(f"  {Colors.YELLOW}•{Colors.RESET} Start with lowercase (e.g., 'add new fader control')")
    print(f"  {Colors.YELLOW}•{Colors.RESET} Use imperative mood (e.g., 'fix' not 'fixed')")
    print(f"  {Colors.YELLOW}•{Colors.RESET} No period at the end")
    print(f"  {Colors.YELLOW}•{Colors.RESET} Max 72 characters recommended")

    while True:
        description = input(f"\n{Colors.CYAN}Enter description: {Colors.RESET}").strip()

        error = validate_description(description)
        if error:
            print_error(error)
            if input(f"{Colors.CYAN}Continue anyway? (y/N): {Colors.RESET}").strip().lower() != 'y':
                continue

        break

    if not description:
        print_error("Description cannot be empty")
        return 1

    # Create commit message
    commit_msg = create_commit_message(commit_type, scope, description)

    # Step 4: Optional body
    print(f"\n{Colors.BOLD}Optional: Add body/footers?{Colors.RESET}")
    print(f"  {Colors.YELLOW}•{Colors.RESET} Body: Additional context")
    print(f"  {Colors.YELLOW}•{Colors.RESET} BREAKING CHANGE: Major API changes")

    body_choice = input(f"\n{Colors.CYAN}Add body? (y/N): {Colors.RESET}").strip().lower()

    if body_choice == 'y':
        body = input(f"\n{Colors.CYAN}Body (multi-line supported, empty to skip): {Colors.RESET}").strip()
        if body:
            commit_msg += f"\n\n{body}"

    # Add breaking change footer
    if input(f"\n{Colors.CYAN}Is this a BREAKING CHANGE? (y/N): {Colors.RESET}").strip().lower() == 'y':
        breaking_desc = input(f"{Colors.CYAN}Describe the breaking change: {Colors.RESET}").strip()
        commit_msg += f"\n\nBREAKING CHANGE: {breaking_desc}"

    # Add issue references
    issues = input(f"\n{Colors.CYAN}Issue references (e.g., 'Closes #123', empty to skip): {Colors.RESET}").strip()
    if issues:
        commit_msg += f"\n\n{issues}"

    # Add CI workflow markers
    print(f"\n{Colors.BOLD}Optional: Add CI workflow markers{Colors.RESET}")
    for i, m in enumerate(CI_MARKERS, 1):
        print(f"  {Colors.GREEN}{i:2d}.{Colors.RESET} {m}")
    print(f"  {Colors.YELLOW}0.{Colors.RESET} Skip")

    marker_choice = input(f"\n{Colors.CYAN}Select marker(s) or enter custom (comma-separated for multiple): {Colors.RESET}").strip()
    if marker_choice and marker_choice != '0':
        if marker_choice.isdigit():
            idx = int(marker_choice) - 1
            if 0 <= idx < len(CI_MARKERS):
                commit_msg += f"\n\n{CI_MARKERS[idx]}"
        elif ',' in marker_choice:
            indices = [int(x.strip()) - 1 for x in marker_choice.split(',') if x.strip().isdigit()]
            selected = [CI_MARKERS[i] for i in indices if 0 <= i < len(CI_MARKERS)]
            if selected:
                commit_msg += f"\n\n{' '.join(selected)}"
        else:
            # Treat as custom marker
            commit_msg += f"\n\n{marker_choice}"

    # Step 5: Preview and edit loop
    while True:
        print(f"\n{Colors.BOLD}Full commit message:{Colors.RESET}")
        print(f"{Colors.GREEN}{commit_msg}{Colors.RESET}")

        edit = input(f"\n{Colors.CYAN}Edit message? (y/N): {Colors.RESET}").strip().lower()
        if edit != 'y':
            break

        print(f"\n{Colors.CYAN}1. Edit description{Colors.RESET}")
        print(f"{Colors.CYAN}2. Edit scope{Colors.RESET}")
        print(f"{Colors.CYAN}3. Add/edit body{Colors.RESET}")
        print(f"{Colors.CYAN}4. Start over{Colors.RESET}")

        choice = input(f"\n{Colors.CYAN}Choice (1-4): {Colors.RESET}").strip()

        if choice == '1':
            description = input(f"\n{Colors.CYAN}New description: {Colors.RESET}").strip()
            if description:
                commit_msg = create_commit_message(commit_type, scope, description)
        elif choice == '2':
            scopes = get_user_scopes()
            new_scope = select_scope(scopes, scope)
            if new_scope is not None:
                scope = new_scope
            commit_msg = create_commit_message(commit_type, scope, description)
        elif choice == '3':
            body = input(f"\n{Colors.CYAN}Body text: {Colors.RESET}").strip()
            if body:
                commit_msg += f"\n\n{body}"
        elif choice == '4':
            return interactive_mode(no_verify)

    # Step 6: Validate with commitlint
    print(f"\n{Colors.CYAN}Validating commit message...{Colors.RESET}")
    is_valid, validation_msg = validate_commit_message(commit_msg)

    if is_valid:
        print_success(validation_msg)
    else:
        print_warn("Commit message validation failed:")
        print(f"  {validation_msg}")

        if input(f"\n{Colors.CYAN}Continue anyway? (y/N): {Colors.RESET}").strip().lower() != 'y':
            print_info("Aborted. Please fix the issues and try again.")
            return 1

    # Step 7: Create commit
    print(f"\n{Colors.BOLD}Ready to commit{Colors.RESET}")

    if input(f"\n{Colors.CYAN}Create commit? (Y/n): {Colors.RESET}").strip().lower() == 'n':
        print_info("Aborted. Commit not created.")
        return 0

    success, output = commit_with_message(commit_msg, no_verify)

    if success:
        print_header("Success!")
        print_success(f"Created commit: {commit_msg.split(chr(10))[0]}")
        print(f"\n{Colors.GREEN}Your commit is ready!{Colors.RESET}")
        return 0
    else:
        print_error("Failed to create commit:")
        print(f"  {output}")
        return 1


def direct_mode(message: str, no_verify: bool = False) -> int:
    """Commit with a direct message (non-interactive)."""
    print_header("Direct Commit")

    # Validate message
    is_valid, validation_msg = validate_commit_message(message)

    if is_valid:
        print_success(validation_msg)
    else:
        print_warn("Commit message validation failed:")
        print(f"  {validation_msg}")

        if input(f"\n{Colors.CYAN}Continue anyway? (y/N): {Colors.RESET}").strip().lower() != 'y':
            return 1

    # Stage all changes if needed
    if not has_staged_changes():
        run_command(['git', 'add', '-A'])

    # Create commit
    success, output = commit_with_message(message, no_verify)

    if success:
        print_header("Success!")
        print_success(f"Created commit: {message}")
        return 0
    else:
        print_error("Failed to create commit:")
        print(f"  {output}")
        return 1


def main() -> int:
    """Main entry point."""
    no_verify = '--no-verify' in sys.argv

    # Remove flags from message
    args = [arg for arg in sys.argv[1:] if not arg.startswith('--')]

    if args:
        message = ' '.join(args)
        return direct_mode(message, no_verify)
    else:
        return interactive_mode(no_verify)


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
YAML Workflow Validator and Fixer

Validates GitHub Actions workflows using actionlint and yamllint.
Automatically fixes common issues like CRLF line endings, trailing spaces,
and emojis in YAML files.

Note: actionlint includes built-in shellcheck for 'run:' blocks with proper
GitHub Actions context, so no separate shellcheck step is needed.

Usage:
    python scripts/validate_workflows.py [workflow_files...]

Examples:
    python scripts/validate_workflows.py
    python scripts/validate_workflows.py .github/workflows/cd_prod_*.yml
    python scripts/validate_workflows.py .github/workflows/ci_*.yml
"""

# Copyright (c) 2026 Peters Digital
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import os
import re
import sys
import subprocess
import glob
from pathlib import Path
from typing import List, Tuple


class Colors:
    """ANSI color codes for terminal output."""
    CYAN = '\033[96m'
    YELLOW = '\033[93m'
    GREEN = '\033[92m'
    RED = '\033[91m'
    RESET = '\033[0m'


def print_header(text: str) -> None:
    """Print a colored header."""
    print(f"\n{Colors.CYAN}=== {text} ==={Colors.RESET}\n")


def print_step(step_num: int, text: str) -> None:
    """Print a step header."""
    print(f"{Colors.YELLOW}[{step_num}/5] {text}{Colors.RESET}")


def print_success(text: str) -> None:
    """Print a success message."""
    print(f"  {Colors.GREEN}✓{Colors.RESET} {text}")


def print_error(text: str) -> None:
    """Print an error message."""
    print(f"  {Colors.RED}✗{Colors.RESET} {text}")


def print_warning(text: str) -> None:
    """Print a warning message."""
    print(f"  {Colors.YELLOW}⚠{Colors.RESET} {text}")


def fix_line_endings(files: List[str]) -> Tuple[List[str], List[str]]:
    """
    Convert CRLF to LF in the given files.

    Returns:
        Tuple of (fixed_files, failed_files)
    """
    fixed = []
    failed = []

    for filepath in files:
        try:
            with open(filepath, 'rb') as f:
                content = f.read()

            # Check if CRLF exists
            if b'\r\n' in content:
                content = content.replace(b'\r\n', b'\n')
                with open(filepath, 'wb') as f:
                    f.write(content)
                fixed.append(filepath)
            else:
                fixed.append(filepath)  # Already LF, consider it "fixed"
        except Exception as e:
            print_error(f"Failed to fix {filepath}: {e}")
            failed.append(filepath)

    return fixed, failed


def remove_trailing_spaces(files: List[str]) -> Tuple[List[str], List[str]]:
    """
    Remove trailing spaces from YAML files.

    Returns:
        Tuple of (fixed_files, failed_files)
    """
    fixed = []
    failed = []

    for filepath in files:
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                lines = f.readlines()

            original_lines = lines.copy()

            # Remove trailing spaces from each line
            lines = [line.rstrip() + '\n' if line.endswith('\n') else line.rstrip()
                     for line in lines]

            # Only write if changed
            if lines != original_lines:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.writelines(lines)
                fixed.append(filepath)
            else:
                fixed.append(filepath)  # Already clean
        except Exception as e:
            print_error(f"Failed to process {filepath}: {e}")
            failed.append(filepath)

    return fixed, failed


def remove_emojis_and_unicode_symbols(files: List[str]) -> Tuple[List[str], List[str]]:
    """
    Remove emojis and non-essential Unicode symbols from YAML files.
    Preserves only characters needed for YAML syntax to function.

    Removed:
    - Emojis: U+1F300-U+1F9FF, U+1FA00-U+1FAFF, U+2600-U+27BF, U+1F1E0-U+1F1FF
    - Unicode quotes: U+2018, U+2019, U+201C, U+201D (replaced with ASCII)

    Returns:
        Tuple of (fixed_files, failed_files)
    """
    # Comprehensive emoji and symbol pattern
    emoji_pattern = re.compile(
        "["
        "\U0001F300-\U0001F9FF"  # Main emoji blocks (Misc Symbols, Emoticons, etc.)
        "\U0001FA00-\U0001FAFF"  # Symbols and Pictographs Extended-A
        "\U00002600-\U000027BF"  # Miscellaneous Symbols and Dingbats
        "\U0001F1E0-\U0001F1FF"  # Regional Indicator Symbols (flags)
        "]+",
        flags=re.UNICODE
    )

    # Unicode quotes to replace with ASCII equivalents
    unicode_quotes = {
        '\u2018': "'",  # Left single quote
        '\u2019': "'",  # Right single quote
        '\u201C': '"',  # Left double quote
        '\u201D': '"',  # Right double quote
    }

    fixed = []
    failed = []

    for filepath in files:
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()

            original_content = content

            # Remove emojis
            if emoji_pattern.search(content):
                content = emoji_pattern.sub('', content)

            # Replace unicode quotes
            for unicode_char, ascii_char in unicode_quotes.items():
                if unicode_char in content:
                    content = content.replace(unicode_char, ascii_char)

            # Only write if changed
            if content != original_content:
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)

            fixed.append(filepath)
        except Exception as e:
            print_error(f"Failed to process {filepath}: {e}")
            failed.append(filepath)

    return fixed, failed


def run_actionlint(files: List[str]) -> bool:
    """
    Run actionlint on the given files.

    Note: actionlint includes built-in shellcheck for 'run:' blocks with
    proper GitHub Actions context.

    Returns:
        True if all checks pass, False otherwise
    """
    try:
        result = subprocess.run(
            ['actionlint', '-shellcheck='] + files,
            capture_output=True,
            text=True
        )

        if result.returncode == 0:
            return True
        else:
            print(result.stdout)
            print(result.stderr)
            return False
    except FileNotFoundError:
        print_error("actionlint not found. Install with: pipx install actionlint")
        return False
    except Exception as e:
        print_error(f"actionlint failed: {e}")
        return False


def run_yamllint(files: List[str]) -> bool:
    """
    Run yamllint on the given files.

    Returns:
        True if all checks pass, False otherwise
    """
    # Look for yamllint config in .github/workflows/.yamllint
    config_path = ".github/workflows/.yamllint"

    try:
        if os.path.exists(config_path):
            cmd = ['yamllint', '-c', config_path] + files
        else:
            cmd = ['yamllint'] + files

        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True
        )

        if result.returncode == 0:
            return True
        else:
            print(result.stdout)
            print(result.stderr)
            return False
    except FileNotFoundError:
        print_error("yamllint not found. Install with: pip install yamllint")
        return False
    except Exception as e:
        print_error(f"yamllint failed: {e}")
        return False


def expand_glob_patterns(patterns: List[str]) -> List[str]:
    """Expand glob patterns to actual file paths."""
    files = []
    for pattern in patterns:
        if '*' in pattern or '?' in pattern:
            matched = glob.glob(pattern)
            if not matched:
                print_error(f"No files matched pattern: {pattern}")
            files.extend(matched)
        else:
            if os.path.exists(pattern):
                files.append(pattern)
            else:
                print_error(f"File not found: {pattern}")

    return sorted(set(files))


def main() -> int:
    """Main entry point."""
    print_header("YAML Workflow Validator")

    # Determine which files to process
    if len(sys.argv) > 1:
        patterns = sys.argv[1:]
    else:
        # Default: all workflow files (exclude action.yml files)
        patterns = [".github/workflows/*.yml"]

    files = expand_glob_patterns(patterns)

    if not files:
        print_error("No workflow files found to validate")
        return 1

    # Filter out action.yml files and non-workflow YAML files for actionlint
    workflow_files = [f for f in files if not f.endswith('action.yml') and '.github/workflows/' in f.replace('\\', '/')]
    action_files = [f for f in files if f.endswith('action.yml')]
    other_yaml_files = [f for f in files if f not in workflow_files and f not in action_files]

    if workflow_files:
        print(f"Found {len(workflow_files)} workflow file(s):\n")
        for f in workflow_files:
            print(f"  - {f}")
        if action_files:
            print(f"\nFound {len(action_files)} action file(s):")
            for f in action_files:
                print(f"  - {f}")
        if other_yaml_files:
            print(f"\nFound {len(other_yaml_files)} other YAML file(s):")
            for f in other_yaml_files:
                print(f"  - {f}")
        print()
    elif action_files:
        print(f"Found {len(action_files)} action file(s):\n")
        for f in action_files:
            print(f"  - {f}")
        if other_yaml_files:
            print(f"\nFound {len(other_yaml_files)} other YAML file(s):")
            for f in other_yaml_files:
                print(f"  - {f}")
        print()
    else:
        print(f"Found {len(other_yaml_files)} YAML file(s):\n")
        for f in other_yaml_files:
            print(f"  - {f}")
        print()

    # Step 1: Fix line endings
    print_step(1, "Fixing line endings (CRLF → LF)...")
    fixed, failed = fix_line_endings(files)

    if fixed:
        print_success(f"Fixed line endings in {len(fixed)} file(s)")
    if failed:
        print_error(f"Failed to fix {len(failed)} file(s)")
        return 1
    print()

    # Step 2: Remove trailing spaces
    print_step(2, "Removing trailing spaces...")
    fixed, failed = remove_trailing_spaces(files)

    if fixed:
        print_success(f"Removed trailing spaces in {len(fixed)} file(s)")
    if failed:
        print_error(f"Failed to process {len(failed)} file(s)")
        return 1
    print()

    # Step 3: Remove emojis
    print_step(3, "Removing emojis from YAML files...")
    fixed, failed = remove_emojis_and_unicode_symbols(files)

    if fixed:
        print_success(f"Removed emojis from {len(fixed)} file(s)")
    if failed:
        print_error(f"Failed to process {len(failed)} file(s)")
        return 1
    print()

    # Step 4: Run actionlint (only on .github/workflows/*.yml files)
    if workflow_files:
        print_step(4, "Running actionlint (includes shellcheck)...")
        if run_actionlint(workflow_files):
            print_success("actionlint passed")
        else:
            print_error("actionlint failed")
            return 1
        print()
    else:
        print_warning("Skipping actionlint (no workflow files)")
        print()

    # Step 5: Run yamllint (on all files)
    print_step(5, "Running yamllint...")
    if run_yamllint(files):
        print_success("yamllint passed")
    else:
        print_error("yamllint failed")
        return 1
    print()

    print_header("All checks passed!")
    print(f"\nTip: Run this script before committing workflow changes:")
    print(f"  python scripts/validate_workflows.py .github/workflows/*.yml\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
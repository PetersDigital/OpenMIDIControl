#!/usr/bin/env python3
"""
Test script to verify release notes generation logic.

This script tests the logic for:
- Beta tag detection
- Commit marker detection ([wip], [skip-release], [beta])
- Auto-release threshold logic
- Conventional commit parsing
- Git log retrieval
- Tag detection
- Release notes generation simulation
- Commit link generation

Usage:
    python scripts/test_release_notes.py
"""

# Copyright (c) 2026 Peters Digital
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import subprocess
import re
from typing import Optional, Tuple


class Colors:
    """ANSI color codes for terminal output."""
    CYAN = '\033[96m'
    YELLOW = '\033[93m'
    GREEN = '\033[92m'
    RED = '\033[91m'
    BOLD = '\033[1m'
    RESET = '\033[0m'


def print_header(text: str) -> None:
    """Print a colored header."""
    print(f"\n{Colors.CYAN}=== {text} ==={Colors.RESET}\n")


def print_section(text: str) -> None:
    """Print a section header."""
    print(f"{Colors.BOLD}[{text}]{Colors.RESET}")


def print_ok(text: str) -> None:
    """Print a success message."""
    print(f"  {Colors.GREEN}[OK]{Colors.RESET} {text}")


def print_fail(text: str) -> None:
    """Print a failure message."""
    print(f"  {Colors.RED}[FAIL]{Colors.RESET} {text}")


def print_warn(text: str) -> None:
    """Print a warning message."""
    print(f"  {Colors.YELLOW}[WARN]{Colors.RESET} {text}")


def print_error(text: str) -> None:
    """Print an error message."""
    print(f"  {Colors.RED}[ERROR]{Colors.RESET} {text}")


# Test 1: Beta tag detection
def test_beta_tag_detection() -> None:
    """Test beta tag pattern matching."""
    print_section("Test 1: Beta Tag Detection")
    print("Testing pattern matching for *-beta.*\n")

    test_cases = [
        ("v0.2.2-beta.1", True),
        ("v0.2.2-beta.44", True),
        ("v1.0.0-beta.5", True),
        ("v0.2.2", False),
        ("v1.0.0", False),
    ]

    for tag, expected_beta in test_cases:
        is_beta = "-beta." in tag
        status = "Beta release detected" if is_beta else "Stable release detected"
        if is_beta == expected_beta:
            print_ok(f"'{tag}' -> {status}")
        else:
            print_fail(f"'{tag}' -> Expected {'beta' if expected_beta else 'stable'}")

    print()


# Test 2: Commit marker detection
def test_commit_marker_detection() -> None:
    """Test [wip], [skip-release], [beta] marker detection."""
    print_section("Test 2: Commit Marker Detection")
    print("Testing [wip], [skip-release], [beta] markers\n")

    test_cases = [
        ("fix(midi): reduce latency [wip]", "skip"),
        ("docs: update README [skip-release]", "skip"),
        ("feat(ui): add new fader [beta]", "release"),
        ("fix: bug fix", "auto"),
        ("Multiple markers [wip][beta]", "skip"),
    ]

    for commit_msg, expected in test_cases:
        has_wip = "[wip]" in commit_msg
        has_skip = "[skip-release]" in commit_msg
        has_beta = "[beta]" in commit_msg

        if has_wip or has_skip:
            result = "skip"
        elif has_beta:
            result = "release"
        else:
            result = "auto"

        if result == expected:
            print_ok(f"'{commit_msg}' -> {result} (expected: {expected})")
        else:
            print_fail(f"'{commit_msg}' -> {result} (expected: {expected})")

    print()


# Test 3: Auto-release threshold logic
def test_auto_release_threshold() -> None:
    """Test auto-release threshold logic."""
    print_section("Test 3: Auto-Release Threshold Logic")
    print("Testing priority: skip > beta > auto(5+) > none\n")

    test_cases = [
        (True, False, 1, "skip"),
        (False, True, 1, "release"),
        (False, False, 5, "release"),
        (False, False, 3, "skip"),
        (False, False, 0, "skip"),
        (True, True, 10, "skip"),
    ]

    for has_skip, has_beta, commit_count, expected in test_cases:
        # Apply priority logic
        if has_skip:
            result = "skip"
        elif has_beta:
            result = "release"
        elif commit_count >= 5:
            result = "release"
        else:
            result = "skip"

        if result == expected:
            print_ok(f"skip={has_skip}, beta={has_beta}, count={commit_count} -> {result}")
        else:
            print_fail(f"skip={has_skip}, beta={has_beta}, count={commit_count} -> {result} (expected: {expected})")

    print()


# Test 4: Conventional commit parsing
def test_conventional_commit_parsing() -> None:
    """Test conventional commit pattern matching."""
    print_section("Test 4: Conventional Commit Pattern Matching")
    print()

    # Pattern: type(scope): description
    pattern = re.compile(r'^([a-zA-Z]+)(\([a-zA-Z0-9/_-]+\))?:\s+(.+)$')

    section_map = {
        'feat': 'Added',
        'feature': 'Added',
        'fix': 'Fixed',
        'perf': 'Changed',
        'refactor': 'Changed',
        'docs': 'Documentation',
        'test': 'Testing',
        'chore': 'Maintenance',
        'ci': 'Maintenance',
        'build': 'Maintenance',
    }

    test_commits = [
        "feat(ui): add new fader component",
        "fix(midi): resolve UMP reconstruction bug",
        "chore(deps): update dependencies",
        "docs(readme): update installation instructions",
        "test(unit): add unit tests for MidiEvent",
        "refactor(core): improve state management",
        "perf(midi): reduce latency by 20%",
        "ci(workflow): optimize build pipeline",
        "Random commit without conventional format",
    ]

    for commit in test_commits:
        match = pattern.match(commit)
        if match:
            commit_type = match.group(1)
            desc = match.group(3)
            section = section_map.get(commit_type.lower(), 'Other')
            print_ok(f"'{commit}'")
            print(f"       -> Section: {section}, Description: {desc}")
        else:
            print_warn(f"'{commit}' -> No match (will use raw format)")

    print()


# Test 5: Commit link generation
def test_commit_link_generation() -> None:
    """Test commit link generation for release notes."""
    print_section("Test 5: Commit Link Generation")
    print("Testing commit link format: [hash](url)\n")

    # Simulate GitHub context
    server_url = "https://github.com"
    repo = "dencelkbabu/OpenMIDIControl"
    
    test_hashes = [
        "abc1234",
        "def5678",
        "1234567",
    ]
    
    print(f"Repository: {repo}")
    print(f"Server URL: {server_url}\n")
    
    for commit_hash in test_hashes:
        expected_link = f"[{commit_hash}]({server_url}/{repo}/commit/{commit_hash})"
        expected_md = f"- Array bounds crash {expected_link}"
        
        # Simulate the bash logic
        desc = "Array bounds crash"
        generated_md = f"- {desc} [{commit_hash}]({server_url}/{repo}/commit/{commit_hash})"
        
        if generated_md == expected_md:
            print_ok(f"Generated: {generated_md}")
        else:
            print_fail(f"Expected: {expected_md}")
            print(f"         Got: {generated_md}")
    
    print()


# Test 6: Git log retrieval
def test_git_log_retrieval() -> None:
    """Test git log retrieval."""
    print_section("Test 6: Git Log Retrieval")

    try:
        # Check if inside git repository
        result = subprocess.run(
            ['git', 'rev-parse', '--git-dir'],
            capture_output=True,
            text=True
        )

        if result.returncode == 0:
            print_ok("Inside git repository")
            print("  Recent commits:")

            result = subprocess.run(
                ['git', 'log', '--oneline', '-5', '--no-decorate'],
                capture_output=True,
                text=True
            )

            if result.returncode == 0:
                for line in result.stdout.strip().split('\n'):
                    print(f"    - {line}")
            else:
                print_error("Failed to retrieve git log")
        else:
            print_error("Not a git repository")
    except Exception as e:
        print_error(f"Git command failed: {e}")

    print()


# Test 7: Tag detection
def test_tag_detection() -> Optional[Tuple[str, int, str]]:
    """Test git tag detection."""
    print_section("Test 7: Git Tag Detection")

    try:
        # Get latest production tag
        result = subprocess.run(
            ['git', 'describe', '--tags', '--match=v[0-9]*.[0-9]*.[0-9]*', '--abbrev=0'],
            capture_output=True,
            text=True
        )

        if result.returncode == 0 and result.stdout.strip():
            latest_tag = result.stdout.strip()
            print_ok(f"Latest production tag: {latest_tag}")

            # Get commits since last tag
            result = subprocess.run(
                ['git', 'rev-list', '--count', f'{latest_tag}..HEAD'],
                capture_output=True,
                text=True
            )

            if result.returncode == 0:
                beta_num = int(result.stdout.strip())
                print_ok(f"Commits since last tag: {beta_num}")

                version = latest_tag.lstrip('v')
                beta_tag = f"v{version}-beta.{beta_num}"
                print_ok(f"Generated beta tag would be: {beta_tag}")

                return latest_tag, beta_num, beta_tag
        else:
            print_warn("No production tags found (first release)")
    except Exception as e:
        print_error(f"Git command failed: {e}")

    return None


# Test 8: Simulate release notes generation
def test_release_notes_generation(tag_info: Optional[Tuple[str, int, str]]) -> None:
    """Simulate beta release notes generation."""
    print_section("Test 8: Simulated Beta Release Notes Generation")
    print("=" * 47)

    if not tag_info:
        # Try to get any tag
        try:
            result = subprocess.run(
                ['git', 'describe', '--tags', '--abbrev=0'],
                capture_output=True,
                text=True
            )

            if result.returncode == 0 and result.stdout.strip():
                latest_tag = result.stdout.strip()
                tag_info = (latest_tag, 1, f"{latest_tag}-beta.1")
        except Exception:
            pass

    if tag_info:
        latest_tag, beta_num, beta_tag = tag_info
        print(f"Simulating tag: {beta_tag}\n")

        # Get previous tag
        try:
            result = subprocess.run(
                ['git', 'describe', '--tags', '--abbrev=0', f'{beta_tag}^'],
                capture_output=True,
                text=True
            )

            if result.returncode == 0 and result.stdout.strip():
                prev_tag = result.stdout.strip()
            else:
                prev_tag = latest_tag
        except Exception:
            prev_tag = latest_tag

        print(f"Previous tag: {prev_tag}")
        print("\nRelease Notes Preview (with commit links):")
        print("-" * 47)
        print("🚧 **Beta Release** - This is a release candidate for testing.\n")
        print(f"### Changes since {prev_tag}\n")

        # Get commits between tags
        try:
            result = subprocess.run(
                ['git', 'log', '--pretty=format:%h|%s', f'{prev_tag}..HEAD'],
                capture_output=True,
                text=True
            )

            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')[:10]  # Limit to 10
                
                server_url = "https://github.com"
                repo = "dencelkbabu/OpenMIDIControl"

                pattern = re.compile(r'^([a-zA-Z]+)(\([a-zA-Z0-9/_-]+\))?:\s+(.+)$')
                
                non_conventional_commits = []

                for line in lines:
                    if '|' in line:
                        commit_hash, commit_msg = line.split('|', 1)
                        match = pattern.match(commit_msg)
                        if match:
                            commit_type = match.group(1)
                            desc = match.group(3)
                            commit_link = f"[{commit_hash}]({server_url}/{repo}/commit/{commit_hash})"
                            print(f"  - [{commit_type}] {desc} {commit_link}")
                        else:
                            # Non-conventional commit - track it
                            non_conventional_commits.append((commit_hash, commit_msg))
                            commit_link = f"[{commit_hash}]({server_url}/{repo}/commit/{commit_hash})"
                            print(f"  - {commit_msg} {commit_link}")
                
                # Warn about non-conventional commits found
                if non_conventional_commits:
                    print(f"\n{Colors.YELLOW}[WARN] Found {len(non_conventional_commits)} non-conventional commit(s):{Colors.RESET}")
                    for commit_hash, commit_msg in non_conventional_commits:
                        print(f"       - {commit_hash}: \"{commit_msg}\"")
                    print(f"\n{Colors.YELLOW}       Consider rewriting these commits to follow conventional commit format:{Colors.RESET}")
                    print(f"       {Colors.BOLD}type(scope): description{Colors.RESET}")
                    print(f"       Example: {Colors.GREEN}fix(midi): resolve UMP reconstruction bug{Colors.RESET}")
        except Exception as e:
            print_error(f"Failed to get commits: {e}")
    else:
        print("[No previous tag found - would show all commits]")

    print()


def main() -> int:
    """Main entry point."""
    print_header("Testing Release Notes Generation Logic")

    # Run all tests
    test_beta_tag_detection()
    test_commit_marker_detection()
    test_auto_release_threshold()
    test_conventional_commit_parsing()
    test_commit_link_generation()
    test_git_log_retrieval()
    tag_info = test_tag_detection()
    test_release_notes_generation(tag_info)

    print_header("Test Complete")

    return 0


if __name__ == "__main__":
    exit(main())

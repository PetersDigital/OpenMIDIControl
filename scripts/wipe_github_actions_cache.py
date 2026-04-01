#!/usr/bin/env python3
"""
GitHub Actions Cache Wiper for OpenMIDIControl

Deletes all GitHub Actions caches from the repository.
Useful for cleaning up stale caches after dependency updates or starting fresh.

Usage:
    python scripts/wipe_github_actions_cache.py [--dry-run]

Requirements:
    - GitHub CLI (gh) must be installed and authenticated
    - Must have write permissions on the repository

Examples:
    # Preview what would be deleted
    python scripts/wipe_github_actions_cache.py --dry-run

    # Actually delete all caches
    python scripts/wipe_github_actions_cache.py
"""

# Copyright (c) 2026 Peters Digital
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import os
import sys
import subprocess
import argparse
from typing import List


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
    print(f"\n{Colors.CYAN}{'=' * 60}{Colors.RESET}")
    print(f"{Colors.CYAN}{text.center(60)}{Colors.RESET}")
    print(f"{Colors.CYAN}{'=' * 60}{Colors.RESET}\n")


def print_error(text: str) -> None:
    """Print an error message."""
    print(f"{Colors.RED}❌ {text}{Colors.RESET}")


def print_success(text: str) -> None:
    """Print a success message."""
    print(f"{Colors.GREEN}✓ {text}{Colors.RESET}")


def print_info(text: str) -> None:
    """Print an info message."""
    print(f"{Colors.YELLOW}ℹ {text}{Colors.RESET}")


def print_warning(text: str) -> None:
    """Print a warning message."""
    print(f"{Colors.YELLOW}⚠ {text}{Colors.RESET}")


def check_gh_installed() -> bool:
    """Check if GitHub CLI is installed."""
    try:
        subprocess.run(['gh', '--version'], capture_output=True, check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False


def get_repository() -> str:
    """Get the current repository in owner/name format."""
    try:
        result = subprocess.run(
            ['gh', 'repo', 'view', '--json', 'nameWithOwner', '--jq', '.nameWithOwner'],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return 'PetersDigital/OpenMIDIControl'


def get_caches(repo: str) -> List[str]:
    """
    Get all cache IDs using GitHub CLI.

    Args:
        repo: Repository in owner/name format

    Returns:
        List of cache IDs
    """
    try:
        result = subprocess.run(
            [
                'gh', 'api',
                f'repos/{repo}/actions/caches',
                '--paginate',
                '--jq', '.actions_caches[].id'
            ],
            capture_output=True,
            text=True,
            check=True
        )

        return [line.strip() for line in result.stdout.splitlines() if line.strip()]

    except subprocess.CalledProcessError as e:
        print_error(f"Failed to get caches: {e}")
        return []


def delete_cache(cache_id: str, repo: str, dry_run: bool = False) -> bool:
    """
    Delete a single cache.

    Args:
        cache_id: The cache ID to delete
        repo: Repository in owner/name format
        dry_run: If True, only preview the deletion

    Returns:
        True if successful, False otherwise
    """
    if dry_run:
        print_info(f"Would delete cache {cache_id}")
        return True

    try:
        subprocess.run(
            [
                'gh', 'api',
                f'repos/{repo}/actions/caches/{cache_id}',
                '-X', 'DELETE'
            ],
            capture_output=True,
            text=True,
            check=True
        )
        return True

    except subprocess.CalledProcessError as e:
        print_error(f"Failed to delete cache {cache_id}: {e}")
        return False


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Delete all GitHub Actions caches",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python scripts/wipe_github_actions_cache.py --dry-run   # Preview what would be deleted
  python scripts/wipe_github_actions_cache.py             # Actually delete all caches
        """
    )

    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Preview what would be deleted without actually deleting'
    )

    args = parser.parse_args()

    print_header("GitHub Actions Cache Wiper")

    # Check if gh is installed
    if not check_gh_installed():
        print_error("GitHub CLI (gh) not found")
        print_info("Install from: https://cli.github.com/")
        return 1

    # Check if authenticated
    try:
        subprocess.run(['gh', 'auth', 'status'], capture_output=True, check=True)
    except subprocess.CalledProcessError:
        print_error("Not authenticated with GitHub CLI")
        print_info("Run 'gh auth login' to authenticate")
        return 1

    # Get repository
    repo = get_repository()
    print_info(f"Repository: {repo}\n")

    # Get all caches
    print("Fetching caches...")
    cache_ids = get_caches(repo)

    if not cache_ids:
        print_success("No caches found")
        return 0

    print(f"Found {len(cache_ids)} cache(s)\n")

    if args.dry_run:
        print_warning("DRY RUN - No deletions will be performed\n")

    # Confirm deletion
    if not args.dry_run:
        response = input(f"{Colors.RED}Are you sure you want to delete {len(cache_ids)} cache(s)? [y/N]: {Colors.RESET}")
        if response.lower() != 'y':
            print("\nCancelled by user")
            return 0
        print()

    # Delete caches
    deleted = 0
    failed = 0

    for cache_id in cache_ids:
        if delete_cache(cache_id, repo, args.dry_run):
            deleted += 1
            if not args.dry_run:
                print(f"  {Colors.GREEN}✓{Colors.RESET} Deleted cache {cache_id}")
        else:
            failed += 1

    # Summary
    print_header("Summary")
    if args.dry_run:
        print(f"Would delete: {deleted} cache(s)")
    else:
        print(f"Deleted: {deleted} cache(s)")
        if failed > 0:
            print(f"Failed: {failed} cache(s)")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
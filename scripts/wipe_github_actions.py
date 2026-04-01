#!/usr/bin/env python3
"""
GitHub Actions Run History Wiper for OpenMIDIControl

Deletes all workflow runs from the repository.
Useful for cleaning up test runs or starting fresh.

Usage:
    python scripts/wipe_github_actions.py [--dry-run]

Requirements:
    - GitHub CLI (gh) must be installed and authenticated
    - Must have write permissions on the repository

Examples:
    # Preview what would be deleted
    python scripts/wipe_github_actions.py --dry-run

    # Actually delete all runs
    python scripts/wipe_github_actions.py
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


def get_workflow_runs() -> List[str]:
    """
    Get all workflow run IDs using GitHub CLI.
    
    Returns:
        List of run IDs
    """
    try:
        result = subprocess.run(
            ['gh', 'api', 'repos/PetersDigital/OpenMIDIControl/actions/runs',
             '--paginate', '--jq', '.workflow_runs[].id'],
            capture_output=True,
            text=True,
            check=True
        )
        
        run_ids = [line.strip() for line in result.stdout.splitlines() if line.strip()]
        return run_ids
    except subprocess.CalledProcessError as e:
        print_error(f"Failed to get workflow runs: {e}")
        return []


def delete_workflow_run(run_id: str, dry_run: bool = False) -> bool:
    """
    Delete a single workflow run.
    
    Returns:
        True if successful, False otherwise
    """
    if dry_run:
        print_info(f"Would delete run {run_id}")
        return True
    
    try:
        subprocess.run(
            ['gh', 'api', 'repos/PetersDigital/OpenMIDIControl/actions/runs/' + run_id,
             '-X', 'DELETE'],
            capture_output=True,
            text=True,
            check=True
        )
        return True
    except subprocess.CalledProcessError as e:
        print_error(f"Failed to delete run {run_id}: {e}")
        return False


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Delete all GitHub Actions workflow runs",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python scripts/wipe_github_actions.py --dry-run   # Preview what would be deleted
  python scripts/wipe_github_actions.py             # Actually delete all runs
        """
    )
    
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Preview what would be deleted without actually deleting'
    )
    
    args = parser.parse_args()
    
    print_header("GitHub Actions Run Wiper")
    
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
    
    # Get all workflow runs
    print("Fetching workflow runs...")
    run_ids = get_workflow_runs()
    
    if not run_ids:
        print_success("No workflow runs found")
        return 0
    
    print(f"Found {len(run_ids)} workflow run(s)\n")
    
    if args.dry_run:
        print_warning("DRY RUN - No deletions will be performed\n")
    
    # Confirm deletion
    if not args.dry_run:
        response = input(f"{Colors.RED}Are you sure you want to delete {len(run_ids)} run(s)? [y/N]: {Colors.RESET}")
        if response.lower() != 'y':
            print("\nCancelled by user")
            return 0
        print()
    
    # Delete runs
    deleted = 0
    failed = 0
    
    for run_id in run_ids:
        if delete_workflow_run(run_id, args.dry_run):
            deleted += 1
            if not args.dry_run:
                print(f"  {Colors.GREEN}✓{Colors.RESET} Deleted run {run_id}")
        else:
            failed += 1
    
    # Summary
    print_header("Summary")
    if args.dry_run:
        print(f"Would delete: {deleted} run(s)")
    else:
        print(f"Deleted: {deleted} run(s)")
        if failed > 0:
            print(f"Failed: {failed} run(s)")
    
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
License Header Checker for OpenMIDIControl

Checks all source files for proper license headers.
Returns exit code 1 if any files are missing headers.

Usage:
    python scripts/check_license_headers.py

Usage:
    python scripts/check_license_headers.py
"""

# Copyright (c) 2026 Peters Digital
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import os
import sys
import re
from pathlib import Path
from typing import List, Tuple


class Colors:
    """ANSI color codes for terminal output."""
    CYAN = '\033[96m'
    YELLOW = '\033[93m'
    GREEN = '\033[92m'
    RED = '\033[91m'
    WHITE = '\033[97m'
    RESET = '\033[0m'


def print_header(text: str) -> None:
    """Print a colored header."""
    print(f"\n{Colors.CYAN}=== {text} ==={Colors.RESET}")


def print_section(text: str) -> None:
    """Print a section header."""
    print(f"\n{Colors.WHITE}{text}{Colors.RESET}")


def print_success(text: str) -> None:
    """Print a success message."""
    print(f"{Colors.GREEN}✓ {text}{Colors.RESET}")


def print_error(text: str) -> None:
    """Print an error message."""
    print(f"{Colors.RED}✗ {text}{Colors.RESET}")


def has_license_header(content: str) -> bool:
    """Check if content has a proper license header."""
    has_copyright = re.search(r'Copyright \(c\) \d{4} Peters Digital', content)
    has_spdx = re.search(r'SPDX-License-Identifier: GPL-3\.0-or-later OR LicenseRef-Commercial', content)
    return bool(has_copyright and has_spdx)


def check_files(
    root: Path,
    pattern: str,
    exclude_patterns: List[str] = None
) -> Tuple[int, int]:
    """
    Check files matching pattern for license headers.
    
    Returns:
        Tuple of (total_files, missing_count)
    """
    if exclude_patterns is None:
        exclude_patterns = []
    
    total = 0
    missing = 0
    
    for filepath in root.rglob(pattern):
        # Skip excluded paths
        if any(exclude in str(filepath) for exclude in exclude_patterns):
            continue
        
        try:
            with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            total += 1
            
            if not has_license_header(content):
                print_error(f"[MISS] {filepath}")
                missing += 1
        except Exception as e:
            print_error(f"[ERROR] {filepath}: {e}")
    
    return total, missing


def main() -> int:
    """Main entry point."""
    print_header("License Header Check")
    
    root = Path(__file__).parent.parent
    print(f"Root: {root}\n")
    
    total_files = 0
    missing_count = 0
    
    # Check Dart files
    print_section("Checking Dart files...")
    dart_total, dart_missing = check_files(
        root,
        "*.dart",
        exclude_patterns=['build/', '.dart_tool/', '.g.dart', '.freezed.dart']
    )
    total_files += dart_total
    missing_count += dart_missing
    
    # Check Kotlin files
    print_section("Checking Kotlin files...")
    kotlin_total, kotlin_missing = check_files(
        root,
        "*.kt",
        exclude_patterns=['build/']
    )
    total_files += kotlin_total
    missing_count += kotlin_missing
    
    # Check PowerShell scripts
    print_section("Checking PowerShell scripts...")
    ps_total, ps_missing = check_files(
        root,
        "*.ps1",
        exclude_patterns=['build/', 'node_modules/', 'vendor/']
    )
    total_files += ps_total
    missing_count += ps_missing
    
    # Check YAML files (workflows and actions only)
    print_section("Checking YAML files (workflows/actions)...")
    yaml_total, yaml_missing = check_files(
        root / ".github",
        "*.yml",
        exclude_patterns=[]
    )
    total_files += yaml_total
    missing_count += yaml_missing
    
    # Check Python scripts
    print_section("Checking Python scripts...")
    py_total, py_missing = check_files(
        root,
        "*.py",
        exclude_patterns=['build/', '__pycache__/']
    )
    total_files += py_total
    missing_count += py_missing
    
    # Summary
    print_header("Summary")
    print(f"Total files checked: {total_files}")
    print(f"Missing headers: {missing_count}")
    
    if missing_count > 0:
        print(f"\n{Colors.YELLOW}Run 'python scripts/add_license_headers.py' to add missing headers.{Colors.RESET}")
        return 1
    else:
        print(f"\n{Colors.GREEN}All files have proper license headers!{Colors.RESET}")
        return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
License Header Adder for OpenMIDIControl

Adds license headers to all source files that are missing them.

Usage:
    python scripts/add_license_headers.py
"""

# Copyright (c) 2026 Peters Digital
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import os
import sys
import re
from pathlib import Path
from typing import List, Optional


class Colors:
    """ANSI color codes for terminal output."""
    CYAN = '\033[96m'
    YELLOW = '\033[93m'
    GREEN = '\033[92m'
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
    print(f"{Colors.GREEN}[ADD] {text}{Colors.RESET}")


def print_skip(text: str) -> None:
    """Print a skip message."""
    print(f"{Colors.YELLOW}[SKIP] {text}{Colors.RESET}")


# Header templates for different file types
DART_HEADER = """// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

"""

KOTLIN_HEADER = """// Copyright (c) 2026 Peters Digital
// SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

"""

POWERSHELL_HEADER = """# Copyright (c) 2026 Peters Digital
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

"""

YAML_HEADER = """# Copyright (c) 2026 Peters Digital
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial
"""

PYTHON_HEADER = """# Copyright (c) 2026 Peters Digital
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

"""

SHELL_HEADER = """# Copyright (c) 2026 Peters Digital
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

"""


def has_license_header(content: str) -> bool:
    """Check if content has a proper license header."""
    has_copyright = re.search(r'Copyright \(c\) \d{4} Peters Digital', content)
    has_spdx = re.search(r'SPDX-License-Identifier: GPL-3\.0-or-later OR LicenseRef-Commercial', content)
    return bool(has_copyright and has_spdx)


def add_header_to_file(filepath: Path, header: str) -> bool:
    """
    Add header to a file, preserving shebang if present.
    
    Returns:
        True if successful, False otherwise
    """
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check if already has header
        if has_license_header(content):
            return False
        
        lines = content.splitlines(keepends=True)
        
        # Handle shebang
        if lines and lines[0].startswith('#!'):
            # Keep shebang first, then add header
            new_content = lines[0] + header + ''.join(lines[1:])
        else:
            new_content = header + content
        
        # Write back without BOM
        with open(filepath, 'w', encoding='utf-8', newline='\n') as f:
            f.write(new_content)
        
        return True
    except Exception as e:
        print(f"{Colors.RED}[ERROR] {filepath}: {e}{Colors.RESET}")
        return False


def process_files(
    root: Path,
    pattern: str,
    header: str,
    exclude_patterns: List[str] = None
) -> int:
    """
    Process files matching pattern, adding headers where missing.
    
    Returns:
        Number of files modified
    """
    if exclude_patterns is None:
        exclude_patterns = []
    
    modified_count = 0
    
    for filepath in root.rglob(pattern):
        # Normalize path separators for cross-platform exclude matching
        filepath_str = str(filepath).replace('\\', '/')

        # Skip excluded paths
        if any(exclude in filepath_str for exclude in exclude_patterns):
            continue
        
        if add_header_to_file(filepath, header):
            print_success(filepath)
            modified_count += 1
        else:
            print_skip(filepath.name)
    
    return modified_count


def main() -> int:
    """Main entry point."""
    print_header("Adding License Headers (Comprehensive)")
    
    root = Path(__file__).parent.parent
    print(f"Root: {root}")
    
    total_modified = 0
    
    # Process PowerShell scripts
    print_section("Processing PowerShell scripts...")
    ps_modified = process_files(
        root,
        "*.ps1",
        POWERSHELL_HEADER,
        exclude_patterns=['build/', 'node_modules/', 'vendor/', '.dart_tool/']
    )
    total_modified += ps_modified
    
    # Process YAML files (workflows and actions)
    print_section("Processing YAML files (workflows/actions)...")
    yaml_modified = process_files(
        root / ".github",
        "*.yml",
        YAML_HEADER,
        exclude_patterns=[]
    )
    total_modified += yaml_modified
    
    # Process Dart files
    print_section("Processing Dart files...")
    dart_modified = process_files(
        root,
        "*.dart",
        DART_HEADER,
        exclude_patterns=['build/', '.dart_tool/', '.g.dart', '.freezed.dart']
    )
    total_modified += dart_modified
    
    # Process Kotlin files
    print_section("Processing Kotlin files...")
    kotlin_modified = process_files(
        root,
        "*.kt",
        KOTLIN_HEADER,
        exclude_patterns=['build/']
    )
    total_modified += kotlin_modified
    
    # Process Python files
    print_section("Processing Python files...")
    py_modified = process_files(
        root,
        "*.py",
        PYTHON_HEADER,
        exclude_patterns=['build/', '__pycache__/']
    )
    total_modified += py_modified
    
    # Process shell scripts
    print_section("Processing shell scripts...")
    sh_modified = process_files(
        root,
        "*.sh",
        SHELL_HEADER,
        exclude_patterns=['build/', 'node_modules/']
    )
    total_modified += sh_modified
    
    # Summary
    print_header("Complete")
    print(f"Total headers added: {total_modified}")
    print(f"\n{Colors.YELLOW}Note: pubspec.yaml and analysis_options.yaml excluded (simple config files){Colors.RESET}")
    
    return 0


if __name__ == "__main__":
    sys.exit(main())

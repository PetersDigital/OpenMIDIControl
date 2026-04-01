#!/usr/bin/env python3
"""
CHANGELOG.md Auto-Generator

Generates or updates CHANGELOG.md from git log using conventional commit format.
This script ensures the CHANGELOG.md stays in sync with actual git history.

Usage:
    python scripts/update_changelog.py [version]
    
Examples:
    python scripts/update_changelog.py           # Auto-detect version from git tags
    python scripts/update_changelog.py 0.2.3     # Generate for specific version
"""

# Copyright (c) 2026 Peters Digital
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import subprocess
import re
import sys
from pathlib import Path
from typing import Optional, Dict, List, Tuple
from datetime import datetime


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


def print_success(text: str) -> None:
    """Print a success message."""
    print(f"  {Colors.GREEN}✓{Colors.RESET} {text}")


def print_error(text: str) -> None:
    """Print an error message."""
    print(f"  {Colors.RED}✗{Colors.RESET} {text}")


def print_warn(text: str) -> None:
    """Print a warning message."""
    print(f"  {Colors.YELLOW}⚠{Colors.RESET} {text}")


def get_git_log(from_ref: str, to_ref: str = "HEAD") -> List[Tuple[str, str]]:
    """
    Get git log as list of (hash, message) tuples.
    
    Args:
        from_ref: Starting git reference (tag or commit)
        to_ref: Ending git reference (default: HEAD)
    
    Returns:
        List of (commit_hash, commit_message) tuples
    """
    try:
        result = subprocess.run(
            ['git', 'log', '--pretty=format:%h|%s', f'{from_ref}..{to_ref}'],
            capture_output=True,
            text=True,
            check=True
        )
        
        if not result.stdout.strip():
            return []
        
        commits = []
        for line in result.stdout.strip().split('\n'):
            if '|' in line:
                commit_hash, message = line.split('|', 1)
                commits.append((commit_hash, message))
        
        return commits
    except subprocess.CalledProcessError as e:
        print_error(f"Git command failed: {e}")
        return []


def parse_conventional_commit(message: str) -> Optional[Tuple[str, str]]:
    """
    Parse a conventional commit message.
    
    Args:
        message: Commit message (e.g., "feat(ui): add fader")
    
    Returns:
        Tuple of (type, description) or None if not conventional
    """
    pattern = re.compile(r'^([a-zA-Z]+)(\([a-zA-Z0-9/_-]+\))?:\s+(.+)$')
    match = pattern.match(message)
    
    if match:
        commit_type = match.group(1).lower()
        description = match.group(3)
        return (commit_type, description)
    
    return None


def categorize_commits(commits: List[Tuple[str, str]]) -> Dict[str, List[Tuple[str, str, str]]]:
    """
    Categorize commits by type following Keep a Changelog (SemVer) standard.

    Standard sections: Merged, Added, Changed, Deprecated, Removed, Fixed, Security, Other
    Note: 'Merged' section is for merge commits (e.g., "merge(main/release): v0.2.2") 
    and appears first to highlight the main milestone/PR merge.

    Args:
        commits: List of (hash, message) tuples

    Returns:
        Dict mapping section names to list of (hash, type, description) tuples
    """
    sections: Dict[str, List[Tuple[str, str, str]]] = {
        'Merged': [],
        'Added': [],
        'Changed': [],
        'Deprecated': [],
        'Removed': [],
        'Fixed': [],
        'Security': [],
        'Other': [],
    }

    # Map conventional commit types to SemVer changelog sections (Keep a Changelog standard)
    type_to_section = {
        'feat': 'Added',
        'feature': 'Added',
        'fix': 'Fixed',
        'perf': 'Changed',
        'refactor': 'Changed',
        'restyle': 'Changed',
        'docs': 'Changed',
        'style': 'Changed',
        'test': 'Changed',
        'chore': 'Changed',
        'ci': 'Changed',
        'build': 'Changed',
        'deprecate': 'Deprecated',
        'remove': 'Removed',
        'del': 'Removed',
        'delete': 'Removed',
        'merge': 'Merged',  # Merge commits for major milestones (appears first)
    }

    for commit_hash, message in commits:
        parsed = parse_conventional_commit(message)

        if parsed:
            commit_type, description = parsed
            section = type_to_section.get(commit_type, None)

            # Security fixes go to Security section
            if commit_type == 'fix' and any(kw in message.lower() for kw in ['security', 'vulnerability', 'exploit', 'injection', 'cve']):
                section = 'Security'

            # Map to section or Other
            if section:
                sections[section].append((commit_hash, commit_type, description))
            else:
                sections['Other'].append((commit_hash, commit_type, description))
        else:
            # Non-conventional commits - try to infer from message keywords
            message_lower = message.lower()
            if any(kw in message_lower for kw in ['add', 'new', 'create', 'implement']):
                sections['Added'].append((commit_hash, '', message))
            elif any(kw in message_lower for kw in ['fix', 'bug', 'crash', 'error', 'resolve']):
                sections['Fixed'].append((commit_hash, '', message))
            elif any(kw in message_lower for kw in ['change', 'update', 'improve', 'refactor', 'move']):
                sections['Changed'].append((commit_hash, '', message))
            elif any(kw in message_lower for kw in ['deprecat', 'obsolete']):
                sections['Deprecated'].append((commit_hash, '', message))
            elif any(kw in message_lower for kw in ['remov', 'delete', 'drop']):
                sections['Removed'].append((commit_hash, '', message))
            elif any(kw in message_lower for kw in ['security', 'vulnerability', 'exploit']):
                sections['Security'].append((commit_hash, '', message))
            else:
                # Unmatched commits go to Other
                sections['Other'].append((commit_hash, '', message))

    return sections


def format_changelog_entry(commit_hash: str, commit_type: str, description: str, include_links: bool = True) -> str:
    """
    Format a single changelog entry.

    Note: Does NOT include the commit type prefix (e.g., "feat:", "fix:")
    as per Keep a Changelog standard - only the description and link.
    Capitalizes the first letter of the description.

    Args:
        commit_hash: Git commit hash (short form)
        commit_type: Conventional commit type (e.g., 'feat', 'fix') - NOT used in output
        description: Commit description
        include_links: Whether to include GitHub commit links

    Returns:
        Formatted markdown entry with capitalized first letter
    """
    repo = get_repo_slug()
    server_url = "https://github.com"

    # Capitalize first letter of description
    if description:
        description = description[0].upper() + description[1:]

    if include_links and repo:
        commit_link = f"[{commit_hash}]({server_url}/{repo}/commit/{commit_hash})"
        return f"- {description} {commit_link}"
    else:
        return f"- {description}"


def get_repo_slug() -> Optional[str]:
    """Get the repository slug (owner/repo) from git remote."""
    try:
        result = subprocess.run(
            ['git', 'config', '--get', 'remote.origin.url'],
            capture_output=True,
            text=True,
            check=True
        )
        
        url = result.stdout.strip()
        
        # Handle GitHub URLs
        if 'github.com:' in url:
            # SSH: git@github.com:owner/repo.git
            parts = url.split('github.com:')
            if len(parts) > 1:
                repo = parts[1].replace('.git', '')
                return repo
        elif 'github.com/' in url:
            # HTTPS: https://github.com/owner/repo.git
            parts = url.split('github.com/')
            if len(parts) > 1:
                repo = parts[1].replace('.git', '')
                return repo
    except Exception:
        pass
    
    return None


def get_latest_tag() -> Optional[str]:
    """Get the latest git tag."""
    try:
        result = subprocess.run(
            ['git', 'describe', '--tags', '--abbrev=0'],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None


def get_previous_tag(current_tag: str) -> Optional[str]:
    """Get the tag before the specified tag."""
    try:
        result = subprocess.run(
            ['git', 'describe', '--tags', '--abbrev=0', f'{current_tag}^'],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        # No previous tag - this is the first release
        result = subprocess.run(
            ['git', 'rev-list', '--max-parents=0', 'HEAD'],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()


def generate_changelog_section(section_name: str, commits: List[Tuple[str, str, str]], include_links: bool = True) -> str:
    """
    Generate a changelog section.

    Args:
        section_name: Section name (e.g., 'Added', 'Fixed')
        commits: List of (hash, type, description) tuples
        include_links: Whether to include commit links

    Returns:
        Formatted markdown section with one blank line after for separation
    """
    if not commits:
        return ""

    lines = [f"### {section_name}"]

    for commit_hash, commit_type, description in commits:
        entry = format_changelog_entry(commit_hash, commit_type, description, include_links)
        lines.append(entry)

    # Two empty strings to create a blank line (newline + blank line + newline for next section)
    lines.extend(["", ""])
    return '\n'.join(lines)


def update_changelog(version: Optional[str], include_links: bool = True) -> bool:
    """
    Update CHANGELOG.md with a new version entry or [Unreleased] section.
    
    Args:
        version: Version number (without 'v' prefix, e.g., '0.2.3') or None for [Unreleased]
        include_links: Whether to include GitHub commit links
    
    Returns:
        True if successful, False otherwise
    """
    repo_slug = get_repo_slug() or "owner/repo"
    
    if version is None:
        # [Unreleased] section - changes from last tag to HEAD
        latest_tag = get_latest_tag()
        if not latest_tag:
            print_error("No tags found. Cannot generate [Unreleased] section.")
            return False
        
        previous_tag = latest_tag
        section_title = "## [Unreleased]"
        changelog_link = f"[Full Changelog](https://github.com/{repo_slug}/compare/{previous_tag}...HEAD)"
        date_str = None
    else:
        # Versioned release
        current_tag = f"v{version}"
        previous_tag = get_previous_tag(current_tag)
        
        if not previous_tag:
            print_error(f"Could not find previous tag for {current_tag}")
            return False
        
        section_title = f"## [{version}] - {datetime.now().strftime('%Y-%m-%d')}"
        changelog_link = f"[Full Changelog](https://github.com/{repo_slug}/compare/{previous_tag}...{current_tag})"
        date_str = datetime.now().strftime("%Y-%m-%d")
    
    print_success(f"Generating changelog for {section_title} (since {previous_tag})")
    
    # Get commits
    commits = get_git_log(previous_tag, "HEAD")
    
    if not commits:
        print_warn(f"No commits found since {previous_tag}")
        return False
    
    print_success(f"Found {len(commits)} commits")
    
    # Categorize commits
    sections = categorize_commits(commits)

    # Generate changelog entry - ONE blank line after changelog link
    changelog_entry = f"""{section_title}
{changelog_link}

"""

    # Add sections in order (Merged first, then Keep a Changelog standard + Other)
    for section_name in ['Merged', 'Added', 'Changed', 'Deprecated', 'Removed', 'Fixed', 'Security', 'Other']:
        if sections[section_name]:
            changelog_entry += generate_changelog_section(section_name, sections[section_name], include_links)

    # Strip trailing newlines from the last section to avoid extra blank line before next version
    changelog_entry = changelog_entry.rstrip('\n') + '\n'

    # Read existing CHANGELOG.md
    changelog_path = Path("CHANGELOG.md")
    
    if changelog_path.exists():
        existing_content = changelog_path.read_text(encoding='utf-8')
        
        # Find the position after the standard header lines
        # Look for: "The format is based on **Keep a Changelog**, and this project adheres to **Semantic Versioning (SemVer)**."
        header_end_marker = "**Semantic Versioning (SemVer)**."
        header_end_pos = existing_content.find(header_end_marker)
        
        if header_end_pos != -1:
            # Find the end of that line (including newlines after it)
            newline_after_header = existing_content.find('\n', header_end_pos)
            if newline_after_header != -1:
                # Skip any blank lines after the header
                insert_pos = newline_after_header + 1
                while insert_pos < len(existing_content) and existing_content[insert_pos] == '\n':
                    insert_pos += 1
                
                # Insert new entry after the header (with one blank line before existing content)
                new_content = existing_content[:insert_pos] + changelog_entry + '\n' + existing_content[insert_pos:]
            else:
                new_content = existing_content + '\n\n' + changelog_entry
        else:
            # Header not found, prepend to existing content
            new_content = changelog_entry + existing_content
        
        # Update footnote links at the bottom
        new_content = update_footnote_links(new_content, version, repo_slug, previous_tag)
    else:
        # Create new file with header
        new_content = f"""# Changelog

All notable changes to this project will be documented in this file.

The format is based on **Keep a Changelog**, and this project adheres to **Semantic Versioning (SemVer)**.

{changelog_entry}"""
    
    # Write updated content
    changelog_path.write_text(new_content, encoding='utf-8')
    
    print_success(f"Updated {changelog_path}")
    return True


def update_footnote_links(content: str, version: Optional[str], repo_slug: str, previous_tag: str) -> str:
    """
    Update or add footnote-style version links at the bottom of the changelog.
    
    Args:
        content: Current CHANGELOG.md content
        version: Version number (without 'v') or None for [Unreleased]
        repo_slug: Repository slug (owner/repo)
        previous_tag: Previous tag name
    
    Returns:
        Updated content with footnote links
    """
    lines = content.split('\n')
    
    # Find existing footnote links (lines starting with [)
    footnote_start = -1
    for i, line in enumerate(lines):
        if line.startswith('[') and ']:' in line:
            footnote_start = i
            break
    
    if version is None:
        # Add [Unreleased] link
        unreleased_link = f"[Unreleased]: https://github.com/{repo_slug}/compare/{previous_tag}...HEAD"
        
        if footnote_start == -1:
            # No footnotes exist, add at end
            lines.append('')
            lines.append(unreleased_link)
        else:
            # Check if [Unreleased] already exists
            unreleased_exists = any(line.startswith('[Unreleased]:') for line in lines[footnote_start:])
            if not unreleased_exists:
                # Insert at the beginning of footnotes section
                lines.insert(footnote_start, unreleased_link)
    else:
        # Add new version link and update [Unreleased] if it exists
        current_tag = f"v{version}"
        new_version_link = f"[{version}]: https://github.com/{repo_slug}/compare/{previous_tag}...{current_tag}"
        
        if footnote_start == -1:
            # No footnotes exist, add at end
            lines.append('')
            lines.append(new_version_link)
        else:
            # Check if this version already exists
            version_exists = any(line.startswith(f'[{version}]:') for line in lines[footnote_start:])
            if not version_exists:
                # Insert at the beginning of footnotes section (right after [Unreleased] if it exists)
                insert_pos = footnote_start
                # Skip [Unreleased] if it exists, insert after it
                if footnote_start < len(lines) and lines[footnote_start].startswith('[Unreleased]:'):
                    insert_pos = footnote_start + 1
                lines.insert(insert_pos, new_version_link)
            
            # Update [Unreleased] to point to new version
            for i in range(footnote_start, len(lines)):
                if lines[i].startswith('[Unreleased]:'):
                    lines[i] = f"[Unreleased]: https://github.com/{repo_slug}/compare/{current_tag}...HEAD"
                    break
    
    return '\n'.join(lines)


def main() -> int:
    """Main entry point."""
    print_header("CHANGELOG.md Auto-Generator")
    
    # Check if inside git repository
    try:
        subprocess.run(
            ['git', 'rev-parse', '--git-dir'],
            capture_output=True,
            check=True
        )
    except subprocess.CalledProcessError:
        print_error("Not a git repository")
        return 1
    
    # Get all tags sorted by version
    try:
        result = subprocess.run(
            ['git', 'tag', '--sort=-v:refname'],
            capture_output=True,
            text=True,
            check=True
        )
        
        if result.returncode == 0 and result.stdout.strip():
            all_tags = [tag.strip() for tag in result.stdout.strip().split('\n') if tag.strip()]
        else:
            all_tags = []
    except subprocess.CalledProcessError:
        all_tags = []
    
    # Determine version
    if len(sys.argv) > 1:
        version = sys.argv[1].lstrip('v')
    elif all_tags:
        # Interactive mode - show available tags
        print(f"{Colors.BOLD}Available tags:{Colors.RESET}")
        for i, tag in enumerate(all_tags[:20], 1):  # Show first 20 tags
            print(f"  {i}. {tag}")
        
        if len(all_tags) > 20:
            print(f"  ... and {len(all_tags) - 20} more")
        
        print()
        print(f"{Colors.BOLD}Options:{Colors.RESET}")
        print(f"  1. Latest tag ({all_tags[0]})")
        print(f"  2. Enter custom version")
        print(f"  3. [Unreleased] - Changes since last tag (not yet released)")
        print(f"  4. Cancel")
        print()
        
        choice = input(f"{Colors.CYAN}Select option (1-4) or enter tag number: {Colors.RESET}").strip()
        
        if choice == '4' or choice.lower() == 'cancel':
            print("Cancelled.")
            return 0
        elif choice == '3' or choice.lower() == 'unreleased':
            # Generate [Unreleased] section from last tag to HEAD
            version = None  # Signal for unreleased
            print_success("Generating [Unreleased] section")
        elif choice == '2' or choice.lower() == 'custom':
            version = input(f"{Colors.CYAN}Enter version (e.g., 0.2.3): {Colors.RESET}").strip().lstrip('v')
        elif choice == '1' or choice == '':
            version = all_tags[0].lstrip('v')
            print_success(f"Selected: {version} (from {all_tags[0]})")
        else:
            try:
                tag_index = int(choice) - 1
                if 0 <= tag_index < len(all_tags):
                    version = all_tags[tag_index].lstrip('v')
                    print_success(f"Selected: {version} (from {all_tags[tag_index]})")
                else:
                    print_error(f"Invalid selection. Must be 1-{len(all_tags)}.")
                    return 1
            except ValueError:
                print_error(f"Invalid input: {choice}")
                return 1
    else:
        print_error("No git tags found. Please specify a version:")
        print(f"  {Colors.BOLD}python scripts/update_changelog.py 0.2.3{Colors.RESET}")
        return 1
    
    # Validate that the tag exists (skip for Unreleased)
    if version is not None:
        try:
            result = subprocess.run(
                ['git', 'rev-parse', f'v{version}'],
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                print_error(f"Tag 'v{version}' does not exist in this repository.")
                
                # Suggest similar tags
                similar_tags = [tag for tag in all_tags if version.replace('.', '') in tag.replace('.', '').replace('v', '')]
                if similar_tags:
                    print(f"\n{Colors.YELLOW}Did you mean one of these?{Colors.RESET}")
                    for tag in similar_tags[:5]:
                        print(f"  - {tag}")
                
                return 1
        except Exception:
            pass
    
    # Update changelog
    if update_changelog(version, include_links=True):
        print_header("Success!")
        print(f"\nTip: Review and commit the updated CHANGELOG.md:")
        print(f"  {Colors.BOLD}git add CHANGELOG.md{Colors.RESET}")
        if version:
            print(f"  {Colors.BOLD}git commit -m 'docs(changelog): update for v{version}'{Colors.RESET}\n")
        else:
            print(f"  {Colors.BOLD}git commit -m 'docs(changelog): add unreleased changes'{Colors.RESET}\n")
        return 0
    else:
        print_header("Failed")
        return 1


if __name__ == "__main__":
    sys.exit(main())

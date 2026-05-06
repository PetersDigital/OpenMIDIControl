#!/usr/bin/env python3
"""
Flutter App Launcher for OpenMIDIControl

Interactive script to launch the Flutter app in debug or release mode.
Automatically discovers connected devices and handles release signing configuration.

Usage:
    python scripts/run_app.py [--release]
    python scripts/run_app.py -r  # Short form for --release

Examples:
    # Launch in debug mode (default)
    python scripts/run_app.py

    # Launch in release mode (requires keystore configuration)
    python scripts/run_app.py --release
"""

# Copyright (c) 2026 Peters Digital
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Commercial

import os
import sys
import json
import subprocess
import base64
import argparse
from pathlib import Path
from typing import Optional, Dict, Any, List


class Colors:
    """ANSI color codes for terminal output."""
    CYAN = '\033[96m'
    YELLOW = '\033[93m'
    GREEN = '\033[92m'
    RED = '\033[91m'
    MAGENTA = '\033[95m'
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


def find_flutter_project_root(start_dir: Optional[Path] = None) -> Optional[Path]:
    """
    Find the Flutter project root by searching for pubspec.yaml.
    
    Searches in the current directory and immediate subdirectories.
    """
    if start_dir is None:
        start_dir = Path.cwd()
    
    # Check current directory
    if (start_dir / "pubspec.yaml").exists():
        return start_dir
    
    # Check immediate subdirectories (app/, appname/, etc.)
    for subdir in start_dir.iterdir():
        if subdir.is_dir() and (subdir / "pubspec.yaml").exists():
            return subdir
    
    return None


def get_flutter_devices(flutter_project_dir: Path) -> List[Dict[str, Any]]:
    """
    Get list of available Flutter devices.
    
    Returns:
        List of device dictionaries with id, name, and targetPlatform
    """
    try:
        # Use shell=True on Windows to correctly find flutter.bat
        is_windows = os.name == 'nt'
        result = subprocess.run(
            ['flutter', 'devices', '--machine'],
            cwd=flutter_project_dir,
            capture_output=True,
            text=True,
            check=True,
            shell=is_windows
        )
        
        devices = json.loads(result.stdout)
        if isinstance(devices, dict):
            devices = [devices]
        
        return devices
    except subprocess.CalledProcessError as e:
        print_error(f"Failed to get Flutter devices: {e}")
        return []
    except json.JSONDecodeError as e:
        print_error(f"Failed to parse device output: {e}")
        return []


def select_device(devices: List[Dict[str, Any]]) -> Optional[str]:
    """
    Interactive device selection.
    
    Returns:
    """
    if not devices:
        return None
    
    print(f"\n{Colors.YELLOW}Available devices:{Colors.RESET}")
    for i, device in enumerate(devices):
        device_id = device.get('id', 'unknown')
        device_name = device.get('name', 'unknown')
        platform = device.get('targetPlatform', 'unknown')
        print(f"  [{Colors.BOLD}{i}{Colors.RESET}] {device_name} ({platform})")
    
    print()
    try:
        selection = input(f"{Colors.CYAN}Select a device [0-{len(devices) - 1}]: {Colors.RESET}")
        selection = selection.strip()
        if not selection:
            return None
            
        selected_index = int(selection)
        
        if 0 <= selected_index < len(devices):
            device_id = devices[selected_index].get('id')
            print_success(f"Selected: {devices[selected_index].get('name')} ({device_id})")
            return device_id
        else:
            print_error("Selection out of range")
            return None
    except ValueError:
        print_error("Invalid selection")
        return None
    except KeyboardInterrupt:
        print("\n\nCancelled by user")
        return None


def load_env_file(env_path: Path) -> Dict[str, str]:
    """
    Load environment variables from .env.ps1 file.
    
    Parses PowerShell-style environment variable assignments.
    """
    env_vars = {}
    
    if not env_path.exists():
        return env_vars
    
    try:
        with open(env_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                # Skip comments and empty lines
                if not line or line.startswith('#'):
                    continue
                
                # Parse $env:VAR_NAME="value" or $env:VAR_NAME='value'
                if line.startswith('$env:'):
                    parts = line[5:].split('=', 1)
                    if len(parts) == 2:
                        var_name = parts[0].strip()
                        var_value = parts[1].strip().strip('"\'')
                        env_vars[var_name] = var_value
    except Exception as e:
        print_error(f"Failed to load .env.ps1: {e}")
    
    return env_vars


def setup_release_signing(flutter_project_dir: Path, env_vars: Dict[str, str]) -> bool:
    """
    Set up Android release signing configuration.
    
    Creates upload-keystore.jks and key.properties files.
    """
    required_vars = ['KEYSTORE_BASE64', 'KEY_PASSWORD', 'KEY_ALIAS', 'STORE_PASSWORD']
    
    for var in required_vars:
        if var not in env_vars:
            print_error(f"Missing required variable: {var}")
            return False
    
    android_dir = flutter_project_dir / "android"
    app_dir = android_dir / "app"
    
    if not app_dir.exists():
        print_error(f"Android app directory not found: {app_dir}")
        return False
    
    # Decode and write keystore
    keystore_path = app_dir / "upload-keystore.jks"
    try:
        keystore_bytes = base64.b64decode(env_vars['KEYSTORE_BASE64'])
        with open(keystore_path, 'wb') as f:
            f.write(keystore_bytes)
        print_success(f"Created keystore: {keystore_path}")
    except Exception as e:
        print_error(f"Failed to decode keystore: {e}")
        return False
    
    # Write key.properties
    properties_path = app_dir / "key.properties"
    properties_content = f"""storePassword={env_vars['STORE_PASSWORD']}
keyPassword={env_vars['KEY_PASSWORD']}
keyAlias={env_vars['KEY_ALIAS']}
storeFile=upload-keystore.jks
"""
    
    try:
        with open(properties_path, 'w', encoding='utf-8') as f:
            f.write(properties_content)
        print_success(f"Created key.properties: {properties_path}")
    except Exception as e:
        print_error(f"Failed to write key.properties: {e}")
        return False
    
    return True


def build_flutter_app(
    flutter_project_dir: Path,
    build_type: str,
    release_mode: bool = False
) -> int:
    """
    Build the Flutter app.
    
    Returns:
        Exit code from flutter build command
    """
    cmd = ['flutter', 'build', build_type]
    
    if release_mode:
        cmd.append('--release')
        print(f"\n{Colors.GREEN}📦 Building {Colors.BOLD}{build_type.upper()}{Colors.RESET}{Colors.GREEN} in {Colors.BOLD}RELEASE{Colors.RESET}{Colors.GREEN} mode...{Colors.RESET}")
    else:
        cmd.append('--debug')
        print(f"\n{Colors.GREEN}📦 Building {Colors.BOLD}{build_type.upper()}{Colors.RESET}{Colors.GREEN} in {Colors.BOLD}DEBUG{Colors.RESET}{Colors.GREEN} mode...{Colors.RESET}")
    
    try:
        is_windows = os.name == 'nt'
        return subprocess.call(cmd, cwd=flutter_project_dir, shell=is_windows)
    except Exception as e:
        print_error(f"Failed to build Flutter app: {e}")
        return 1


def run_flutter_app(
    flutter_project_dir: Path,
    device_id: str,
    release_mode: bool = False
) -> int:
    """
    Run the Flutter app on the selected device.
    
    Returns:
        Exit code from flutter run command
    """
    cmd = ['flutter', 'run', '-d', device_id]
    
    if release_mode:
        cmd.append('--release')
        print(f"\n{Colors.GREEN}🚀 Launching in {Colors.BOLD}RELEASE{Colors.RESET}{Colors.GREEN} mode...{Colors.RESET}")
    else:
        print(f"\n{Colors.GREEN}🚀 Launching in {Colors.BOLD}DEBUG{Colors.RESET}{Colors.GREEN} mode...{Colors.RESET}")
    
    try:
        os.chdir(flutter_project_dir)
        if os.name == 'nt':
            # On Windows, subprocess.call with shell=True is more reliable for .bat files
            return subprocess.call(cmd, shell=True)
        else:
            # On Unix, os.execvp is fine and replaces the process
            os.execvp('flutter', cmd)
    except Exception as e:
        print_error(f"Failed to run Flutter app: {e}")
        return 1


def main() -> int:
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="OpenMIDIControl Development Utility",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    parser.add_argument(
        '-r', '--release',
        action='store_true',
        help='Use release mode'
    )
    
    parser.add_argument(
        '-b', '--build',
        choices=['apk', 'appbundle'],
        help='Build the app instead of running it'
    )
    
    args = parser.parse_args()
    
    print_header("OpenMIDIControl Tool")
    
    # Find Flutter project
    flutter_project_dir = find_flutter_project_root()
    
    if not flutter_project_dir:
        print_error("Could not find Flutter project (pubspec.yaml)")
        return 1
    
    print_success(f"Project root: {flutter_project_dir}")
    
    # Interaction flow
    action = None
    release_mode = args.release
    
    if args.build:
        action = 'build'
        build_target = args.build
    elif args.release:
        action = 'run'
    else:
        # Show interactive menu if no flags or just run
        print(f"\n{Colors.YELLOW}What would you like to do?{Colors.RESET}")
        print(f"  [{Colors.BOLD}1{Colors.RESET}] Run App (Debug)")
        print(f"  [{Colors.BOLD}2{Colors.RESET}] Run App (Release)")
        print(f"  [{Colors.BOLD}3{Colors.RESET}] Build APK (Release)")
        print(f"  [{Colors.BOLD}4{Colors.RESET}] Build App Bundle (Release)")
        print(f"  [{Colors.BOLD}5{Colors.RESET}] Build APK (Debug)")
        print(f"  [{Colors.BOLD}q{Colors.RESET}] Quit")
        
        choice = input(f"\n{Colors.CYAN}Selection: {Colors.RESET}").strip().lower()
        
        if choice == '1':
            action = 'run'
            release_mode = False
        elif choice == '2':
            action = 'run'
            release_mode = True
        elif choice == '3':
            action = 'build'
            build_target = 'apk'
            release_mode = True
        elif choice == '4':
            action = 'build'
            build_target = 'appbundle'
            release_mode = True
        elif choice == '5':
            action = 'build'
            build_target = 'apk'
            release_mode = False
        else:
            return 0

    # If release mode or build, check for signing
    if release_mode:
        script_dir = Path(__file__).parent
        env_path = script_dir / ".env.ps1"
        
        if not env_path.exists():
            print_error("Secrets file not found: scripts/.env.ps1")
            print_info("Release builds require signing credentials.")
            return 1
        
        print_info("Loading release signing configuration...")
        env_vars = load_env_file(env_path)
        
        if not env_vars or not setup_release_signing(flutter_project_dir, env_vars):
            print_error("Failed to set up release signing")
            return 1
        
        print_success("Release signing configured!")

    if action == 'run':
        # Get available devices
        print("\nFetching available Flutter devices...")
        devices = get_flutter_devices(flutter_project_dir)
        
        if not devices:
            print_error("No Flutter devices found")
            return 1
        
        device_id = select_device(devices)
        if not device_id:
            return 1
        
        return run_flutter_app(flutter_project_dir, device_id, release_mode)
    
    elif action == 'build':
        return build_flutter_app(flutter_project_dir, build_target, release_mode)
    
    return 0


if __name__ == "__main__":
    sys.exit(main())

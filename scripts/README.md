# OpenMIDIControl Scripts

This folder contains organizational and build-assistance scripts to standardize testing and release workflows across contributors. These scripts provide an interactive device-selection layer (via `flutter devices --machine`) to ensure the app targets the correct hardware during high-frequency MIDI testing.

## Key Features

### 🚀 Project-Agnostic Discovery
Both scripts automatically locate the Flutter project by searching for a `pubspec.yaml` file in the project root or its immediate subdirectories (e.g., `app/`, `appname/`). You can run these scripts from the repository root without worrying about the internal folder structure.

### 📱 Interactive Target Selection
The scripts hook into the `flutter devices` daemon to parse your connected hardware and virtual targets. They present an interactive, numbered list of all available simulators, physical devices, and web endpoints, allowing you to select a target with a single keystroke.


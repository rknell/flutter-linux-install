# Flutter Linux Install

A command-line utility for installing Flutter Linux applications across different distributions.

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/flutter_linux_install.git
   ```

2. Install the utility:
   ```bash
   cd flutter_linux_install
   sudo ./install.sh
   ```

This will install the `flutter-linux-install` command globally.

## Usage

From any Flutter Linux project:

```bash
flutter-linux-install [options]
```

Or specify a project directory:

```bash
flutter-linux-install -p /path/to/flutter/project [options]
```

### Options

```bash
Options:
  -p, --project DIR      Flutter project directory (default: current directory)
  -n, --name NAME        Application name (default: derived from pubspec.yaml)
  -d, --dir DIR          Installation directory (default: detected per distro)
  -i, --icon FILE        Icon file to use (png/svg, will be auto-resized)
  --no-desktop           Skip desktop file installation
  -h, --help            Show this help message
```

## Features

- Distribution-aware installation paths and package management
- Automatic project detection and configuration
- Automatic Flutter release build if not present
- Automatic icon resizing from a single source image
- Desktop file integration
- Clean uninstallation of previous versions

## Supported Distributions

- Debian/Ubuntu-based: Ubuntu, Debian, Pop!_OS, Elementary OS
- Red Hat-based: Fedora, RHEL, CentOS
- Arch-based: Arch Linux, Manjaro
- SUSE-based: openSUSE
- Others: Falls back to sensible defaults

## Examples

Install current project:
```bash
flutter-linux-install
```

Install with custom icon:
```bash
flutter-linux-install --icon path/to/icon.svg
```

Install specific project:
```bash
flutter-linux-install -p ~/Projects/my_flutter_app
```

## License

MIT License - See LICENSE file for details.

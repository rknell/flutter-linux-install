#!/bin/bash

# Exit on error
set -e

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo ./install.sh)"
    exit 1
fi

# Create installation directories
mkdir -p /usr/local/lib/flutter-linux-install
mkdir -p /usr/local/bin

# Copy files
cp -r lib/flutter-linux-install/* /usr/local/lib/flutter-linux-install/
cp bin/flutter-linux-install /usr/local/bin/

# Set permissions
chmod 755 /usr/local/bin/flutter-linux-install
chmod 644 /usr/local/lib/flutter-linux-install/*
chmod 755 /usr/local/lib/flutter-linux-install/*.sh

echo "Flutter Linux Install utility has been installed."
echo "You can now use 'flutter-linux-install' from any Flutter project directory." 
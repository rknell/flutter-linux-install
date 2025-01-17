#!/bin/bash

# Detect Linux distribution and set defaults
detect_distribution() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="$ID"
        DISTRO_FAMILY="$ID_LIKE"
    else
        echo "Warning: Could not detect distribution, using generic defaults"
        DISTRO_ID="unknown"
        DISTRO_FAMILY="unknown"
    fi

    # Set installation directory based on distribution
    case "$DISTRO_ID" in
        "fedora"|"rhel"|"centos")
            DEFAULT_INSTALL_DIR="/usr"
            PACKAGE_MANAGER="dnf"
            PACKAGE_INSTALL="sudo dnf install -y"
            ;;
        "debian"|"ubuntu"|"pop"|"elementary")
            DEFAULT_INSTALL_DIR="/usr/local"
            PACKAGE_MANAGER="apt"
            PACKAGE_INSTALL="sudo apt-get install -y"
            ;;
        "arch"|"manjaro")
            DEFAULT_INSTALL_DIR="/usr"
            PACKAGE_MANAGER="pacman"
            PACKAGE_INSTALL="sudo pacman -S --noconfirm"
            ;;
        "opensuse"*)
            DEFAULT_INSTALL_DIR="/usr"
            PACKAGE_MANAGER="zypper"
            PACKAGE_INSTALL="sudo zypper install -y"
            ;;
        *)
            DEFAULT_INSTALL_DIR="/usr/local"
            PACKAGE_MANAGER="unknown"
            PACKAGE_INSTALL="echo 'Please install manually:'"
            ;;
    esac
}

# Check for required tools and offer to install them
check_dependencies() {
    local missing_deps=()
    
    # Check for ImageMagick if icon processing is needed
    if [ -n "$ICON_FILE" ] && ! command -v convert &> /dev/null; then
        case "$PACKAGE_MANAGER" in
            "apt")
                missing_deps+=("imagemagick")
                ;;
            "dnf")
                missing_deps+=("ImageMagick")
                ;;
            "pacman")
                missing_deps+=("imagemagick")
                ;;
            "zypper")
                missing_deps+=("ImageMagick")
                ;;
        esac
    fi
    
    # Check for librsvg if SVG processing is needed
    if [ -n "$ICON_FILE" ] && [[ "$ICON_FILE" == *.svg ]] && ! command -v rsvg-convert &> /dev/null; then
        case "$PACKAGE_MANAGER" in
            "apt")
                missing_deps+=("librsvg2-bin")
                ;;
            "dnf")
                missing_deps+=("librsvg2-tools")
                ;;
            "pacman")
                missing_deps+=("librsvg")
                ;;
            "zypper")
                missing_deps+=("librsvg-tools")
                ;;
        esac
    fi
    
    # Install missing dependencies if any
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "The following dependencies are required:"
        printf '%s\n' "${missing_deps[@]}"
        if [ "$PACKAGE_MANAGER" != "unknown" ]; then
            echo "Installing dependencies..."
            $PACKAGE_INSTALL "${missing_deps[@]}"
        else
            echo "Please install the required dependencies manually."
            exit 1
        fi
    fi
}

# Function to create icons from source
create_icons() {
    local source_icon="$1"
    local icon_name="$2"
    local temp_dir
    temp_dir=$(mktemp -d)
    
    echo "Creating icons from $source_icon..."
    
    # Create icons for each size
    for size in 16 32 48 64 128 256; do
        target_dir="$temp_dir/${size}x${size}"
        mkdir -p "$target_dir"
        if [[ "$source_icon" == *.svg ]]; then
            # For SVG, use rsvg-convert if available, otherwise use ImageMagick
            if command -v rsvg-convert &> /dev/null; then
                rsvg-convert -w "$size" -h "$size" "$source_icon" -o "$target_dir/$icon_name.png"
            else
                convert -background none -resize "${size}x${size}" "$source_icon" "$target_dir/$icon_name.png"
            fi
        else
            convert "$source_icon" -resize "${size}x${size}" "$target_dir/$icon_name.png"
        fi
    done
    
    echo "$temp_dir"
}

# Update icon cache based on distribution
update_icon_cache() {
    echo "Updating system caches..."
    
    # Update desktop database if command exists
    if command -v update-desktop-database &> /dev/null; then
        sudo update-desktop-database
    fi
    
    # Update icon cache if command exists
    if command -v gtk-update-icon-cache &> /dev/null; then
        sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor
    elif command -v gtk4-update-icon-cache &> /dev/null; then
        sudo gtk4-update-icon-cache -f -t /usr/share/icons/hicolor
    fi
}

# Find project root (directory containing pubspec.yaml)
find_project_root() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/pubspec.yaml" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# Extract app name from pubspec.yaml
extract_app_name() {
    local project_root="$1"
    local pubspec="$project_root/pubspec.yaml"
    
    if [ ! -f "$pubspec" ]; then
        return 1
    fi
    
    local name
    name=$(grep "^name:" "$pubspec" | awk '{print $2}' | tr -d '"'"'" | tr -d "[:space:]")
    if [ -z "$name" ]; then
        return 1
    fi
    
    echo "$name"
    return 0
}

# Install the application
install_application() {
    local project_root="$1"
    local app_name="$2"
    local install_dir="$3"
    local install_desktop="$4"
    local icon_file="$5"
    
    local bundle_dir="$project_root/build/linux/x64/release/bundle"
    local binary_path="$install_dir/bin/$app_name"
    local app_dir="$install_dir/lib/$app_name"
    local desktop_file_path="/usr/share/applications/$app_name.desktop"
    local icon_base_path="/usr/share/icons/hicolor"
    
    echo "Installing $app_name..."
    
    # Check sudo access
    if ! sudo -v; then
        echo "This script requires sudo privileges to install the application."
        exit 1
    fi
    
    # Keep sudo alive
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    
    # Verify Flutter build exists
    if [ ! -d "$bundle_dir" ]; then
        echo "Flutter build not found. Building release version..."
        (cd "$project_root" && flutter build linux --release)
    fi
    
    # Create directories
    echo "Creating directories..."
    sudo mkdir -p "$install_dir/bin"
    sudo mkdir -p "$app_dir"
    
    # Set permissions
    sudo chown -R root:root "$app_dir"
    sudo chmod 755 "$app_dir"
    
    # Remove existing installation
    echo "Removing previous installation..."
    sudo rm -rf "$app_dir"/*
    sudo rm -f "$binary_path"
    
    # Copy application files
    echo "Installing application files..."
    sudo cp -r "$bundle_dir"/* "$app_dir/"
    
    # Create wrapper script
    echo "Creating wrapper script..."
    sudo bash -c "cat > '$binary_path'" << EOF
#!/bin/bash
export LD_LIBRARY_PATH="$app_dir/lib:\$LD_LIBRARY_PATH"
cd "$app_dir"
exec "$app_dir/$app_name" "\$@"
EOF
    sudo chmod +x "$binary_path"
    
    # Handle desktop file
    if [ "$install_desktop" = true ]; then
        local desktop_file="$project_root/linux/my-application.desktop"
        if [ -f "$desktop_file" ]; then
            echo "Installing desktop entry..."
            sudo mkdir -p "/usr/share/applications"
            sudo cp "$desktop_file" "$desktop_file_path"
            sudo sed -i "s/My Application/$app_name/g" "$desktop_file_path"
            sudo sed -i "s/my-application/$app_name/g" "$desktop_file_path"
        else
            echo "Warning: Desktop file not found at $desktop_file"
        fi
    fi
    
    # Handle icons
    if [ -n "$icon_file" ]; then
        if [ ! -f "$icon_file" ]; then
            echo "Error: Icon file not found: $icon_file"
            exit 1
        fi
        
        check_dependencies
        
        local icons_temp_dir
        icons_temp_dir=$(create_icons "$icon_file" "$app_name")
        
        echo "Installing icons..."
        for size in 16 32 48 64 128 256; do
            local icon_dir="$icon_base_path/${size}x${size}/apps"
            sudo mkdir -p "$icon_dir"
            sudo cp "$icons_temp_dir/${size}x${size}/$app_name.png" "$icon_dir/$app_name.png"
            sudo chmod 644 "$icon_dir/$app_name.png"
        done
        
        rm -rf "$icons_temp_dir"
        update_icon_cache
    else
        local icons_dir="$project_root/linux/packaging/icons"
        if [ -d "$icons_dir" ]; then
            echo "Using existing icons from $icons_dir..."
            for size in 16 32 48 64 128 256; do
                local icon_path="$icons_dir/${size}x${size}/$app_name.png"
                if [ -f "$icon_path" ]; then
                    local icon_dir="$icon_base_path/${size}x${size}/apps"
                    sudo mkdir -p "$icon_dir"
                    sudo cp "$icon_path" "$icon_dir/$app_name.png"
                    sudo chmod 644 "$icon_dir/$app_name.png"
                fi
            done
            update_icon_cache
        fi
    fi
    
    echo "Installation complete! You can run it from the command line with: $app_name"
} 
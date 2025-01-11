#!/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root or with sudo"
    exit 1
fi

# Get the username of the user who invoked sudo
REAL_USER=${SUDO_USER:-$(whoami)}
HOME_DIR=$(eval echo ~$REAL_USER)

# Function to print colored output
print_status() {
    echo -e "\e[1;34m==> $1\e[0m"
}

# Store password at the beginning
print_status "Please enter your password once for all operations:"
read -s PASSWORD
echo

# Function to check if command was successful
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "\e[1;32m==> Success: $1\e[0m"
    else
        echo -e "\e[1;31m==> Error: $1\e[0m"
        exit 1
    fi
}

# Function to check if a package is installed
is_package_installed() {
    pacman -Qi "$1" >/dev/null 2>&1
}

# Function to check if an AUR package is installed
is_aur_package_installed() {
    yay -Qi "$1" >/dev/null 2>&1
}

# Install yay if not already installed
print_status "Checking/Installing yay AUR helper"
if ! command -v yay &> /dev/null; then
    cd /tmp
    rm -rf yay  # Clean up any existing yay directory
    sudo -u $REAL_USER git clone https://aur.archlinux.org/yay.git
    cd yay
    sudo -u $REAL_USER makepkg -si --noconfirm
    cd ..
    rm -rf yay
    check_status "yay installation"
else
    echo "yay is already installed, skipping..."
fi

# Add system update
print_status "Updating system packages"
pacman -Syu --noconfirm
check_status "System update"

# Install AUR packages as non-root user
print_status "Installing AUR packages"
AUR_PACKAGES=(
    "android-studio"
    "postman-bin"
    "mongodb-compass"
    "mongodb-bin"
    "google-chrome"
    "spotify"
    "nvm"
    "discord"
    "zoom"
    "visual-studio-code-bin"
    "insomnia-bin"           # REST API client alternative to Postman
    "dbeaver"                # Universal database tool
    "slack-desktop"          # Team communication
    "figma-linux"           # Design tool
    "notion-app"            # Note-taking and collaboration
    "docker-desktop"        # Docker GUI
)

for package in "${AUR_PACKAGES[@]}"; do
    if ! is_aur_package_installed "$package"; then
        echo "Installing $package..."
        echo "$PASSWORD" | sudo -u $REAL_USER yay -S --noconfirm "$package"
    else
        echo "$package is already installed, skipping..."
    fi
done
check_status "AUR packages installation"

# Install official packages
print_status "Installing official packages"
OFFICIAL_PACKAGES=(
    "docker"
    "docker-compose"
    "github-cli"
    "postgresql"
    "jdk-openjdk"
    "jdk17-openjdk"
    "android-tools"
    "gimp"
    "blender"
    "inkscape"
    "libreoffice-fresh"
    "obs-studio"
    "ttf-fira-code"
    "ttf-firacode-nerd"
    "ttf-hack-nerd"
    "python-virtualenv"
    "redis"
    "git"
    "base-devel"        # Essential for development
    "python-pip"       # Python package manager
    "cmake"            # Build system
    "vim"              # Text editor
    "neovim"           # Modern vim
    "htop"             # Process viewer
    "tmux"             # Terminal multiplexer
    "wget"             # File downloader
    "curl"             # URL transfer tool
)

for package in "${OFFICIAL_PACKAGES[@]}"; do
    if ! is_package_installed "$package"; then
        echo "Installing $package..."
        echo "$PASSWORD" | pacman -S --noconfirm "$package"
    else
        echo "$package is already installed, skipping..."
    fi
done
check_status "Official packages installation"

# Configure Java environment for the real user (only if not already configured)
print_status "Checking/Configuring Java environment"
if ! grep -q "JAVA_17_HOME" "$HOME_DIR/.bashrc"; then
    sudo -u $REAL_USER bash -c "cat >> $HOME_DIR/.bashrc << 'EOL'

# Java configuration
export JAVA_17_HOME=/usr/lib/jvm/java-17-openjdk
export JAVA_23_HOME=/usr/lib/jvm/java-23-openjdk
export JAVA_HOME=\$JAVA_17_HOME
export PATH=\$JAVA_HOME/bin:\$PATH

use_java17() {
    export JAVA_HOME=\$JAVA_17_HOME
    export PATH=\$(echo \$PATH | sed \"s|/usr/lib/jvm/[^/]*/bin:|\$JAVA_HOME/bin:|\")
    echo \"Switched to Java 17\"
    java -version
}

use_java23() {
    export JAVA_HOME=\$JAVA_23_HOME
    export PATH=\$(echo \$PATH | sed \"s|/usr/lib/jvm/[^/]*/bin:|\$JAVA_HOME/bin:|\")
    echo \"Switched to Java 23\"
    java -version
}

# Android SDK configuration
export ANDROID_HOME=\$HOME/Android/Sdk
export PATH=\$PATH:\$ANDROID_HOME/emulator
export PATH=\$PATH:\$ANDROID_HOME/platform-tools

# NVM configuration
export NVM_DIR=\"\$HOME/.nvm\"
[ -s \"/usr/share/nvm/init-nvm.sh\" ] && \\. \"/usr/share/nvm/init-nvm.sh\"
EOL"
    check_status "Java and environment configuration"
else
    echo "Java environment already configured, skipping..."
fi

# Configure PostgreSQL if not already initialized
print_status "Checking/Configuring PostgreSQL"
if [ ! -d "/var/lib/postgres/data" ] || [ -z "$(ls -A /var/lib/postgres/data)" ]; then
    sudo -u postgres initdb -D /var/lib/postgres/data
    systemctl start postgresql
    systemctl enable postgresql
    # Set PostgreSQL password
    print_status "Setting PostgreSQL password"
    sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '123456';"
    check_status "PostgreSQL initialization and password configuration"
else
    echo "PostgreSQL already initialized, skipping..."
fi

# Configure Redis if not already running
print_status "Checking/Configuring Redis"
if ! systemctl is-active --quiet redis; then
    systemctl start redis
    systemctl enable redis
    check_status "Redis service configuration"
else
    echo "Redis already running and enabled, skipping..."
fi

# Configure Docker if not already set up
print_status "Checking/Configuring Docker service"
if ! systemctl is-active --quiet docker; then
    systemctl enable docker
    systemctl start docker
fi

# Add user to docker group if not already added
if ! groups $REAL_USER | grep -q docker; then
    usermod -aG docker $REAL_USER
    check_status "Docker service configuration"
else
    echo "User already in docker group, skipping..."
fi

print_status "Installation completed successfully!"
echo "Please note: Some changes require a system restart to take effect."
echo "Script was run as root/sudo by user: $REAL_USER"

# Add restart prompt
read -p "Would you like to restart the system now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Restarting system in 5 seconds..."
    sleep 5
    reboot
else
    echo "Please remember to restart your system later for all changes to take effect."
fi

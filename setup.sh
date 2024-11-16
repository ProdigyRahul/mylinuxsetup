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

# Function to check if command was successful
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "\e[1;32m==> Success: $1\e[0m"
    else
        echo -e "\e[1;31m==> Error: $1\e[0m"
        exit 1
    fi
}

# Install yay as non-root user
print_status "Installing yay AUR helper"
cd /tmp
rm -rf yay  # Clean up any existing yay directory
sudo -u $REAL_USER git clone https://aur.archlinux.org/yay.git
cd yay
sudo -u $REAL_USER makepkg -si --noconfirm
cd ..
rm -rf yay
check_status "yay installation"

# Install AUR packages as non-root user
print_status "Installing AUR packages"
sudo -u $REAL_USER yay -S --noconfirm \
    android-studio \
    visual-studio-code-bin \
    postman-bin \
    mongodb-compass \
    mongodb-bin \
    google-chrome \
    spotify \
    nvm \
    pgadmin4-desktop
check_status "AUR packages installation"

# Install official packages
print_status "Installing official packages"
pacman -S --noconfirm \
    docker \
    docker-compose \
    github-cli \
    postgresql \
    jdk-openjdk \
    jdk17-openjdk \
    android-tools \
    gimp \
    blender \
    inkscape \
    libreoffice-fresh \
    obs-studio \
    telegram-desktop \
    ttf-fira-code \
    ttf-firacode-nerd
check_status "Official packages installation"

# Configure Java environment for the real user
print_status "Configuring Java environment"
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

# NVM configuration
export NVM_DIR=\"\$HOME/.nvm\"
[ -s \"/usr/share/nvm/init-nvm.sh\" ] && \\. \"/usr/share/nvm/init-nvm.sh\"
EOL"
check_status "Java and NVM configuration"

# Configure PostgreSQL
print_status "Configuring PostgreSQL"
if [ ! -d "/var/lib/postgres/data" ] || [ -z "$(ls -A /var/lib/postgres/data)" ]; then
    sudo -u postgres initdb -D /var/lib/postgres/data
fi
systemctl start postgresql
systemctl enable postgresql
check_status "PostgreSQL initialization and service setup"

# Set PostgreSQL password
print_status "Setting PostgreSQL password"
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '123456';"
check_status "PostgreSQL password configuration"

# Enable and start Docker service
print_status "Enabling Docker service"
systemctl enable docker
systemctl start docker
usermod -aG docker $REAL_USER
check_status "Docker service configuration"

print_status "Installation completed successfully!"
echo "Please log out and log back in for group changes to take effect."
echo "Script was run as root/sudo by user: $REAL_USER"

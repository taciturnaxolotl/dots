#!/usr/bin/env bash

# NixOS Installation Script
# This script automates the post-network setup installation process

set -e # Exit on any error

echo "==== NixOS Installation Automation ===="
echo "This script will automate the installation process after network setup."
echo "Make sure you have already set up network connectivity before running this script."

# Verify network connectivity
echo -n "Checking network connectivity... "
if ping -c 1 1.1.1.1 &> /dev/null; then
    echo "Success!"
else
    echo "Failed!"
    echo "Error: No internet connection detected. Please set up your network first."
    echo "You can use the following commands to connect to WiFi:"
    echo "  sudo systemctl start wpa_supplicant"
    echo "  wpa_cli"
    echo "  > add_network 0"
    echo "  > set_network 0 ssid \"your SSID\""
    echo "  > set_network 0 psk \"your password\""
    echo "  > enable network 0"
    echo "  > exit"
    exit 1
fi

# Get sudo privileges and maintain them
echo "Acquiring root permissions..."
sudo -v
# Keep sudo privileges active
while true; do sudo -v; sleep 60; done &
KEEP_SUDO_PID=$!

# Function to clean up the background sudo process on exit
cleanup() {
    kill $KEEP_SUDO_PID 2>/dev/null
}
trap cleanup EXIT

# Check if git is already enabled in the configuration
echo "Checking git configuration..."
if grep -q "programs.git.enable = true" /etc/nixos/configuration.nix; then
    echo "Git is already enabled in configuration.nix"
else
    echo "Enabling git..."
    sudo sed -i 's/^{$/{\n  programs.git.enable = true;/' /etc/nixos/configuration.nix
    sudo nixos-rebuild switch
fi

# Download and run the disk configuration
echo "Downloading and running disk configuration..."
curl -L https://github.com/taciturnaxolotl/dots/raw/main/moonlark/disk-config.nix -o /tmp/disk-config.nix
sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode destroy,format,mount /tmp/disk-config.nix

# Generate NixOS configuration
echo "Generating NixOS configuration..."
sudo nixos-generate-config --root /mnt
cd /mnt/etc/nixos

# Check if repository already exists
echo "Setting up configuration..."
if [ -d ".git" ]; then
    echo "Configuration already exists, pulling latest changes..."
    sudo git pull
else
    # Clone the repository to the NixOS configuration directory
    echo "Cloning nixos repository..."
    sudo rm -f *
    sudo git clone https://github.com/taciturnaxolotl/dots.git .
fi

# Prompt user for SSH key setup
echo ""
echo "SSH Key Setup"
read -p "Do you want to add an SSH private key? (y/n): " add_ssh_key
if [[ "$add_ssh_key" =~ ^[Yy]$ ]]; then
    echo "How would you like to add your SSH key?"
    echo "1) From a local file"
    echo "2) From a URL"
    read -p "Enter your choice (1/2): " ssh_key_method

    sudo mkdir -p /mnt/etc/ssh/

    if [[ "$ssh_key_method" == "1" ]]; then
        echo "Please enter the path to your SSH private key:"
        read ssh_key_path

        if [ -f "$ssh_key_path" ]; then
            sudo cp "$ssh_key_path" /mnt/etc/ssh/id_rsa
            sudo chmod 600 /mnt/etc/ssh/id_rsa
            echo "SSH key added from local file!"
        else
            echo "Warning: SSH key file not found. Proceeding without SSH key."
        fi
    elif [[ "$ssh_key_method" == "2" ]]; then
        echo "Please enter the URL to download your SSH private key:"
        read ssh_key_url

        echo "Downloading SSH key from URL..."
        if curl -s "$ssh_key_url" -o /tmp/downloaded_ssh_key; then
            sudo mv /tmp/downloaded_ssh_key /mnt/etc/ssh/id_rsa
            sudo chmod 600 /mnt/etc/ssh/id_rsa
            echo "SSH key successfully downloaded and added!"
        else
            echo "Warning: Failed to download SSH key from URL. Proceeding without SSH key."
        fi
    else
        echo "Invalid choice. Proceeding without SSH key."
    fi
else
    echo "Proceeding without SSH key."
fi

# Prompt for hostname configuration
echo ""
echo "Hostname Configuration"
echo "Available configurations in this repo:"
echo "1) moonlark (default)"
read -p "Which configuration would you like to use? (Press Enter for moonlark): " hostname_choice
hostname=${hostname_choice:-moonlark}

# Install the flake
echo "Installing the flake for configuration: $hostname"
sudo nixos-install --flake .#${hostname} --no-root-passwd

echo "Installation complete! The system will now reboot."
echo ""
echo "After reboot, you'll need to complete these post-installation tasks:"
echo "1. Change your password"
echo "2. Move config to local directory: sudo mv /etc/nixos ~/dots"
echo "3. Link to /etc/nixos: sudo ln -s ~/dots /etc"
echo "4. Change permissions: sudo chown -R \$(id -un):users ~/dots"
echo "5. Setup fingerprint reader (optional): sudo fprintd-enroll -f right-index-finger \$(whoami)"

read -p "Press Enter to unmount and reboot..."
sudo umount -R /mnt
sudo reboot

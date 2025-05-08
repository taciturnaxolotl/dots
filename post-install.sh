#!/usr/bin/env bash

# NixOS Post-Installation Script
# This script automates the post-installation tasks after the first reboot

set -e # Exit on any error

echo "==== NixOS Post-Installation Setup ===="
echo "This script will automate the post-installation tasks."

# Function to print current step
print_step() {
    echo -e "\n\033[1;34m==== $1 ====\033[0m"
}

# Change password if needed
print_step "Password Management"
read -p "Do you want to change your password? (y/n): " change_password
if [[ "$change_password" =~ ^[Yy]$ ]]; then
    passwd
    echo "Password changed successfully!"
fi

# Move config to local directory and fix permissions
print_step "Setting up configuration files"
if [ -L "/etc/nixos" ]; then
    echo "Configuration is already properly set up."
else
    echo "Moving configuration to home directory..."
    mkdir -p ~/etc
    sudo mv /etc/nixos ~/etc/
    sudo ln -s ~/etc/nixos /etc/
    echo "Fixing permissions..."
    sudo chown -R $(id -un):users ~/etc/nixos
    sudo chown -R $(id -un) ~/etc/nixos/.*
    echo "Configuration files moved and linked successfully!"
fi

# Setup fingerprint reader (optional)
print_step "Fingerprint Reader Setup"
read -p "Do you want to set up the fingerprint reader? (y/n): " setup_fingerprint
if [[ "$setup_fingerprint" =~ ^[Yy]$ ]]; then
    echo "Setting up fingerprint reader..."
    echo "You may need to swipe your finger across the fingerprint sensor instead of simply laying it there."
    sudo fprintd-enroll -f right-index-finger $(whoami)
    echo "Verifying fingerprint..."
    sudo fprintd-verify $(whoami)
else
    echo "Skipping fingerprint reader setup."
fi

# Git configuration
print_step "Git Configuration"
read -p "Do you want to configure Git? (y/n): " setup_git
if [[ "$setup_git" =~ ^[Yy]$ ]]; then
    read -p "Enter your Git taciturnaxolotl: " git_user
    read -p "Enter your Git email: " git_email

    git config --global user.name "$git_user"
    git config --global user.email "$git_email"

    echo "Git configuration complete!"
fi

# Rebuild system
print_step "Rebuilding system"
read -p "Do you want to rebuild the system to apply all changes? (y/n): " rebuild_system
if [[ "$rebuild_system" =~ ^[Yy]$ ]]; then
    echo "Rebuilding system..."
    cd ~/etc/nixos

    # Get the hostname to use for the rebuild
    hostname=$(hostname)
    echo "Current hostname: $hostname"

    sudo nixos-rebuild switch --flake .#${hostname}
    echo "System rebuilt successfully!"
else
    echo "Skipping system rebuild."
fi

print_step "Post-installation complete!"
echo "Your NixOS setup is now complete! You may need to restart some applications or services for all changes to take effect."
echo "To rebuild your system in the future, run: cd ~/etc/nixos && sudo nixos-rebuild switch --flake .#$(hostname)"
echo "Enjoy your new NixOS installation!"

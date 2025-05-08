# So, you want to use my dots?

Hey there! This guide supplements the README with additional details about using the installation scripts. I've tried to make installation as painless as possible. (mainly because i hate typing in commands manually with no autocomplete; yeah ik im not a "true" linux nerd but whatever lol)

## The Automated Way (Recommended)

### Step 1: Get connected

First, make sure you've got internet! (this is already covered in [`README.md`](/README.md) so not duplicating here) Also don't forget to double check with `ping 1.1.1.1`

### Step 2: Run the install script

```bash
curl -L https://raw.githubusercontent.com/taciturnaxolotl/dots/main/nixos/install.sh -o install.sh
chmod +x install.sh
./install.sh
```

This magic script will:
- Make sure you're online
- Enable git (required for the rest of this charade)
- Partition your disks with disko
- Clone my dots to the right place
- Let you add your SSH key if you've got one
- Install the flake
- Send you off to reboot land

### Step 3: First login after reboot

After the system reboots, login with user `kierank` and password `lolzthisaintsecure!`

(Please change this password immediately!)

### Step 4: Run the post-install script

```bash
curl -L https://raw.githubusercontent.com/taciturnaxolotl/dots/main/nixos/post-install.sh -o post-install.sh
chmod +x post-install.sh
./post-install.sh
```

This script will walk you through:
- Changing your password (if you haven't already)
- Moving config files to your home directory
- Setting up the fingerprint reader (optional)
- Configuring git (optional)
- Rebuilding the system with your hostname

## Available System Configurations

Currently, this repo has the following system configurations:

- `moonlark` - My Framework laptop setup (default config)

You'll be asked which one you want during the installation.

Good luck, and may the nix gods be with you! 🙏

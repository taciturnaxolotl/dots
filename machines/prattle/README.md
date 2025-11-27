# Prattle - Oracle Cloud x86_64 NixOS Server

## Overview
This is a minimal NixOS server configuration for Oracle Cloud Infrastructure.

- **Hostname**: prattle
- **Platform**: x86_64-linux
- **Disk**: /dev/sda (Oracle Cloud default)
- **Services**: SSH, Tailscale

## Deployment with nixos-anywhere

### Prerequisites
1. Oracle Cloud instance running and accessible via SSH
2. Root SSH access or sudo access configured
3. Your SSH public key should already be in the configuration (already set)
4. **Important for Apple Silicon (M1/M2/M3) Macs**: 
   - The built-in macOS Linux builder only supports `aarch64-linux` (ARM)
   - Since Oracle Cloud x86_64 instances use `x86_64-linux` (Intel), you **must** use `--build-on-remote`
   - This builds the system on the target machine itself during installation

### Deploy Command

From your local machine (with flake repository):

```bash
# Deploy to Oracle Cloud instance (builds on remote machine)
nix run github:nix-community/nixos-anywhere -- \
  --flake .#prattle \
  -i ~/.ssh/id_rsa \
  --build-on-remote \
  root@<ORACLE_INSTANCE_IP>
```

**Note**: The `-i ~/.ssh/id_rsa` flag tells nixos-anywhere which SSH key to use during installation. Your public key (`~/.ssh/id_rsa.pub`) is already configured in the system for post-installation access.

The `--build-on-remote` flag is **required** when deploying from Apple Silicon Macs to x86_64 systems.

### Post-Installation

1. **SSH Key Changed**: The server's SSH host key will be different after installation. Remove old entry:
   ```bash
   ssh-keygen -R <ORACLE_INSTANCE_IP>
   ```

2. **Login**: SSH into the new system:
   ```bash
   ssh kierank@<ORACLE_INSTANCE_IP>
   ```

3. **Change Password** (optional, since SSH key auth is configured):
   ```bash
   passwd
   ```

4. **Update the System**:
   ```bash
   cd ~/dots
   git pull
   sudo nixos-rebuild switch --flake .#prattle
   ```

## Configuration Details

### Boot Configuration
- **Bootloader**: systemd-boot (Oracle Cloud recommended)
- **Kernel Parameters**: `net.ifnames=0` for predictable network interface names
- **EFI**: Enabled with variable modification support
### Disk Layout
- **Boot Partition**: 500MB, EFI (vfat), mounted at `/boot`
- **Root Partition**: Remaining space, ext4, mounted at `/`

### Network
- DHCP configured (Oracle Cloud default)
- Hostname: `prattle`
- Firewall enabled
- SSH enabled (key-based auth only)
- Tailscale client configured

### User Configuration
- **User**: kierank
- **Shell**: zsh
- **Groups**: wheel, networkmanager
- **SSH**: Key-based authentication configured
- **Initial Password**: "changeme" (change after first login)

### Installed Packages
Core utilities, development tools (nodejs, python, go, gcc), nix tools (nixvim, nixd, nil), networking tools (mosh, curl, wget), and more.

## Notes

- Oracle Cloud uses `/dev/sda` as the primary disk device
- The configuration uses disko for declarative disk partitioning
- Hardware configuration will be auto-generated during installation
- Root login via SSH is disabled for security

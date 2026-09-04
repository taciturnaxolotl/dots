{
  pkgs,
  lib,
  inputs,
  outputs,
  modulesPath,
  ...
}:
{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    inputs.home-manager.nixosModules.home-manager
  ];

  networking.hostName = "iso";
  # ZFS refuses to load without one. Fixed rather than random so a stick that
  # imports a pool twice does not look like two different machines.
  networking.hostId = "15015015";

  # A rescue stick that cannot read the filesystems it is rescuing is a coaster.
  # bcachefs is out-of-tree as of 6.18, so it is absent from stock install media;
  # this is the whole reason for rolling our own.
  boot.supportedFilesystems = {
    bcachefs = true;
    zfs = true;
    ntfs = true;
  };
  # Never force-import a pool on rescue media. If a pool looks like it is still
  # owned by another host, that is information, not an obstacle to bulldoze.
  boot.zfs.forceImportRoot = false;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = false;
    };
  };

  # Reaching the stick over the tailnet beats reading a console over someone's
  # shoulder. No auth key is baked in: a USB stick is a losable object, and a
  # reusable key on one is a standing credential for anybody who finds it.
  # Instead the stick prints a login URL and a QR code on tty1 at boot; one
  # click authenticates it, and --ssh means no key juggling afterwards.
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  systemd.services.tailscale-rescue-login = {
    description = "Bring the rescue stick onto the tailnet and print a login QR";
    after = [ "tailscaled.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    requires = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StandardOutput = "tty";
      TTYPath = "/dev/tty1";
    };
    script = ''
      ${pkgs.tailscale}/bin/tailscale up \
        --ssh \
        --accept-routes \
        --hostname="rescue-$(${pkgs.coreutils}/bin/head -c4 /proc/sys/kernel/random/uuid)" \
        --qr || true
      echo
      echo "tailnet address: $(${pkgs.tailscale}/bin/tailscale ip -4 2>/dev/null || echo 'not connected')"
    '';
  };

  home-manager = {
    useGlobalPkgs = true;
    extraSpecialArgs = { inherit inputs outputs; };
    users.root = {
      imports = [ (inputs.import-tree ../../modules/home) ];

      home = {
        username = "root";
        homeDirectory = "/root";
      };

      atelier.shell = {
        enable = true;
        ephemeral = true;
      };

      programs.home-manager.enable = true;
      home.stateVersion = lib.trivial.release;
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCzEEjvbL/ttqmYoDjxYQmDIq36BabROJoXgQKeh9liBxApwp+2PmgxROzTg42UrRc9pyrkq5kVfxG5hvkqCinhL1fMiowCSEs2L2/Cwi40g5ZU+QwdcwI8a4969kkI46PyB19RHkxg54OUORiIiso/WHGmqQsP+5wbV0+4riSnxwn/JXN4pmnE//stnyAyoiEZkPvBtwJjKb3Ni9n3eNLNs6gnaXrCtaygEZdebikr9kS2g9mM696HvIFgM6cdR/wZ7DcLbG3IdTXuHN7PC3xxL+Y4ek5iMreQIPmuvs4qslbthPGYoYbYLUQiRa9XO5s/ksIj5Z14f7anHE6cuTQVpvNWdGDOigyIVS5qU+4ZF7j+rifzOXVL48gmcAvw/uV68m5Wl/p0qsC/d8vI3GYwEsWG/EzpAlc07l8BU2LxWgN+d7uwBFaJV9VtmUDs5dcslsh8IbzmtC9gq3OLGjklxTfIl6qPiL8U33oc/UwqzvZUrI2BlbagvIZYy6rP+q0= kierank@mockingjay"
  ];

  environment.systemPackages = with pkgs; [
    # filesystems
    bcachefs-tools
    zfs
    e2fsprogs
    dosfstools
    ntfs3g
    # disks and hardware
    gptfdisk
    parted
    smartmontools
    nvme-cli
    hdparm
    pciutils
    usbutils
    lshw
    # moving data
    rsync
    # working
    git
    jq
    curl
    vim
    tmux
    file
  ];

  system.stateVersion = lib.trivial.release;
}

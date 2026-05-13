{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./disk-config.nix
    ./home-manager.nix

    (inputs.import-tree ../../modules/nixos)
  ];

  nixpkgs = {
    hostPlatform = "x86_64-linux";
    config = {
      allowUnfree = true;
    };
  };

  nix =
    let
      flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
    in
    {
      settings = {
        experimental-features = "nix-command flakes";
        flake-registry = "";
        nix-path = config.nix.nixPath;
        trusted-users = [
          "kierank"
        ];
      };
      channel.enable = false;
      optimise.automatic = true;
      registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
      nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
      gc = {
        automatic = false;
        dates = "weekly";
        options = "--delete-older-than 7d";
      };
    };

  time.timeZone = "America/New_York";

  environment.systemPackages = with pkgs; [
    # core
    coreutils
    ghostty.terminfo
    screen
    bc
    jq
    psmisc
    # cli_utils
    direnv
    zsh
    gum
    vim
    zmx-binary
    # networking
    xh
    curl
    wget
    dogdns
    inetutils
    mosh
    # nix_tools
    inputs.nixvim.packages.x86_64-linux.default
    nixd
    nil
    nixfmt-rfc-style
    inputs.agenix.packages.x86_64-linux.default
    # security
    openssl
    gpgme
    gnupg
    # dev_langs
    nodejs_22
    unstable.bun
    python3
    go
    gopls
    gotools
    go-tools
    gcc
    jre
    # misc
    neofetch
    git
  ];

  age.identityPaths = [
    "/home/kierank/.ssh/id_rsa"
    "/etc/ssh/id_rsa"
  ];
  age.secrets = {
    wakatime = {
      file = ../../secrets/wakatime.age;
      path = "/home/kierank/.wakatime.cfg";
      owner = "kierank";
    };
    nordvpn-wg = {
      file = ../../secrets/nordvpn-wg.age;
    };
    minio = {
      file = ../../secrets/minio.age;
    };
  };

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/home/kierank/dots";
  };

  environment.sessionVariables = {
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_STATE_HOME = "$HOME/.local/state";
    EDITOR = "nvim";
    SYSTEMD_EDITOR = "nvim";
    VISUAL = "nvim";
  };

  atelier = {
    authentication.enable = true;
    machine = {
      enable = true;
      tailscaleHost = "prattle";
    };
  };

  networking = {
    hostName = "prattle";
    hostId = "4e4de3a2";
    useDHCP = true;
    networkmanager.enable = false;
  };

  programs.zsh.enable = true;
  programs.direnv.enable = true;

  users.users = {
    kierank = {
      initialPassword = "changeme";
      isNormalUser = true;
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCzEEjvbL/ttqmYoDjxYQmDIq36BabROJoXgQKeh9liBxApwp+2PmgxROzTg42UrRc9pyrkq5kVfxG5hvkqCinhL1fMiowCSEs2L2/Cwi40g5ZU+QwdcwI8a4969kkI46PyB19RHkxg54OUORiIiso/WHGmqQsP+5wbV0+4riSnxwn/JXN4pmnE//stnyAyoiEZkPvBtwJjKb3Ni9n3eNLNs6gnaXrCtaygEZdebikr9kS2g9mM696HvIFgM6cdR/wZ7DcLbG3IdTXuHN7PC3xxL+Y4ek5iMreQIPmuvs4qslbthPGYoYbYLUQiRa9XO5s/ksIj5Z14f7anHE6cuTQVpvNWdGDOigyIVS5qU+4ZF7j+rifzOXVL48gmcAvw/uV68m5Wl/p0qsC/d8vI3GYwEsWG/EzpAlc07l8BU2LxWgN+d7uwBFaJV9VtmUDs5dcslsh8IbzmtC9gq3OLGjklxTfIl6qPiL8U33oc/UwqzvZUrI2BlbagvIZYy6rP+q0= kierank@mockingjay"
      ];
      extraGroups = [
        "wheel"
        "media"
      ];
    };
    root.openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCzEEjvbL/ttqmYoDjxYQmDIq36BabROJoXgQKeh9liBxApwp+2PmgxROzTg42UrRc9pyrkq5kVfxG5hvkqCinhL1fMiowCSEs2L2/Cwi40g5ZU+QwdcwI8a4969kkI46PyB19RHkxg54OUORiIiso/WHGmqQsP+5wbV0+4riSnxwn/JXN4pmnE//stnyAyoiEZkPvBtwJjKb3Ni9n3eNLNs6gnaXrCtaygEZdebikr9kS2g9mM696HvIFgM6cdR/wZ7DcLbG3IdTXuHN7PC3xxL+Y4ek5iMreQIPmuvs4qslbthPGYoYbYLUQiRa9XO5s/ksIj5Z14f7anHE6cuTQVpvNWdGDOigyIVS5qU+4ZF7j+rifzOXVL48gmcAvw/uV68m5Wl/p0qsC/d8vI3GYwEsWG/EzpAlc07l8BU2LxWgN+d7uwBFaJV9VtmUDs5dcslsh8IbzmtC9gq3OLGjklxTfIl6qPiL8U33oc/UwqzvZUrI2BlbagvIZYy6rP+q0= kierank@mockingjay"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      445   # Samba
      5252  # qBittorrent
      6767  # Bazarr
      7878  # Radarr
      8096  # Jellyfin
      8989  # Sonarr
      9000  # MinIO API
      9001  # MinIO Console
      9696  # Prowlarr
    ];
    allowedUDPPorts = [
      137 138 # Samba NetBIOS
    ];
    logRefusedConnections = false;
    rejectPackets = true;
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  # ── NVIDIA (GT 1030 — Pascal GP108) ──────────────────────────────────
  hardware.nvidia = {
    open = false;
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];

  # ── Nixarr ───────────────────────────────────────────────────────────
  nixarr = {
    enable = true;
    mediaDir = "/storage/media";
    stateDir = "/storage/.state/nixarr";

    vpn = {
      enable = true;
      wgConf = config.age.secrets.nordvpn-wg.path;
    };

    jellyfin = {
      enable = true;
      openFirewall = true;
    };

    sonarr = {
      enable = true;
      openFirewall = true;
      settings-sync.qbittorrent.enable = true;
    };

    radarr = {
      enable = true;
      openFirewall = true;
      settings-sync.qbittorrent.enable = true;
    };

    prowlarr = {
      enable = true;
      openFirewall = true;
      settings-sync = {
        enable-nixarr-apps = true;
        sonarr.enable = true;
        radarr.enable = true;
      };
    };

    bazarr = {
      enable = true;
      openFirewall = true;
      settings-sync = {
        sonarr.enable = true;
        radarr.enable = true;
      };
    };

    qbittorrent = {
      enable = true;
      vpn.enable = true;
      openFirewall = true;
    };
  };

  # ── Samba ─────────────────────────────────────────────────────────────
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "prattle";
        "server role" = "standalone server";
        "map to guest" = "Bad User";
        "hosts allow" = "192.168.0.0/16 100.64.0.0/10 127.0.0.1";
        "hosts deny" = "0.0.0.0/0";
      };
      storage = {
        path = "/storage";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "kierank";
        "create mask" = "0664";
        "directory mask" = "0775";
        "force group" = "media";
      };
      media = {
        path = "/storage/media";
        browseable = "yes";
        "read only" = "yes";
        "guest ok" = "yes";
        "force group" = "media";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  # ── MinIO (S3-compatible) ─────────────────────────────────────────────
  services.minio = {
    enable = true;
    dataDir = [ "/storage/s3" ];
    rootCredentialsFile = config.age.secrets.minio.path;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  services.journald.extraConfig = ''
    SystemMaxUse=100M
    MaxRetentionSec=7day
  '';

  system.stateVersion = "23.05";
}

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

    # Backport tailscale-serve module from nixpkgs-unstable (not in 25.11)
    "${inputs.nixpkgs-unstable}/nixos/modules/services/networking/tailscale-serve.nix"
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
    protonvpn-wg = {
      file = ../../secrets/protonvpn-wg.age;
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
      80    # Media dashboard
      445   # Samba
      8096  # Jellyfin
      9000  # MinIO API
      9001  # MinIO Console
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
    serve = {
      enable = true;
      services = {
        media.endpoints."tcp:443" = "http://localhost:80";
        sonarr.endpoints."tcp:443" = "http://localhost:8989";
        radarr.endpoints."tcp:443" = "http://localhost:7878";
        prowlarr.endpoints."tcp:443" = "http://localhost:9696";
        bazarr.endpoints."tcp:443" = "http://localhost:6767";
        transmission.endpoints."tcp:443" = "http://localhost:9091";
        jellyfin.endpoints."tcp:443" = "http://localhost:8096";
        seerr.endpoints."tcp:443" = "http://localhost:5055";
        minio.endpoints."tcp:443" = "http://localhost:9001";
      };
    };
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
      wgConf = config.age.secrets.protonvpn-wg.path;
    };

    jellyfin = {
      enable = true;
      api.enable = false;
    };

    seerr.enable = true;

    sonarr = {
      enable = true;
      settings-sync.transmission.enable = true;
    };

    radarr = {
      enable = true;
      settings-sync.transmission.enable = true;
    };

    prowlarr = {
      enable = true;
      settings-sync = {
        enable-nixarr-apps = true;
        sonarr.enable = true;
        radarr.enable = true;
      };
    };

    bazarr = {
      enable = true;
      settings-sync = {
        sonarr.enable = true;
        radarr.enable = true;
      };
    };

    transmission = {
      enable = true;
      vpn.enable = true;
      peerPort = 51413;
      extraAllowedIps = [ "192.168.15.0/24" "100.64.0.0/10" ];
      extraSettings = {
        download-dir = "/storage/torrents";
        incomplete-dir = "/storage/torrents/.incomplete";
        incomplete-dir-enabled = true;
      };
    };
  };

  # Root folders and hardlinks for Sonarr/Radarr
  services.sonarr.settings.mediaManagement = {
    useHardlinksInsteadOfCopy = true;
    recycleBin = "/storage/.trash";
    recycleBinCleanupDays = 7;
  };
  services.radarr.settings.mediaManagement = {
    useHardlinksInsteadOfCopy = true;
    recycleBin = "/storage/.trash";
    recycleBinCleanupDays = 7;
  };

  services.prowlarr.settings.auth.required = "DisabledForLocalAddresses";
  services.sonarr.settings.auth.required = "DisabledForLocalAddresses";
  services.radarr.settings.auth.required = "DisabledForLocalAddresses";

  # Media/torrent directory structure (hardlinks require same filesystem)
  systemd.tmpfiles.rules = [
    "d /storage/media/movies 2775 root media -"
    "d /storage/media/tv 2775 root media -"
    "d /storage/torrents 2775 root media -"
    "d /storage/torrents/.incomplete 2775 root media -"
    "d /storage/.trash 2775 root media -"
    "d /storage/s3 0750 minio minio -"
  ];

  # ── Recyclarr (TRaSH Guides sync) ─────────────────────────────────────
  services.recyclarr = {
    enable = true;
    configuration = {
      radarr.movies = {
        base_url = "http://localhost:7878";
        api_key._secret = "/storage/.state/nixarr/secrets/radarr.api-key";
        delete_old_custom_formats = true;
        quality_definition.type = "movie";
        quality_profiles = [
          { trash_id = "d1d67249d3890e49bc12e275d989a7e9"; } # HD Bluray + WEB
        ];
      };
      sonarr.tv = {
        base_url = "http://localhost:8989";
        api_key._secret = "/storage/.state/nixarr/secrets/sonarr.api-key";
        delete_old_custom_formats = true;
        quality_definition.type = "series";
        quality_profiles = [
          { trash_id = "72dae194fc92bf828f32cde7744e51a1"; } # WEB-1080p
        ];
      };
    };
  };

  # Fix Transmission umask so Radarr/Sonarr can read downloaded files
  systemd.services.transmission.serviceConfig.UMask = lib.mkForce "0002";

  # ── Media dashboard + reverse proxy ───────────────────────────────────
  services.caddy = {
    enable = true;
    virtualHosts.":80" = {
      extraConfig = ''
        root * ${./media-dashboard}
        file_server

        handle /jellyfin/* {
          reverse_proxy localhost:8096
        }
        handle /seerr/* {
          reverse_proxy localhost:5055
        }
        handle /sonarr/* {
          reverse_proxy localhost:8989
        }
        handle /radarr/* {
          reverse_proxy localhost:7878
        }
        handle /prowlarr/* {
          reverse_proxy localhost:9696
        }
        handle /bazarr/* {
          reverse_proxy localhost:6767
        }
        handle /transmission/* {
          reverse_proxy localhost:9091
        }
        handle /minio/* {
          reverse_proxy localhost:9001
        }
      '';
    };
  };

  # ── FlareSolverr (Cloudflare bypass for Prowlarr indexers) ───────────
  services.flaresolverr = {
    enable = true;
    port = 8191;
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

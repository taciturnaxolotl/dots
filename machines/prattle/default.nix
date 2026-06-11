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
    doggo
    inetutils
    mosh
    # nix_tools
    inputs.nixvim.packages.x86_64-linux.default
    nixd
    nil
    nixfmt
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
    fastfetch
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
        "cdrom"
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
      80 # Media dashboard
      445 # Samba
      8096 # Jellyfin
      9000 # MinIO API
      9001 # MinIO Console
    ];
    allowedUDPPorts = [
      137
      138 # Samba NetBIOS
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
      extraAllowedIps = [
        "192.168.15.0/24"
        "100.64.0.0/10"
      ];
      extraSettings = {
        download-dir = "/storage/torrents";
        incomplete-dir = "/storage/torrents/.incomplete";
        incomplete-dir-enabled = true;
        rpc-host-whitelist-enabled = false;
      };
    };
  };

  # ── ARM (Automatic Ripping Machine) ───────────────────────────────
  atelier.services.arm = {
    enable = true;
    nvidiaGpu = false;
    tmdbApiKey = "d02571bf8c4e4d232a05dc9a764992db";
    makemkvKey = "T-BSaJ6gwgMx4eIggWkVYXiVP_6zehm7WAO9dEydvzOHFHoZ6YQ82BL5cGpYDxvyRWnS";
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
    "d /storage/s3 0750 root root -"
    "d /storage/s3/meta 0750 garage garage -"
    "d /storage/s3/data 0750 garage garage -"
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

  # Fix Transmission RPC host whitelist — nixarr doesn't set rpc-host-whitelist-enabled,
  # so Transmission defaults it to true with an empty host list, blocking Tailscale Serve.
  # Append a second ExecStartPre that patches settings.json after nixarr's prestart creates it.
  systemd.services.transmission.serviceConfig.ExecStartPre = [
    "+${pkgs.writeShellScript "transmission-fix-whitelist" ''
      SETTINGS="/storage/.state/nixarr/transmission/.config/transmission-daemon/settings.json"
      if [ -f "$SETTINGS" ]; then
        ${pkgs.jq}/bin/jq '."rpc-host-whitelist-enabled" = false' "$SETTINGS" > "$SETTINGS.tmp"
        mv "$SETTINGS.tmp" "$SETTINGS"
        chown transmission:media "$SETTINGS"
        chmod 600 "$SETTINGS"
      fi
    ''}"
  ];

  # ── ProtonVPN NAT-PMP port forwarding ─────────────────────────────────
  # Requests a public port from ProtonVPN's gateway every 45s via NAT-PMP
  # and pushes it to Transmission inside the VPN namespace.
  systemd.services.protonvpn-port-forward = {
    description = "NAT-PMP port forwarding through ProtonVPN for Transmission";
    bindsTo = [
      "wg.service"
      "transmission.service"
    ];
    after = [
      "wg.service"
      "transmission.service"
    ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.JoinsNamespaceOf = "transmission.service";
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      User = "transmission";
      Group = "media";
      ExecStart = pkgs.writeShellScript "protonvpn-port-forward" ''
        sleep 5
        GATEWAY=10.2.0.1
        echo "starting NAT-PMP loop, gateway=$GATEWAY"
        while true; do
          TCP_OUT=$(${pkgs.libnatpmp}/bin/natpmpc -a 1 0 tcp 60 -g "$GATEWAY" 2>&1) || true
          ${pkgs.libnatpmp}/bin/natpmpc -a 1 0 udp 60 -g "$GATEWAY" >/dev/null 2>&1 || true
          echo "natpmpc: $TCP_OUT" | head -1
          PORT=$(echo "$TCP_OUT" | ${pkgs.gawk}/bin/awk '/Mapped public port/ {print $4}')
          if [ -n "$PORT" ] && [ "$PORT" -ne 0 ] 2>/dev/null; then
            echo "mapped port $PORT, updating transmission"
            SID=$(${pkgs.curl}/bin/curl -s http://localhost:9091/transmission/rpc 2>&1 | ${pkgs.gnused}/bin/sed -n 's/.*X-Transmission-Session-Id: //p')
            if [ -n "$SID" ]; then
              ${pkgs.curl}/bin/curl -s -X POST \
                "http://localhost:9091/transmission/rpc" \
                -H "X-Transmission-Session-Id: $SID" \
                -H "Content-Type: application/json" \
                --data "{\"method\":\"session-set\",\"arguments\":{\"peer-port\":$PORT}}" \
                >/dev/null 2>&1 || true
              echo "transmission port updated to $PORT"
            fi
          fi
          sleep 45
        done
      '';
    };
  };

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
        handle /garage/* {
          reverse_proxy localhost:3902
        }
        handle /garage-ui/* {
          reverse_proxy localhost:3909
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

  # ── Garage (S3-compatible object store) ─────────────────────────────
  services.garage = {
    enable = true;
    package = pkgs.garage_2;
    settings = {
      metadata_dir = "/storage/s3/meta";
      data_dir = "/storage/s3/data";
      db_engine = "lmdb";
      replication_factor = 1;
      consistency_mode = "none";
      rpc_bind_addr = "[::]:3901";
      rpc_public_addr = "127.0.0.1:3901";
      s3_api = {
        s3_region = "garage";
        api_bind_addr = "[::]:3900";
        root_domain = ".s3.garage.localhost";
      };
      s3_web = {
        bind_addr = "[::]:3902";
        root_domain = ".web.garage.localhost";
      };
      admin = {
        api_bind_addr = "127.0.0.1:3903";
      };
    };
  };

  # Bootstrap garage: generate RPC secret, assign layout, create default key/bucket
  systemd.services.garage-bootstrap = {
    description = "Bootstrap Garage cluster (one-time setup)";
    after = [ "garage.service" ];
    requires = [ "garage.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      EnvironmentFile = config.services.garage.environmentFile or null;
    };
    script = ''
      set -euo pipefail
      GARAGE="${config.services.garage.package}/bin/garage"
      MARKER="/var/lib/garage/.bootstrapped"

      if [ -f "$MARKER" ]; then
        echo "Garage already bootstrapped"
        exit 0
      fi

      # Wait for garage to be ready
      for i in $(seq 1 30); do
        if $GARAGE status 2>/dev/null; then break; fi
        sleep 1
      done

      # Get or generate node ID
      NODE_ID=$($GARAGE node id 2>/dev/null | head -1 || true)
      if [ -z "$NODE_ID" ]; then
        echo "Waiting for node ID..."
        sleep 2
        NODE_ID=$($GARAGE node id 2>/dev/null | head -1)
      fi

      # Assign layout
      $GARAGE layout assign -z dc1 -c 1G "$NODE_ID" || true
      $GARAGE layout apply --version 1 || true

      # Create default bucket and key
      $GARAGE bucket create default || true
      $GARAGE key create default || true
      $GARAGE bucket allow --read --write --owner default --key default || true

      touch "$MARKER"
      echo "Garage bootstrap complete"
    '';
  };

  # Garage Web UI
  systemd.services.garage-webui = {
    description = "Garage Web UI";
    after = [ "garage-bootstrap.service" ];
    wants = [ "garage.service" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      API_BASE_URL = "http://127.0.0.1:3903";
      PORT = "3909";
      BASE_PATH = "/";
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.garage-webui}/bin/garage-webui";
      Restart = "on-failure";
      RestartSec = "5s";
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  boot.zfs.forceImportRoot = false;

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

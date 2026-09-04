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
      permittedInsecurePackages = [ "pnpm-9.15.9" ];
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
    garage-env = {
      file = ../../secrets/garage-env.age;
      owner = "garage";
      group = "garage";
    };
    atticd-env = {
      file = ../../secrets/atticd-env.age;
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
    # Only here because ZFS demands it, and ZFS is only here for the migration
    # escape hatch below. Both come out together once bcachefs has proven itself.
    hostId = "4e4de3a2";
    useDHCP = true;
    networkmanager.enable = false;
  };

  programs.zsh.enable = true;
  programs.direnv.enable = true;

  users.groups.garage = { };
  users.users.garage = {
    isSystemUser = true;
    group = "garage";
    home = "/var/lib/garage";
    createHome = false;
  };

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
        "docker" # drive the daemon over DOCKER_HOST=ssh (kloe's kata sandbox)
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
      443 # HTTP/3: caddy advertises h3 whether or not this is open
    ];
    logRefusedConnections = false;
    rejectPackets = true;
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  # ── Boot ─────────────────────────────────────────────────────────────
  # This machine puts its NVMe behind Intel VMD: the drive lives in synthetic
  # PCI domain 0x10000 behind the VMD endpoint at 0000:bc:05.5, so `nvme` has
  # nothing to bind to until `vmd` has exposed that domain. The facter report
  # now covers both, but they are named here anyway — an initrd that cannot see
  # the root disk is an expensive way to discover the hardware report drifted.
  boot.initrd.availableKernelModules = [
    "vmd"
    "nvme"
  ];

  # A locked root account plus a mount that never appears is an unrecoverable
  # console: sulogin refuses, and there is no way in without rebuilding.
  boot.initrd.systemd.emergencyAccess = true;

  # ── Storage ──────────────────────────────────────────────────────────
  # All of it is bcachefs now. nixpkgs builds the out-of-tree module against
  # this kernel at build time, so a mismatch fails the rebuild, not the boot;
  # the previous generation stays bootable either way.
  boot.supportedFilesystems.bcachefs = true;
  boot.initrd.supportedFilesystems.bcachefs = true;

  # Migration escape hatch, temporary. The 6T pair still carries the old ZFS
  # pool, cleanly exported, right up until it gets formatted. Keeping the module
  # here means a bad restore is answered with `zpool import storage` rather than
  # with a live USB, and the box can simply keep running the old layout on the
  # new hardware while the problem gets sorted out. Delete this line and the
  # hostId above once the bcachefs pool is populated and verified.
  boot.supportedFilesystems.zfs = true;
  boot.zfs.forceImportRoot = false;

  # ── TODO: uncomment once the bcachefs pool exists ────────────────────
  # Both of these are held back until the migration off ZFS creates the
  # filesystem and we know its UUID. Declaring them earlier would leave a mount
  # unit waiting on a device that does not exist and a tiering unit that fails
  # because it requires that mount.
  # # Four devices in one tiered filesystem: both SSDs labelled `ssd`, both 6T
  # # spinners labelled `hdd`, replicas=2. Created by hand during the migration
  # # off ZFS rather than by disko, so nothing in this flake is capable of
  # # reformatting it. `nofail` keeps a bad mount from wedging the boot; the
  # # services that need it already wait on storage.mount via RequiresMountsFor.
  # fileSystems."/storage" = {
  #   device = "UUID=REPLACE-storage-uuid";
  #   fsType = "bcachefs";
  #   options = [ "nofail" ];
  # };
  #
  # # The filesystem-wide policy is writeback: writes land on flash, rebalance
  # # drains them to the platters, hot reads are promoted back. That is right for
  # # the arr databases and kloe's workspaces, and wrong for bulk media, which
  # # would push every downloaded byte through the SSDs to be read once. So the
  # # two bulk trees are pinned to writearound instead: written straight to rust,
  # # promoted to flash only when something actually reads them. Options set on a
  # # directory are inherited by everything created beneath it, so this runs once
  # # and covers future files.
  # systemd.services.storage-tiering = {
  #   description = "bcachefs tiering policy for /storage";
  #   after = [ "storage.mount" ];
  #   requires = [ "storage.mount" ];
  #   wantedBy = [ "multi-user.target" ];
  #   serviceConfig = {
  #     Type = "oneshot";
  #     RemainAfterExit = true;
  #   };
  #   script = ''
  #     ${pkgs.bcachefs-tools}/bin/bcachefs setattr \
  #       --foreground_target=hdd /storage/media /storage/torrents
  #   '';
  # };

  services.bcachefs.autoScrub = {
    enable = true;
    interval = "weekly";
  };

  services.smartd = {
    enable = true;
    autodetect = true;
    notifications.wall.enable = true;
  };

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

  # ── Tangled spindle (CI) ──────────────────────────────────────────
  # Runs the spindle workflow server here (bare-metal x86_64 with KVM), so CI
  # can use real microVMs. The knot stays on terebithia.
  atelier.services.tangled = {
    enable = true;
    owner = "did:plc:krxbvxvis5skq7jj6eot23ul";
    knot.enable = false;
    spindle = {
      enable = true;
      hostname = "spindle.dunkirk.sh";
      # Bind all interfaces so terebithia (the public front) can reach it over
      # Tailscale; the port is restricted to tailscale0 in the firewall below,
      # so it isn't exposed on the LAN.
      bindAddr = "0.0.0.0";
      # 8 logical CPUs / 31 GiB here, shared with the media stack. At 4 GiB +
      # 2 vCPU per microVM, 4 jobs is ~16 GiB / 8 vCPU worst case, leaving RAM
      # (+ swap) and CPU headroom for jellyfin/nixarr/minio.
      maxJobCount = 4;
    };
  };

  # spindle's HTTP port, reachable only over Tailscale (terebithia fronts the
  # public spindle.dunkirk.sh and reverse-proxies here). Not in the global
  # allowedTCPPorts, so the default-deny firewall blocks it on the LAN.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    6555
    8091 # atticd (Nix binary cache), tailnet-only
  ];

  # microVM host prerequisite: the vsock transport for the spindle's in-guest agent.
  boot.kernelModules = [ "vhost_vsock" ];

  # ── gVisor (runsc): sandbox runtime for kloe's shell tool ─────────────
  # kloe runs its per-conversation sandbox in a docker container here over
  # Tailscale with `--runtime runsc`, so untrusted commands execute in gVisor's
  # userspace kernel instead of sharing the host kernel. Plain path-based OCI
  # runtime. (Kata was tried for full-VM isolation but its runtime-rs wedges the
  # daemon on docker's resource/interactive flags on this stack, so gVisor it is.)
  virtualisation.docker.daemon.settings.runtimes.runsc.path = "${pkgs.gvisor}/bin/runsc";
  # Docker 29.5+ adds a private `time` namespace to containers by default; some
  # sandbox runtimes don't implement it. Harmless to disable (containers just
  # share the host clock) and keeps such a runtime from choking on it.
  virtualisation.docker.daemon.settings.features.time-namespaces = false;

  # Docker's storage stays on the root SSD (the default /var/lib/docker). It was
  # briefly moved to the pool to keep kloe's sleeping sandboxes off the small
  # disk, which measured wrong twice over: root is 18G of 204G used, and the
  # pool is a 7200rpm mirror, so the move spent sandbox I/O latency to buy space
  # nobody needed. A per-chat writable layer is small; the shared image is the
  # only big thing and there is one of it.
  #
  # kloe's WORKSPACES do live on the pool (sandbox.workspaceRoot, declared
  # below): those want durability and snapshots, not iops.
  #
  # Bind mounts come off /storage, so the daemon must not start before the pool
  # is mounted — it would write into a directory the mount then hides.
  systemd.services.docker.unitConfig.RequiresMountsFor = "/storage";

  # The weekly `docker system prune -f` (enabled with ARM) removes every STOPPED
  # container, which is precisely how kloe now parks an idle conversation's
  # sandbox. Left alone it would quietly undo the warm tier once a week and hand
  # people back an empty environment. kloe ages its own containers out (a 30-day
  # TTL renewed by use, and a cap on how many sleep at once), so the prune only
  # has to leave them alone.
  virtualisation.docker.autoPrune.flags = [
    "--filter"
    "label!=kloe-sandbox=1"
  ];

  # The identity kloe (on terebithia) lands as. It exists here only to hold a
  # login and the docker group; the tailnet ACL is what decides who may become
  # it, and docker's `dial-stdio` needs a shell to be spawned from.
  users.groups.kloe = { };
  users.users.kloe = {
    isSystemUser = true;
    group = "kloe";
    extraGroups = [ "docker" ];
    home = "/var/lib/kloe";
    createHome = true;
    shell = pkgs.bash;
    # kloe gets a rapid burst of short SSH sessions (terebithia's sandbox doing
    # `docker dial-stdio`), each spinning user@997.service up and down. A deploy
    # that lands mid-teardown finds /run/user/997 half-gone and per-user
    # activation dies with EACCES, failing the whole switch. Linger pins the
    # user manager up so there's no teardown window to race.
    linger = true;
  };

  # ── ARM (Automatic Ripping Machine) ───────────────────────────────
  atelier.services.arm = {
    enable = true;
    nvidiaGpu = false;
    tmdbApiKey = "d02571bf8c4e4d232a05dc9a764992db";
    makemkvKey = "T-BSaJ6gwgMx4eIggWkVYXiVP_6zehm7WAO9dEydvzOHFHoZ6YQ82BL5cGpYDxvyRWnS";
  };

  # GlobalProtect → Tailscale subnet router. The gateway is a full tunnel
  # (pushes 0.0.0.0/0), so we ignore its routes and advertise only these campus
  # ranges: 10.40/16 covers internal services like 10.40.10.48, 163.11/16 is
  # Cedarville's public range plus the internal DNS servers (163.11.75.113/119).
  atelier.services.gpGateway = {
    enable = true;
    routes = [
      "10.40.0.0/16"
      "163.11.0.0/16"
    ];
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
    # spindle microVM image (spindle resolves <name>/spec.json under imageDir)
    "d /var/lib/spindle/images 0755 root root -"
    "L+ /var/lib/spindle/images/nixos - - - - ${
      inputs.tangled.packages.${pkgs.system}.spindle-nixos-image
    }"
    "d /storage/media/movies 2775 root media -"
    "d /storage/media/tv 2775 root media -"
    "d /storage/torrents 2775 root media -"
    "d /storage/torrents/.incomplete 2775 root media -"
    "d /storage/.trash 2775 root media -"
    "d /storage/s3 0750 garage garage -"
    "d /storage/s3/meta 0750 garage garage -"
    "d /storage/s3/data 0750 garage garage -"
    # The durable half of kloe's sandboxes: one directory per conversation,
    # bind-mounted at /workspace (sandbox.workspaceRoot, set on terebithia).
    # kloe creates each chat's directory and reaps it when the chat's sandbox is
    # gone; this is only the root they live under.
    "d /storage/kloe 0755 root root -"
    "d /storage/kloe/workspaces 0711 root root -"
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
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      User = "transmission";
      Group = "media";

      # JoinsNamespaceOf only shares namespaces systemd itself created, and
      # nixarr points transmission at a netns that wg.service made out of band.
      # So this unit was silently running on the host network and every NAT-PMP
      # request went nowhere. Enter the namespace the same way transmission does.
      NetworkNamespacePath = "/run/netns/wg";

      # Inside that netns, 10.0.0.0/8 routes back to the host over veth-wg so the
      # arrs stay reachable, and ProtonVPN's NAT-PMP gateway (10.2.0.1) falls
      # inside that range. A /32 wins on longest-prefix match and puts the
      # gateway back on wg0. Runs as root ("+"), still inside the netns.
      ExecStartPre = "+${pkgs.writeShellScript "protonvpn-pf-route" ''
        ${pkgs.iproute2}/bin/ip route replace 10.2.0.1/32 dev wg0
      ''}";

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
      consistency_mode = "consistent";
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

  # Custom paths need a static user; disable DynamicUser so tmpfiles ownership works
  systemd.services.garage = {
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "garage";
      Group = "garage";
      ExecStartPre = "!${pkgs.bash}/bin/bash -c 'mkdir -p /storage/s3/meta /storage/s3/data && chown garage:garage /storage/s3 && chown -R garage:garage /storage/s3/meta /storage/s3/data'";
    };
    after = [ "storage.mount" ];
    requires = [ "storage.mount" ];
  };

  services.garage.environmentFile = config.age.secrets.garage-env.path;

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
    path = [
      config.services.garage.package
      pkgs.coreutils
    ];
    script = ''
      set -euo pipefail
      GARAGE="${config.services.garage.package}/bin/garage"
      MARKER="/storage/s3/.bootstrapped"

      if [ -f "$MARKER" ]; then
        echo "Garage already bootstrapped"
        exit 0
      fi

      # Wait for garage to be ready
      for i in $(seq 1 30); do
        if $GARAGE status 2>/dev/null; then break; fi
        sleep 1
      done

      # Get node ID (first field only)
      NODE_ID=$($GARAGE node id 2>/dev/null | cut -d' ' -f1 | head -1)
      if [ -z "$NODE_ID" ]; then
        echo "Waiting for node ID..."
        sleep 2
        NODE_ID=$($GARAGE node id 2>/dev/null | cut -d' ' -f1 | head -1)
      fi
      echo "Node ID: $NODE_ID"

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

  # ── Attic (Nix binary cache) ──────────────────────────────────────────
  # Tailnet-only cache so CI and both servers reuse custom-built packages
  # (knot, herald, the tangled bits) instead of recompiling them every deploy.
  # SQLite + local storage under /var/lib/atticd on the SSD root; the tailnet
  # provides transport encryption, so it binds plain HTTP and 8091 is opened
  # only on tailscale0 (same pattern as spindle). The RS256 signing secret
  # lives in the agenix env file.
  services.atticd = {
    enable = true;
    environmentFile = config.age.secrets.atticd-env.path;
    settings.listen = "[::]:8091";
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

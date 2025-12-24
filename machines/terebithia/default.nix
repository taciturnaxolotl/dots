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
    inputs.tangled.nixosModules.knot
    inputs.tangled.nixosModules.spindle
  ];

  nixpkgs = {
    hostPlatform = "aarch64-linux";
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
    };

  time.timeZone = "America/New_York";

  environment.systemPackages = with pkgs; [
    # core
    coreutils
    screen
    bc
    jq
    psmisc
    # cli_utils
    direnv
    zsh
    gum
    vim
    # networking
    xh
    curl
    wget
    dogdns
    inetutils
    mosh
    # nix_tools
    inputs.nixvim.packages.aarch64-linux.default
    nixd
    nil
    nixfmt-rfc-style
    inputs.agenix.packages.aarch64-linux.default
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

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/home/kierank/dots";
  };

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
    cachet = {
      file = ../../secrets/cachet.age;
      owner = "cachet";
    };
    hn-alerts = {
      file = ../../secrets/hn-alerts.age;
      owner = "hn-alerts";
    };
    emojibot = {
      file = ../../secrets/emojibot.age;
      owner = "emojibot";
    };
    cloudflare = {
      file = ../../secrets/cloudflare.age;
      owner = "caddy";
    };
    github-knot-sync = {
      file = ../../secrets/github-knot-sync.age;
      owner = "git";
    };
    battleship-arena = {
      file = ../../secrets/battleship-arena.age;
      owner = "battleship-arena";
    };
    frp-auth-token = {
      file = ../../secrets/frp-auth-token.age;
    };
    l4 = {
      file = ../../secrets/l4.age;
      owner = "l4";
    };
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
  };

  networking = {
    hostName = "terebithia";
    networkmanager.enable = true;
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
        "networkmanager"
        "services"
      ];
    };
    duncan = {
      initialPassword = "changeme";
      isNormalUser = true;
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPe38rGtuixnMpGoCwtzXJ2qkPKt16icS7KI+XO0meAE duncanhalderman@Duncans-MacBook-Air.local"
      ];
      extraGroups = [
        "wheel"
        "networkmanager"
      ];
    };
    root.openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCzEEjvbL/ttqmYoDjxYQmDIq36BabROJoXgQKeh9liBxApwp+2PmgxROzTg42UrRc9pyrkq5kVfxG5hvkqCinhL1fMiowCSEs2L2/Cwi40g5ZU+QwdcwI8a4969kkI46PyB19RHkxg54OUORiIiso/WHGmqQsP+5wbV0+4riSnxwn/JXN4pmnE//stnyAyoiEZkPvBtwJjKb3Ni9n3eNLNs6gnaXrCtaygEZdebikr9kS2g9mM696HvIFgM6cdR/wZ7DcLbG3IdTXuHN7PC3xxL+Y4ek5iMreQIPmuvs4qslbthPGYoYbYLUQiRa9XO5s/ksIj5Z14f7anHE6cuTQVpvNWdGDOigyIVS5qU+4ZF7j+rifzOXVL48gmcAvw/uV68m5Wl/p0qsC/d8vI3GYwEsWG/EzpAlc07l8BU2LxWgN+d7uwBFaJV9VtmUDs5dcslsh8IbzmtC9gq3OLGjklxTfIl6qPiL8U33oc/UwqzvZUrI2BlbagvIZYy6rP+q0= kierank@mockingjay"
    ];
  };

  # Allow passwordless sudo for wheel group (needed for deploy-rs)
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
      80
      443
      28868 # Minecraft server
    ];
    allowedUDPPorts = [
      28869 # Minecraft voice chat
    ];
    logRefusedConnections = false;
    rejectPackets = true;
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };

  services.caddy = {
    enable = true;
    package = pkgs.caddy.withPlugins {
      plugins = [ 
        "github.com/caddy-dns/cloudflare@v0.2.2"
        "github.com/mholt/caddy-ratelimit@v0.1.0"
      ];
      hash = "sha256-bK1967g9KQfW4QcMnlAt+ZjKdOvpaUtTFwvlas7CjSA=";
    };
    email = "me@dunkirk.sh";
    globalConfig = ''
      acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      order rate_limit before basicauth
    '';
    virtualHosts."knot.dunkirk.sh" = {
      extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        }
        reverse_proxy localhost:5555 {
          header_up X-Forwarded-Proto {scheme}
          header_up X-Forwarded-For {remote}
        }
      '';
    };
    virtualHosts."spindle.dunkirk.sh" = {
      extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        }
        reverse_proxy localhost:6555 {
          header_up X-Forwarded-Proto {scheme}
          header_up X-Forwarded-For {remote}
        }
      '';
    };
    virtualHosts."emojibot.dunkirk.sh" = {
      extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        }
        reverse_proxy localhost:3002 {
          header_up X-Forwarded-Proto {scheme}
          header_up X-Forwarded-For {remote}
        }
      '';
    };
    virtualHosts."battleship.dunkirk.sh" = {
      extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        }
        reverse_proxy localhost:8081 {
          header_up X-Forwarded-Proto {scheme}
          header_up X-Forwarded-For {remote}
        }
      '';
    };
    extraConfig = ''
      # Default response for unhandled domains
      :80 {
        respond "404 - Looks like this bridge doesn't have an end" 404
      }
      :443 {
        respond "404 - Looks like this bridge doesn't have an end" 404
      }
    '';
  };

  systemd.services.caddy.serviceConfig = {
    EnvironmentFile = config.age.secrets.cloudflare.path;
  };

  atelier.services.cachet = {
    enable = true;
    domain = "cachet.dunkirk.sh";
    secretsFile = config.age.secrets.cachet.path;
  };

  atelier.services.hn-alerts = {
    enable = true;
    domain = "hn.dunkirk.sh";
    secretsFile = config.age.secrets.hn-alerts.path;
  };

  atelier.services.emojibot = {
    enable = true;
    domain = "emojibot.dunkirk.sh";
    secretsFile = config.age.secrets.emojibot.path;
  };

  atelier.services.battleship-arena = {
    enable = true;
    domain = "battleship.dunkirk.sh";
    sshPort = 2222;
    package = inputs.battleship-arena.packages.aarch64-linux.default;
    secretsFile = config.age.secrets.battleship-arena.path;
  };

  services.tangled.knot = {
    enable = true;
    package = inputs.tangled.packages.aarch64-linux.knot;
    appviewEndpoint = "https://tangled.org";
    server = {
      owner = "did:plc:krxbvxvis5skq7jj6eot23ul";
      hostname = "knot.dunkirk.sh";
      listenAddr = "127.0.0.1:5555";
    };
  };

  services.tangled.spindle = {
    enable = true;
    package = inputs.tangled.packages.aarch64-linux.spindle;
    server = {
      owner = "did:plc:krxbvxvis5skq7jj6eot23ul";
      hostname = "spindle.dunkirk.sh";
      listenAddr = "127.0.0.1:6555";
    };
  };

  atelier.services.knot-sync = {
    enable = true;
    secretsFile = config.age.secrets.github-knot-sync.path;
  };

  atelier.services.frps = {
    enable = true;
    domain = "bore.dunkirk.sh";
    authTokenFile = config.age.secrets.frp-auth-token.path;
  };

  atelier.services.indiko = {
    enable = true;
    domain = "indiko.dunkirk.sh";
  };

  atelier.services.l4 = {
    enable = true;
    domain = "l4.dunkirk.sh";
    port = 3004;
    autoUpdate = false;
    secretsFile = config.age.secrets.l4.path;
  };

  services.n8n = {
    enable = true;
    environment = {
      N8N_HOST = "n8n.dunkirk.sh";
      N8N_PROTOCOL = "https";
      WEBHOOK_URL = "https://n8n.dunkirk.sh";
    };
  };

  services.caddy.virtualHosts."n8n.dunkirk.sh" = {
    extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
      }
      reverse_proxy localhost:5678 {
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-For {remote}
      }
    '';
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "console=ttyS0" ];

  system.stateVersion = "23.05";
}

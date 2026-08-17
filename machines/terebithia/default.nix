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
    ../../modules/nixos/services/herald.nix
    ../../modules/nixos/services/paperless.nix
    ../../modules/nixos/services/potluck.nix
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
    zmx-binary
    # networking
    xh
    curl
    wget
    doggo
    inetutils
    mosh
    # nix_tools
    inputs.nixvim.packages.aarch64-linux.default
    nixd
    nil
    nixfmt
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
    fastfetch
    git
    mcrcon
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
    "emojibot/hackclub" = {
      file = ../../secrets/emojibot/hackclub.age;
      owner = "emojibot-hackclub";
    };
    "emojibot/df1317" = {
      file = ../../secrets/emojibot/df1317.age;
      owner = "emojibot-df1317";
    };
    cloudflare = {
      file = ../../secrets/cloudflare.age;
      owner = "caddy";
    };
    github-knot-sync = {
      file = ../../secrets/github-knot-sync.age;
      owner = "git";
    };
    "bore/auth-token".file = ../../secrets/bore/auth-token.age;
    "bore/cookie-hash-key".file = ../../secrets/bore/cookie-hash-key.age;
    "bore/cookie-block-key".file = ../../secrets/bore/cookie-block-key.age;
    "bore/client-secret".file = ../../secrets/bore/client-secret.age;
    l4 = {
      file = ../../secrets/l4.age;
      owner = "l4";
    };
    control = {
      file = ../../secrets/control.age;
      owner = "control";
    };
    herald = {
      file = ../../secrets/herald.age;
      owner = "herald";
    };
    herald-dkim = {
      file = ../../secrets/herald-dkim.age;
      owner = "herald";
      mode = "0400";
    };
    canvas-mcp = {
      file = ../../secrets/canvas-mcp.age;
      owner = "canvas-mcp";
    };
    canvas-mcp-dkim = {
      file = ../../secrets/canvas-mcp-dkim.age;
      owner = "canvas-mcp";
      mode = "0400";
    };
    cedarlogic = {
      file = ../../secrets/cedarlogic.age;
      owner = "cedarlogic";
    };
    overpass = {
      file = ../../secrets/overpass.age;
      owner = "overpass";
    };
    paperless = {
      file = ../../secrets/paperless.age;
      owner = "paperless";
    };
    potluck = {
      file = ../../secrets/potluck.age;
      owner = "potluck";
    };
    lard = {
      file = ../../secrets/lard.age;
      owner = "lard";
    };
    kloe = {
      file = ../../secrets/kloe.age;
      owner = "kloe";
    };
    paperless-oidc = {
      file = ../../secrets/paperless-oidc.age;
      owner = "paperless";
    };

    "restic/env".file = ../../secrets/restic/env.age;
    "restic/repo".file = ../../secrets/restic/repo.age;
    "restic/password".file = ../../secrets/restic/password.age;
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
    backup.enable = true;
    machine = {
      enable = true;
      tailscaleHost = "terebithia";
    };
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
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCzEEjvbL/ttqmYoDjxYQmDIq36BabROJoXgQKeh9liBxApwp+2PmgxROzTg42UrRc9pyrkq5kVfxG5hvkqCinhL1fMiowCSEs2L2/Cwi40g5ZU+QwdcwI8a4969kkI46PyB19RHkxg54OUORiIiso/WHGmqQsP+5wbV0+4riSnxwn/JXN4pmnE//stnyAyoiEZkPvBtwJjKb3Ni9n3eNLNs6gnaXrCtaygEZdebikr9kS2g9mM696HvIFgM6cdR/wZ7DcLbG3IdTXuHN7PC3xxL+Y4ek5iMreQIPmuvs4qslbthPGYoYbYLUQiRa9XO5s/ksIj5Z14f7anHE6cuTQVpvNWdGDOigyIVS5qU+4ZF7j+rifzOXVL48gmcAvw/uV68m5Wl/p0qsC/d8vI3GYwEsWG/EzpAlc07l8BU2LxWgN+d7uwBFaJV9VtmUDs5dcslsh8IbzmtC9gq3OLGjklxTfIl6qPiL8U33oc/UwqzvZUrI2BlbagvIZYy6rP+q0= kierank@mockingjay"
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDX87YPDSScMZ1x/ZmJmiqL1iEagD7o6CZMVSE+WV/L2mKWFiwRrkMwuT07O0cWBbJGrL8s9EHFMm4AFEiLcMVGnM4ZeEKeUNLnvRwa5s/uAnLNq7kfTCxBHGomfrIz68ZrjeclgG4wcP2v5PfjpNnQICQMaJfwVwJTq5d5Vh+qiFdiS/r5bafbECMJZP68r1rbrTpdi220EQ97dlcMpsL9cwwU+A8nnLfMwpiH0bKJFo6hBKX1/ELENZw+usVRTC0YhY0AAuLyT0FOYKuSzH4YA2yHJnPZJPS7ElwoxdjKMFx1HsUhHWAJbrWxUXDsSDlL7V0PPgMU6sIhCHLgfdLsoYMEB31JR0rcSBXJw11Hpj/N3hBLF9vj0X9ENQ0ea8vkWBDnogBHHros/IafPRerkyhUowxLrovYRNHOHAR/IUKtvewFzfnoPQ0hNSdBMt5vL45+y+e+n1HvMkTNL3P0kd7jigmSoTz3x8AK0c1M84E9BtfsLEpZDRi+7kkiqvE= dunca@DESKTOP-9RIG9UH"
      ];
      extraGroups = [
        "wheel"
        "networkmanager"
      ];
    };
    caddy.extraGroups = [ "duncan" ];
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
      2223 # Herald SSH
      28868 # Minecraft server
    ];
    allowedUDPPorts = [
      28869 # Minecraft voice chat
      443 # HTTP/3: caddy advertises h3 whether or not this is open
    ];
    logRefusedConnections = false;
    rejectPackets = true;
  };

  # Public IP, so sshd takes constant scanner traffic (~25k failed auths/week
  # from ~380 distinct hosts). Key-only auth already makes those unwinnable;
  # this just stops them burning CPU and filling the journal.
  atelier.security.fail2ban.enable = true;

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
      hash = "sha256-5d+U7sdSIUuwj6OK8WutZGsfvshtDj0FKRjkMDNfbxU=";
    };
    email = "kieran@dunkirk.sh";
    # No global acme_dns: every vhost sets its own "dns cloudflare" inline (see
    # mkService.nix and the vhosts below), and a global default would force the
    # DNS challenge onto kieran.westerville.oh.us too, which isn't a Cloudflare
    # zone. Leaving it off lets that one site fall back to HTTP-01.
    globalConfig = ''
      order rate_limit before basicauth
    '';
    virtualHosts."map.dunkirk.sh" = {
      extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        }

        # Kill-check for protected endpoints via control panel
        @protected path /sse /sse/* /tiles/*/markers/pl3xmap_players.json
        handle @protected {
          reverse_proxy localhost:3010 {
            rewrite /kill-check
            header_up X-Orig-Host {host}
            header_up X-Orig-Path {path}

            @allowed status 200
            handle_response @allowed {
              reverse_proxy localhost:8084
            }
            handle_response {
              respond "Temporarily disabled" 503
            }
          }
        }

        # Proxy settings.json through control to conditionally redact fields
        handle /tiles/settings.json {
          reverse_proxy localhost:3010 {
            rewrite /proxy/settings.json
            header_up X-Orig-Host {host}
            header_up X-Orig-Path {path}
            header_up X-Backend-Url http://localhost:8084{path}
          }
        }

        reverse_proxy localhost:8084
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
    repository = "https://github.com/taciturnaxolotl/cachet";
    secretsFile = config.age.secrets.cachet.path;
    healthUrl = "https://cachet.dunkirk.sh/health?detailed=true";
  };

  atelier.services.hn-alerts = {
    enable = true;
    domain = "hn.dunkirk.sh";
    repository = "https://github.com/taciturnaxolotl/hn-alerts";
    secretsFile = config.age.secrets.hn-alerts.path;
    healthUrl = "https://hn.dunkirk.sh/health";
  };

  atelier.services.emojibot.instances = {
    hackclub = {
      enable = true;
      domain = "hc.emojibot.dunkirk.sh";
      port = 3002;
      workspace = "hackclub";
      channel = "C02T3CU03T3";
      repository = "https://github.com/taciturnaxolotl/emojibot";
      secretsFile = config.age.secrets."emojibot/hackclub".path;
      healthUrl = "https://hc.emojibot.dunkirk.sh/health";
    };

    df1317 = {
      enable = true;
      domain = "df.emojibot.dunkirk.sh";
      port = 3005;
      workspace = "df1317";
      channel = "C06SBHMQU8G";
      repository = "https://github.com/taciturnaxolotl/emojibot";
      secretsFile = config.age.secrets."emojibot/df1317".path;
      healthUrl = "https://df.emojibot.dunkirk.sh/health";
    };
  };

  atelier.services.frps = {
    enable = true;
    domain = "bore.dunkirk.sh";
    authTokenFile = config.age.secrets."bore/auth-token".path;
    auth = {
      enable = true;
      clientID = "ikc_FxqNPjQQYBt35vIfO1Xvd";
      clientSecretFile = config.age.secrets."bore/client-secret".path;
      cookieHashKeyFile = config.age.secrets."bore/cookie-hash-key".path;
      cookieBlockKeyFile = config.age.secrets."bore/cookie-block-key".path;
    };
  };

  atelier.services.indiko = {
    enable = true;
    domain = "indiko.dunkirk.sh";
    repository = "https://github.com/taciturnaxolotl/indiko";
    healthUrl = "https://indiko.dunkirk.sh/health";
  };

  atelier.services.l4 = {
    enable = true;
    domain = "l4.dunkirk.sh";
    port = 3004;
    repository = "https://github.com/taciturnaxolotl/l4";
    secretsFile = config.age.secrets.l4.path;
    healthUrl = "https://l4.dunkirk.sh/health";
  };

  atelier.services.control = {
    enable = true;
    domain = "control.dunkirk.sh";
    repository = "https://github.com/taciturnaxolotl/control";
    secretsFile = config.age.secrets.control.path;
    healthUrl = "https://control.dunkirk.sh/health";

    flags."map.dunkirk.sh" = {
      name = "Map";
      flags = {
        "block-tracking" = {
          name = "Block Player Tracking";
          description = "Disable real-time player location updates";
          paths = [
            "/sse"
            "/sse/*"
            "/tiles/*/markers/pl3xmap_players.json"
          ];
          redact."/tiles/settings.json" = [ "players" ];
        };
      };
    };
  };

  atelier.services.traverse = {
    enable = true;
    domain = "traverse.dunkirk.sh";
    repository = "https://github.com/taciturnaxolotl/traverse";
    healthUrl = "https://traverse.dunkirk.sh";
  };

  atelier.services.herald = {
    enable = true;
    domain = "herald.dunkirk.sh";
    sshPort = 2223;
    externalSshPort = 2223;
    httpPort = 8085;
    smtp = {
      host = "smtp.mailchannels.net";
      port = 587;
      user = "kieranklukascontracting";
      from = "herald@dunkirk.sh";
      dkim = {
        selector = "mailchannels";
        domain = "dunkirk.sh";
        privateKeyFile = "${config.age.secrets.herald-dkim.path}";
      };
    };
    secretsFile = config.age.secrets.herald.path;
  };

  atelier.services.canvas-mcp = {
    enable = true;
    domain = "canvas.dunkirk.sh";
    repository = "https://github.com/taciturnaxolotl/canvas-mcp";
    secretsFile = config.age.secrets.canvas-mcp.path;
    healthUrl = "https://canvas.dunkirk.sh/health?detailed=true";
    environment = {
      DKIM_PRIVATE_KEY_FILE = "${config.age.secrets.canvas-mcp-dkim.path}";
    };
  };

  atelier.services.cedarlogic = {
    enable = true;
    domain = "cedarlogic.dunkirk.sh";
    repository = "https://github.com/taciturnaxolotl/CedarLogic";
    secretsFile = config.age.secrets.cedarlogic.path;
    healthUrl = "https://cedarlogic.dunkirk.sh/health";
  };
  atelier.services.overpass = {
    enable = true;
    domain = "overpass.dunkirk.sh";
    repository = "https://github.com/taciturnaxolotl/overpass";
    secretsFile = config.age.secrets.overpass.path;
    healthUrl = "https://overpass.dunkirk.sh/health";
    environment.FLARESOLVERR_URL = "http://localhost:8191";
  };

  atelier.services.paperless = {
    enable = true;
    domain = "paperless.dunkirk.sh";
    healthUrl = "https://paperless.dunkirk.sh/health/";
    oidc = {
      enable = true;
      clientId = "ikc_W1wkoHyC8Szw99faIaiGj";
      clientSecretFile = config.age.secrets.paperless-oidc.path;
      issuer = "https://indiko.dunkirk.sh";
    };
  };

  services.paperless.passwordFile = config.age.secrets.paperless.path;

  atelier.services.pear = {
    enable = true;
    domain = "pear.dunkirk.sh";
    healthUrl = "https://pear.dunkirk.sh";
  };

  atelier.services.potluck = {
    enable = true;
    domain = "backend.potluck.dunkirk.sh";
    secretsFile = config.age.secrets.potluck.path;
    healthUrl = "https://backend.potluck.dunkirk.sh/healthz";
  };

  atelier.services.lard = {
    enable = true;
    domain = "lard.dunkirk.sh";
    secretsFile = config.age.secrets.lard.path;
    healthUrl = "https://lard.dunkirk.sh/healthz";
    allowedClientIds = [
      "ikc_NEil8GK01UX2O9AvbcDrv"
      "ikc_cskXitSS6XFSDzvyq3NBA"
    ]; # lard, kloe
    allowedUsers = [ "https://dunkirk.sh/" ];
    collectorClientId = "ikc_NEil8GK01UX2O9AvbcDrv";
  };

  atelier.services.kloe = {
    enable = true;
    domain = "kloe.dunkirk.sh";
    repository = "https://github.com/taciturnaxolotl/kloe";
    secretsFile = config.age.secrets.kloe.path;
    healthUrl = "https://kloe.dunkirk.sh/health";

    settings = {
      auth = {
        enabled = true;
        issuer = "https://indiko.dunkirk.sh";
        clientId = "ikc_cskXitSS6XFSDzvyq3NBA";
        clientSecret = "$KLOE_CLIENT_SECRET";
        # Anyone with an indiko account may sign in; roles decide what they
        # get. A role is held by name or by what indiko calls someone, and a
        # name wins: indiko only reports a role during a fresh login, where a
        # name here applies the moment it deploys.
        allowedSubs = [ ];
        roles = {
          owner = {
            admin = true;
            sandbox = true;
            publish = true;
            subs = [ "https://dunkirk.sh/" ];
            # "admin" is what the kloe client offers in indiko; "owner" is kept
            # in case the client is ever renamed to match this side.
            providerRoles = [
              "admin"
              "owner"
            ];
          };
          # Everyone else: chat, whichever models are marked for guests, and
          # whatever they connect their own account to. No shell, which is this
          # machine, and no public links, which are this domain.
          guest = {
            providerRoles = [ "guest" ];
          };
        };
      };

      # Encrypts the provider credentials users hand over (their own hyper
      # grant, a pasted key). Without it kloe refuses to store one rather than
      # writing it into a database that gets backed up offsite.
      security.credentialKey = "$KLOE_CREDENTIAL_KEY";

      lard = {
        enabled = true;
        baseUrl = "https://lard.dunkirk.sh";
      };

      search = {
        backends = [
          {
            provider = "exa";
            apiKey = "$EXA_API_KEY";
            searchType = "auto";
          }
          {
            provider = "ceramic";
            apiKey = "$CERAMIC_API_KEY";
          }
        ];
        # Asked of each backend and kept after fusion. Ceramic will go to 50;
        # this is the dial that decides how much of a search the model reads.
        maxResults = 10;
      };

      fetch.renderer = {
        provider = "flaresolverr";
        endpoint = "https://flaresolver.dunkirk.sh/v1";
        timeoutMs = 60000;
      };

      # Runs on prattle's docker under gVisor, reached over Tailscale SSH as
      # the kloe user declared there. The tailnet ACL is the thing that has to
      # allow the hop; nothing here can grant it.
      sandbox = {
        enabled = true;
        image = "buildpack-deps:bookworm-scm";
        runtime = "runsc";
        dockerHost = "ssh://kloe@prattle";
        network = true;
      };

      providers = [
        {
          id = "hyper";
          apiKey = "$HYPER_API_KEY";
          apiEndpoint = "https://hyper.charm.land/v1";
          type = "hyper";
          maxConcurrency = 4;
          # The device endpoints sit at the app root, not under /v1, so a user
          # can approve kloe from hyper's own page and spend their own credits.
          oauth = {
            flow = "hyper-device";
            baseUrl = "https://hyper.charm.land";
          };
        }
        {
          id = "llmsolutions";
          apiKey = "$LLMSOLUTIONS_API_KEY";
          apiEndpoint = "https://llmsolutions.top/v1";
          type = "openai-compat";
          maxConcurrency = 4;
          models = [
            {
              id = "deepseek-v4-flash-0731";
              name = "DeepSeek V4 Flash (llmsolutions)";
              context_window = 1048576;
              default_max_tokens = 32768;
            }
          ];
        }
      ];
    };
  };

  atelier.services.tangled = {
    enable = true;
    owner = "did:plc:krxbvxvis5skq7jj6eot23ul";
    knot = {
      motd = ''
        🧶 welcome to kieran's knot!
      '';
      hostname = "knot.dunkirk.sh";
      syncSecretsFile = config.age.secrets.github-knot-sync.path;
    };
    # Spindle moved to prattle (bare-metal x86_64 with KVM → real microVMs).
    # terebithia is a nested VM without EL2, so it has no /dev/kvm.
    spindle = {
      enable = false;
      hostname = "spindle.dunkirk.sh";
    };
  };

  atelier.services.tangle-of-trust = {
    enable = false;
    domain = "tangle-of-trust.dunkirk.sh";
    port = 9090;
  };

  # FlareSolverr — Cloudflare bypass proxy for GasBuddy scraping
  virtualisation.docker.enable = true;
  virtualisation.oci-containers.backend = "docker";
  virtualisation.oci-containers.containers.flaresolverr = {
    image = "ghcr.io/flaresolverr/flaresolverr:latest";
    ports = [ "127.0.0.1:8191:8191" ];
    environment.LOG_LEVEL = "info";
  };

  services.caddy.virtualHosts."flaresolver.dunkirk.sh" = {
    extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
      }

      reverse_proxy localhost:8191
    '';
  };

  services.caddy.virtualHosts."terebithia.dunkirk.sh" = {
    extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
      }
      root * ${./static}
      file_server
    '';
  };

  # Direct A record to terebithia's public IP (not a Cloudflare zone). With no
  # DNS challenge configured for it, caddy provisions this cert via HTTP-01
  # (port 80 is public), so the redirect works over HTTPS.
  services.caddy.virtualHosts."kieran.westerville.oh.us" = {
    extraConfig = ''
      header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
      }
      redir https://dunkirk.sh?from=westerville permanent
    '';
  };

  # ── Prattle reverse proxies (over Tailscale) ─────────────────────────
  services.caddy.virtualHosts."jellyfin.dunkirk.sh" = {
    extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
      }
      reverse_proxy prattle:8096
    '';
  };

  # Spindle (Tangled CI) runs on prattle for KVM microVMs; terebithia is the
  # public front. Proxy over Tailscale to prattle's spindle HTTP port.
  services.caddy.virtualHosts."spindle.dunkirk.sh" = {
    extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
      }
      reverse_proxy prattle:6555 {
        header_up X-Forwarded-Proto {scheme}
        header_up X-Forwarded-For {remote}
      }
    '';
  };

  services.caddy.virtualHosts."s3.dunkirk.sh" = {
    extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
      }
      reverse_proxy prattle:3900
    '';
  };

  swapDevices = [
    {
      device = "/var/swapfile";
      size = 4096;
    }
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "console=ttyS0" ];

  # Uncapped journald defaults to 10% of the filesystem, which is ~14G here, and
  # 30 services on a public IP fill that faster than you'd think (it was at 3.9G).
  # More headroom than prattle's 100M/7day on purpose: this box is the one facing
  # the internet, so fail2ban and auth history are worth keeping around longer.
  services.journald.extraConfig = ''
    SystemMaxUse=1G
    MaxRetentionSec=14day
  '';

  system.stateVersion = "23.05";
}

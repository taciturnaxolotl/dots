{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
let
  # prattle already runs flaresolverr as a native service, and reaches this box
  # over the tailnet. Everything here points at that one instead of a second
  # copy in docker: same work, off the two cores that also serve every vhost.
  flaresolverr = "http://prattle:8191";

  # Sampled hard because zap builds every field before this filter deletes it;
  # logging was 48% of caddy's CPU against 10.5% for the proxy itself.
  # tls + HSTS + one upstream, which is the whole of several vhosts here. Raw
  # extraConfig stays for any vhost with actual logic in it.
  proxyTo = upstream: ''
    tls {
      dns cloudflare {env.CLOUDFLARE_API_TOKEN}
    }
    header {
      Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    }
    reverse_proxy ${upstream}
  '';

  leanAccessLog = host: ''
    output file /var/log/caddy/access-${host}.log
    sampling {
      interval 1s
      first 5
      thereafter 100
    }
    format filter {
      wrap json
      fields {
        request>headers delete
        resp_headers delete
      }
    }
  '';
in
{
  imports = [
    ./disk-config.nix
    ./home-manager.nix

    (inputs.import-tree ../../modules/nixos)
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
    ethtool
    # nix_tools
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
    cedarengine = {
      file = ../../secrets/cedarengine.age;
      owner = "cedarengine";
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
    root.openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCzEEjvbL/ttqmYoDjxYQmDIq36BabROJoXgQKeh9liBxApwp+2PmgxROzTg42UrRc9pyrkq5kVfxG5hvkqCinhL1fMiowCSEs2L2/Cwi40g5ZU+QwdcwI8a4969kkI46PyB19RHkxg54OUORiIiso/WHGmqQsP+5wbV0+4riSnxwn/JXN4pmnE//stnyAyoiEZkPvBtwJjKb3Ni9n3eNLNs6gnaXrCtaygEZdebikr9kS2g9mM696HvIFgM6cdR/wZ7DcLbG3IdTXuHN7PC3xxL+Y4ek5iMreQIPmuvs4qslbthPGYoYbYLUQiRa9XO5s/ksIj5Z14f7anHE6cuTQVpvNWdGDOigyIVS5qU+4ZF7j+rifzOXVL48gmcAvw/uV68m5Wl/p0qsC/d8vI3GYwEsWG/EzpAlc07l8BU2LxWgN+d7uwBFaJV9VtmUDs5dcslsh8IbzmtC9gq3OLGjklxTfIl6qPiL8U33oc/UwqzvZUrI2BlbagvIZYy6rP+q0= kierank@mockingjay"
    ];
  };

  # Allow passwordless sudo for wheel group (needed for deploy-rs)
  security.sudo.wheelNeedsPassword = false;

  atelier.serviceAdmins.idk = {
    keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN/587UmFEqNTCKARWmTPwbBYQl/86SYTGEGvCCNxVH4"
    ];
    # botme and cap both live on prattle now, and the matching entry is there.
    # What stays here is the access log, which caddy still writes because this
    # box is still the public face, and the account itself, which is the way in:
    # idk has no tailnet identity, so they jump from here to prattle's sshd on
    # 2222 (Tailscale SSH owns 22 and would want an identity they do not have).
    logFiles.botme-access = "/var/log/caddy/access-botme.idk.dunkirk.sh.log";
  };

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
      3478 # DERP STUN, never proxied
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
    # Advertises 0.0.0.0/0 and ::/0 as an exit node, so it needs the server half:
    # "client" leaves IPv6 forwarding off and the console flags the node as
    # unable to relay. IPv4 was already on courtesy of docker, hiding the gap.
    useRoutingFeatures = "both";
  };

  services.caddy = {
    enable = true;
    package = pkgs.caddy.withPlugins {
      plugins = [
        "github.com/caddy-dns/cloudflare@v0.2.2"
        "github.com/mholt/caddy-ratelimit@v0.1.0"
      ];
      hash = "sha256-pOKH4KP0vbyhxlvMiWmkHoziKXu6O6PKRjPHjflPZuQ=";
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
    # kloe's HTML artifacts, run on a host that owns nothing: one path, and no
    # to everything else.
    virtualHosts."artifactory.dunkirk.sh" = {
      extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }

        handle /a/* {
          reverse_proxy localhost:${toString config.atelier.services.kloe.port}
        }
        handle {
          respond "404 - this door is for artifacts" 404
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

    # Go collects when the heap doubles, which at the default GOGC=100 and a
    # 426MB live heap means a cycle every 426MB of allocation. The profile put
    # mallocgc at 18% cumulative, much of it the per-request logging fields and
    # the read/write buffers for a few thousand open connections. Trading some
    # of the 8GB this box is not using for a third of the collections is the
    # cheapest CPU on offer here.
    #
    # GOMEMLIMIT is the backstop, not the target: it makes the collector get
    # aggressive again before RSS can run away on a 12GB box. Caddy was at
    # ~1GB RSS when this went in.
    Environment = [
      "GOGC=300"
      "GOMEMLIMIT=3GiB"
    ];
  };

  # botme runs on prattle now: 8 cores at load 0.9 against this box's 2 at 14.
  # Same shape as the jellyfin vhost below, terebithia keeps the public name and
  # the certificate while prattle does the work.
  # Access logging is most of what caddy does on this two-core box: a 30s CPU
  # profile put logRequest at 29% against 39% for the whole of ServeHTTP.
  #
  # The header maps are the bulk of it, but a `format filter` that deletes them
  # only saves the write: caddy builds the fields during Check and the filter
  # runs afterwards, which measured 29% -> 27%. It still shrinks the file by
  # most of its width, so botme keeps it -- that log is read, by idk, for the
  # source addresses.
  #
  # cap's log is two thirds of the request volume and nobody reads it; the
  # dashboard's numbers come from stats.db, not from here. Dropping it is the
  # only thing that actually removes the work. Set it back to
  # `leanAccessLog "cap.dunkirk.sh"` if that history is ever wanted.
  services.caddy.virtualHosts."botme.idk.dunkirk.sh".logFormat = leanAccessLog "botme.idk.dunkirk.sh";
  services.caddy.virtualHosts."cap.dunkirk.sh".logFormat = lib.mkForce null;
  # bore's wildcard is the worst of both: a dev server behind it turns one page
  # load into fifty module requests, and each one writes a json line into a log
  # nobody reads. Same call as cap's, ten times the volume.
  services.caddy.virtualHosts."*.bore.dunkirk.sh".logFormat = lib.mkForce null;

  services.caddy.virtualHosts."botme.idk.dunkirk.sh" = {
    extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
      }

      reverse_proxy prattle:3012 {
        # With one upstream and no health checking, caddy dials every request
        # even when nothing is listening. With botme stopped, the solvers still
        # knocking put 1667 dials/s in SYN-SENT and 62% of a core into retrying
        # a socket that was never going to answer. Three failures in ten seconds
        # takes it out of rotation, which turns that into one probe per ten
        # seconds and an immediate 503. The cost is that a blip of three errors
        # serves 503 to everyone for ten seconds; cheaper than the alternative
        # measured above.
        fail_duration 10s
        max_fails 3

        transport http {
          # Caddy keeps 32 idle upstream connections per host by default. At
          # solver load there are ~1500 requests in flight, so 32 went back in
          # the pool and the rest were closed and redialled: 592 new outbound
          # connections a second against 300 requests, 10k sockets in TIME-WAIT
          # to this upstream alone and 35k across the box, against an ephemeral
          # range of 28k. The whole range cycled about every 90 seconds, which
          # is where the 502s came from, and a 100ms app answered in 3.4s.
          #
          # A 25s CPU profile put 28% of caddy in Transport.dialConnFor and 24%
          # in the connect() syscall alone. Each redial is also a three-way
          # handshake through tailscaled's userspace wireguard, about a quarter
          # of the 15.8k packets/s it was pushing.
          #
          # Sized above the concurrency the flood actually reaches: a pool
          # smaller than that degrades to a dial per request again.
          keepalive_idle_conns 4000
          keepalive_idle_conns_per_host 2000
        }
      }
    '';
  };

  # cap runs on prattle now, next to the botme that calls it once per solve.
  # This box keeps the public name, the certificate, and the userland-proxy work
  # it no longer has to do.
  services.caddy.virtualHosts."cap.dunkirk.sh" = {
    extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }

      reverse_proxy prattle:3013 {
        # Same breaker as botme's vhost, same reason.
        fail_duration 10s
        max_fails 3

        # cap keys its rate limit and blocklist on the *leftmost*
        # X-Forwarded-For value, which is whatever the client sent. Replacing
        # the header instead of appending to it leaves cap one value it can
        # trust: the peer caddy actually talked to. {client_ip} is the right
        # source for it because dunkirk.sh is DNS-only, so caddy's peer is
        # the visitor rather than a CDN edge.
        header_up X-Forwarded-For {client_ip}

        # Same pool as botme's, for the same reason: cap is the widget half of
        # every solve, so it sees the flood at the same scale and churned
        # connections the same way.
        transport http {
          keepalive_idle_conns 4000
          keepalive_idle_conns_per_host 2000
        }
      }
    '';
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

  atelier.services.cedarengine = {
    enable = true;
    domain = "cedarengine.dunkirk.sh";
    repository = "https://github.com/taciturnaxolotl/cedarengine";
    secretsFile = config.age.secrets.cedarengine.path;
    healthUrl = "https://cedarengine.dunkirk.sh/health";
  };

  atelier.services.overpass = {
    enable = true;
    domain = "overpass.dunkirk.sh";
    repository = "https://github.com/taciturnaxolotl/overpass";
    secretsFile = config.age.secrets.overpass.path;
    healthUrl = "https://overpass.dunkirk.sh/health";
    environment.FLARESOLVERR_URL = flaresolverr;
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
    environment.FLARESOLVERR_URL = "${flaresolverr}/v1";
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
        allowedSubs = [ ];
        roles = {
          owner = {
            admin = true;
            sandbox = true;
            publish = true;
            models = [ "*" ];
            search = [ "*" ];
            subs = [ "https://dunkirk.sh/" ];
            providerRoles = [
              "admin"
              "owner"
            ];
          };

          guest = {
            models = [ "hyper/deepseek-v4-flash-0731" ];
            search = [ "duckduckgo" ];
            sandbox = true;
            usdPerDay = 0.5;
            tokensPerDay = 4000000;
            providerRoles = [ "guest" ];
          };
        };
      };

      # Encrypts the provider credentials users hand over
      security.credentialKey = "$KLOE_CREDENTIAL_KEY";

      server.artifactOrigin = "https://artifactory.dunkirk.sh";

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
        maxResults = 10;
      };

      fetch.renderer = {
        provider = "flaresolverr";
        endpoint = "${flaresolverr}/v1";
        timeoutMs = 60000;
      };

      # Runs on prattle's docker under gVisor
      sandbox = {
        enabled = true;
        image = "buildpack-deps:bookworm-scm";
        runtime = "runsc";
        dockerHost = "ssh://kloe@prattle";
        network = true;
        workspaceRoot = "/storage/kloe/workspaces";
      };

      providers = [
        {
          id = "hyper";
          apiKey = "$HYPER_API_KEY";
          apiEndpoint = "https://hyper.charm.land/v1";
          type = "hyper";
          maxConcurrency = 4;
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

  # ── DERP ─────────────────────────────────────────────────────────────
  # Private relay for the tailnet. prattle sits behind campus symmetric NAT with
  # no port mapping, so it can never hole-punch to an off-LAN peer and always
  # falls back to a relay. Tailscale's shared ord node ran 33ms at rest and 1.6s
  # under load; both nodes already reach terebithia directly, so relaying here
  # trades a hop for an uncontended one.
  services.tailscale.derper = {
    enable = true;
    domain = "derp.dunkirk.sh";
    # Answer only for our own tailnet, not as an open relay for the internet.
    verifyClients = true;
    # Caddy owns 443; the bundled nginx would fight it for the port.
    configureNginx = false;
    # Would also expose derper's plaintext port, which only caddy should reach.
    # STUN's UDP 3478 is opened with the rest of the firewall.
    openFirewall = false;
  };

  # DERP rides an HTTP Upgrade on /derp, which reverse_proxy passes through.
  services.caddy.virtualHosts."derp.dunkirk.sh".extraConfig =
    proxyTo "localhost:${toString config.services.tailscale.derper.port}";

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
  services.caddy.virtualHosts."jellyfin.dunkirk.sh".extraConfig = proxyTo "prattle:8096";

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

  services.caddy.virtualHosts."s3.dunkirk.sh".extraConfig = proxyTo "prattle:3900";

  # ── Beef reverse proxy (over Tailscale) ──────────────────────────────
  # integrand serves its own landing page, so there is only one thing to proxy.
  services.caddy.virtualHosts."integrand.dunkirk.sh" = {
    extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }
      header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
      }

      # /v1/snip runs a model on beef's CPU for whoever asks, so meter the API
      # and leave the page alone.
      @api path /v1/*
      rate_limit @api {
        zone integrand_api {
          key {http.request.remote_ip}
          events 20
          window 1m
        }
      }

      request_body {
        max_size 2MB
      }

      reverse_proxy beef:8765
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

  # Uncapped journald defaults to 10% of the filesystem which is far too much
  services.journald.extraConfig = ''
    SystemMaxUse=1G
    MaxRetentionSec=14day
  '';

  system.stateVersion = "23.05";
}

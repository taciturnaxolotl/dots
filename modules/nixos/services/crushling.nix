# crushling: a Crush agent per Slack thread, each in its own gVisor sandbox
#
# The bridge is a Gleam app, deployed the usual way: mkService clones it once
# and `gleam run` builds and starts it, so a deploy is a git pull and a restart.
# It has to run on the docker host: each sandbox serves `crush server` on a
# unix socket in a bind mount, and a unix socket can't cross machines.
#
# What else lives here:
# - the sandbox image: kloe's base plus tailscale, gh and ripgrep from nixpkgs.
#   crush itself is NOT in it. It is a static build of Kieran's local
#   megamerge, mounted from `crushBinary`; drop a new one in with a rename.
# - a `runsc-uds` runtime: gVisor only shares a socket it creates in a bind
#   mount with the host when run with `--host-uds=create`.
# - a docker network whose egress is filtered: sandboxes reach the internet
#   but not the LAN, campus, the tailnet, or this host, except the bridge's
#   Slack tools on the gateway. Without it a sandbox reaches the tailnet
#   through this machine.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  mkService = import ../../lib/mkService.nix;
  cfg = config.atelier.services.crushling;

  gateway = "${cfg.network.prefix}.1";

  # tailscaled from nixpkgs is a wrapper script; the static binary behind it
  # is what works in the sandbox, and `tailscale` is the same binary.
  tailscaled = "${pkgs.tailscale}/bin/.tailscaled-wrapped";

  image = pkgs.dockerTools.buildLayeredImage {
    name = "crushling-sandbox";
    fromImage = pkgs.dockerTools.pullImage {
      imageName = "buildpack-deps";
      imageDigest = "sha256:5bac6b3020afcf0358de87990605d5dc4c3f060629381912266b9b9278375af3";
      hash = "sha256-b4xkkRghDp+AFqvLmgyqgei/XFSQ2MJ8KZNBh2wNcFQ=";
      finalImageName = "buildpack-deps";
      finalImageTag = "bookworm-scm";
      os = "linux";
      arch = "amd64";
    };
    # Real directories with links into the store, so the base image's /usr
    # and /bin stay as they are.
    extraCommands = ''
      mkdir -p usr/local/bin
      ln -s ${tailscaled} usr/local/bin/tailscaled
      ln -s ${tailscaled} usr/local/bin/tailscale
      ln -s ${pkgs.gh}/bin/gh usr/local/bin/gh
      ln -s ${pkgs.ripgrep}/bin/rg usr/local/bin/rg
    '';
  };
  imageRef = "crushling-sandbox:${image.imageTag}";

  # Addresses a sandbox must not reach: private and link-local ranges (the
  # LAN, other docker networks), CGNAT (the tailnet), loopback, multicast, and
  # Cedarville's range, which this host routes through the campus gateway.
  blocked = [
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "100.64.0.0/10"
    "169.254.0.0/16"
    "127.0.0.0/8"
    "224.0.0.0/4"
    "163.11.0.0/16"
  ];

  baseModule = mkService {
    name = "crushling";
    description = "crushling — a Crush agent per Slack thread";
    # The agents' Slack tools, served on the sandbox network's gateway.
    defaultPort = 7469;
    runtime = "custom";
    startCommand = "gleam run";

    extraOptions = {
      uid = lib.mkOption {
        type = lib.types.int;
        description = ''
          The bridge's uid, pinned: sandboxes run as it, and it owns their
          workspaces on disk.
        '';
      };

      threadsDir = lib.mkOption {
        type = lib.types.str;
        default = "/storage/crushling/threads";
        description = "One directory per Slack thread: workspace, socket, meta.";
      };

      crushBinary = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.dataDir}/bin/crush";
        defaultText = lib.literalExpression ''"''${dataDir}/bin/crush"'';
        description = ''
          A static linux/amd64 `crush` mounted into every sandbox. Replace it
          by renaming a new build over it; new sandboxes pick it up.
        '';
      };

      network = {
        name = lib.mkOption {
          type = lib.types.str;
          default = "crushling";
        };
        prefix = lib.mkOption {
          type = lib.types.str;
          default = "172.30.0";
          description = "The /24 the sandboxes get; the gateway is `.1`.";
        };
      };

      dns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "1.1.1.1"
          "9.9.9.9"
        ];
        description = "Docker's own DNS doesn't answer gVisor on a custom network.";
      };

      tailscaleTag = lib.mkOption {
        type = lib.types.str;
        default = "tag:crushling";
      };

      events = {
        address = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
          description = ''
            Where Slack's events are taken over HTTP, at /slack/events. Only
            used when the secrets file sets SLACK_SIGNING_SECRET; without it
            the bridge uses Socket Mode.
          '';
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = 7470;
        };
      };
    };

    extraConfig = cfg: {
      atelier.services.crushling = {
        # Slack's events come through a proxy on another host, if at all.
        caddy.enable = false;
        _ports = [ cfg.events.port ];
        environment = {
          HOME = cfg.dataDir;
          CRUSHLING_ROOT = cfg.threadsDir;
          CRUSHLING_IMAGE = imageRef;
          CRUSHLING_RUNTIME = "runsc-uds";
          CRUSHLING_NETWORK = cfg.network.name;
          CRUSHLING_CRUSH = cfg.crushBinary;
          CRUSHLING_DNS = lib.concatStringsSep "," cfg.dns;
          CRUSHLING_MCP_BIND = gateway;
          CRUSHLING_MCP_PORT = toString cfg.port;
          CRUSHLING_MCP_URL = "http://${gateway}:${toString cfg.port}";
          CRUSHLING_TAILSCALE_TAG = cfg.tailscaleTag;
          CRUSHLING_EVENTS_BIND = cfg.events.address;
          CRUSHLING_EVENTS_PORT = toString cfg.events.port;
        };
        # Workspaces and logins: files at rest, safe to copy while it runs.
        data = {
          files = [
            cfg.threadsDir
            "${cfg.dataDir}/.local/state/crushling"
          ];
          stopForBackup = false;
        };
      };
    };
  };
in
{
  imports = [ baseModule ];

  config = lib.mkIf cfg.enable {
    users.users.crushling = {
      uid = cfg.uid;
      extraGroups = [ "docker" ];
    };
    users.groups.crushling.gid = cfg.uid;

    systemd.tmpfiles.rules = [
      "d ${builtins.dirOf cfg.threadsDir} 0755 root root -"
      "d ${cfg.threadsDir} 0750 crushling crushling -"
      "d ${cfg.dataDir}/bin 0755 crushling crushling -"
    ];

    systemd.services.crushling = {
      after = [
        "docker.service"
        "crushling-sandbox.service"
      ];
      requires = [ "crushling-sandbox.service" ];
      path = [
        pkgs.gleam
        pkgs.erlang
        pkgs.rebar3
        pkgs.docker
        pkgs.coreutils
      ];
      serviceConfig = {
        ReadWritePaths = [ cfg.threadsDir ];
        # The first start fetches packages and compiles.
        TimeoutStartSec = lib.mkForce "5min";
        # Running turns get a minute to finish before they are cancelled.
        TimeoutStopSec = "90s";
      };
    };

    virtualisation.docker.daemon.settings.runtimes.runsc-uds = {
      path = "${pkgs.gvisor}/bin/runsc";
      runtimeArgs = [ "--host-uds=create" ];
    };

    # Stopped sandboxes are how an idle thread keeps its installed state.
    virtualisation.docker.autoPrune.flags = [
      "--filter"
      "label!=crushling-sandbox=1"
    ];

    # Load the image, make the network and filter its egress. Rerun whenever
    # docker restarts, since a restart drops the DOCKER-USER rules.
    systemd.services.crushling-sandbox = {
      description = "crushling sandbox image and network";
      after = [ "docker.service" ];
      requires = [ "docker.service" ];
      partOf = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.docker
        pkgs.iptables
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -eu
        docker image inspect ${imageRef} >/dev/null 2>&1 || docker load -i ${image}

        docker network inspect ${cfg.network.name} >/dev/null 2>&1 ||
          docker network create \
            --subnet ${cfg.network.prefix}.0/24 --gateway ${gateway} \
            -o com.docker.network.bridge.name=br-crushling \
            ${cfg.network.name}

        iptables -N CRUSHLING-EGRESS 2>/dev/null || iptables -F CRUSHLING-EGRESS
        iptables -A CRUSHLING-EGRESS -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
        ${lib.concatMapStrings (net: ''
          iptables -A CRUSHLING-EGRESS -d ${net} -j REJECT
        '') blocked}
        iptables -A CRUSHLING-EGRESS -o tailscale0 -j REJECT
        iptables -C DOCKER-USER -i br-crushling -j CRUSHLING-EGRESS 2>/dev/null ||
          iptables -I DOCKER-USER 1 -i br-crushling -j CRUSHLING-EGRESS
      '';
    };

    # Traffic to this host itself goes through INPUT, not docker's chains: the
    # sandboxes reach the Slack tools and nothing else here. The firewall
    # rebuilds nixos-fw on every reload, so these live with it.
    networking.firewall.extraCommands = ''
      iptables -I nixos-fw 1 -i br-crushling -j nixos-fw-refuse
      iptables -I nixos-fw 1 -i br-crushling -p tcp --dport ${toString cfg.port} -j nixos-fw-accept
    '';
  };
}

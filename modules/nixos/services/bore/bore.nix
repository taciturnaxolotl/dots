{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.atelier.services.frps;
in
{
  options.atelier.services.frps = {
    enable = lib.mkEnableOption "frp server for tunneling services";

    bindAddr = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Address to bind frp server to";
    };

    bindPort = lib.mkOption {
      type = lib.types.port;
      default = 7000;
      description = "Port for frp control connection";
    };

    vhostHTTPPort = lib.mkOption {
      type = lib.types.port;
      default = 7080;
      description = "Port for HTTP virtual host traffic";
    };

    allowedTCPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = lib.lists.range 20000 20099;
      example = [ 20000 20001 20002 20003 20004 ];
      description = "TCP port range to allow for TCP tunnels (default: 20000-20099)";
    };

    allowedUDPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = lib.lists.range 20000 20099;
      example = [ 20000 20001 20002 20003 20004 ];
      description = "UDP port range to allow for UDP tunnels (default: 20000-20099)";
    };

    authToken = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Authentication token for clients (deprecated: use authTokenFile)";
    };

    authTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to file containing authentication token";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      example = "bore.dunkirk.sh";
      description = "Base domain for subdomains (e.g., *.bore.dunkirk.sh)";
    };

    enableCaddy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically configure Caddy reverse proxy for wildcard domain";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.authToken != null || cfg.authTokenFile != null;
        message = "Either authToken or authTokenFile must be set for frps";
      }
    ];

    # Open firewall ports for frp control connection and TCP/UDP tunnels
    networking.firewall.allowedTCPPorts = [ cfg.bindPort ] ++ cfg.allowedTCPPorts;
    networking.firewall.allowedUDPPorts = cfg.allowedUDPPorts;

    # frp server service
    systemd.services.frps =
      let
        tokenConfig =
          if cfg.authTokenFile != null then
            ''
              auth.tokenSource.type = "file"
              auth.tokenSource.file.path = "${cfg.authTokenFile}"
            ''
          else
            ''auth.token = "${cfg.authToken}"'';
        
        configFile = pkgs.writeText "frps.toml" ''
          bindAddr = "${cfg.bindAddr}"
          bindPort = ${toString cfg.bindPort}
          vhostHTTPPort = ${toString cfg.vhostHTTPPort}

          # Dashboard and Prometheus metrics
          webServer.addr = "127.0.0.1"
          webServer.port = 7400
          enablePrometheus = true

          # Authentication token - clients need this to connect
          auth.method = "token"
          ${tokenConfig}

          # Subdomain support for *.${cfg.domain}
          subDomainHost = "${cfg.domain}"
          
          # Allow port ranges for TCP/UDP tunnels
          # Format: [[{"start": 20000, "end": 20099}]]
          allowPorts = [
            { start = 20000, end = 20099 }
          ]

          # Custom 404 page
          custom404Page = "${./404.html}"

          # Logging
          log.to = "console"
          log.level = "info"
        '';
      in
      {
        description = "frp server for ${cfg.domain} tunneling";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          Restart = "on-failure";
          RestartSec = "5s";
          ExecStart = "${pkgs.frp}/bin/frps -c ${configFile}";
        };
      };

    # Automatically configure Caddy for wildcard domain
    services.caddy = lib.mkIf cfg.enableCaddy {
      # Dashboard for base domain
      virtualHosts."${cfg.domain}" = {
        extraConfig = ''
          tls {
            dns cloudflare {env.CLOUDFLARE_API_TOKEN}
          }
          header {
            Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          }
          
          # Proxy /api/* to frps dashboard
          handle /api/* {
            reverse_proxy localhost:7400
          }
          
          # Serve dashboard HTML
          handle {
            root * ${./.}
            try_files dashboard.html
            file_server
          }
        '';
      };

      # Wildcard subdomain proxy to frps
      virtualHosts."*.${cfg.domain}" = {
        extraConfig = ''
          tls {
            dns cloudflare {env.CLOUDFLARE_API_TOKEN}
          }
          header {
            Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
          }
          reverse_proxy localhost:${toString cfg.vhostHTTPPort} {
            header_up X-Forwarded-Proto {scheme}
            header_up X-Forwarded-For {remote}
            header_up Host {host}
          }
          handle_errors {
            @404 expression {http.error.status_code} == 404
            handle @404 {
              root * ${./.}
              rewrite * /404.html
              file_server
            }
          }
        '';
      };
    };
  };
}

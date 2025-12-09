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

    # Open firewall port for frp control connection
    networking.firewall.allowedTCPPorts = [ cfg.bindPort ];

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
          
          # Proxy /metrics to frps dashboard
          handle /metrics {
            reverse_proxy localhost:7400
          }
          
          # Proxy /api/* to frps dashboard
          handle /api/* {
            reverse_proxy localhost:7400
          }
          
          # Serve dashboard HTML
          handle {
            root * ${./.}
            try_files bore-dashboard.html
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
        '';
      };
    };
  };
}

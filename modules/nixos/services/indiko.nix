# Indiko - IndieAuth/OAuth2 server
#
# Uses mkService base with custom rate limiting on auth endpoints

let
  mkService = import ../../lib/mkService.nix;
in

mkService {
  name = "indiko";
  description = "Indiko IndieAuth/OAuth2 server";
  defaultPort = 3003;
  runtime = "bun";
  entryPoint = "src/index.ts";

  extraConfig = cfg: {
    # Add ORIGIN and RP_ID environment variables
    systemd.services.indiko.serviceConfig.Environment = [
      "ORIGIN=https://${cfg.domain}"
      "RP_ID=${cfg.domain}"
    ];

    # Custom Caddy config with rate limiting on auth endpoints
    services.caddy.virtualHosts.${cfg.domain}.extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }

      # Rate limiting for auth endpoints
      handle /auth/* {
        rate_limit {
          zone auth_limit {
            key {http.request.remote_ip}
            events 10
            window 1m
          }
        }
        reverse_proxy localhost:${toString cfg.port}
      }

      # Rate limiting for API endpoints
      handle /api/* {
        rate_limit {
          zone api_limit {
            key {http.request.remote_ip}
            events 30
            window 1m
          }
        }
        reverse_proxy localhost:${toString cfg.port}
      }

      # General rate limiting for all other routes
      handle {
        rate_limit {
          zone general_limit {
            key {http.request.remote_ip}
            events 60
            window 1m
          }
        }
        reverse_proxy localhost:${toString cfg.port}
      }
    '';

    # Disable default caddy config since we're overriding it
    atelier.services.indiko.caddy.enable = false;

    # Data declarations for automatic backup (SQLite for sessions/tokens)
    # App uses hardcoded data/indiko.db relative to app dir
    atelier.services.indiko.data = {
      sqlite = "${cfg.dataDir}/app/data/indiko.db";
    };
  };
}

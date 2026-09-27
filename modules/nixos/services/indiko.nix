# Indiko - IndieAuth/OAuth2 server
#
# Uses mkService base with custom rate limiting on auth endpoints

let
  mkService = import ../../lib/mkService.nix;
  mkRateLimit = import ../../lib/mkRateLimit.nix;
in

mkService {
  name = "indiko";
  description = "Indiko IndieAuth/OAuth2 server";
  defaultPort = 3003;
  runtime = "bun";
  entryPoint = "src/index.ts";

  extraConfig = cfg: {
    atelier.services.indiko.environment = {
      ORIGIN = "https://${cfg.domain}";
      RP_ID = cfg.domain;
      DATABASE_URL = "${cfg.dataDir}/data/indiko.db";
    };

    # Auth is the endpoint worth metering; the API and the rest get looser caps.
    services.caddy.virtualHosts.${cfg.domain}.extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }

      handle /auth/* {
        ${mkRateLimit {
          zone = "auth_limit";
          events = 10;
        }}
        reverse_proxy localhost:${toString cfg.port}
      }

      handle /api/* {
        ${mkRateLimit {
          zone = "api_limit";
          events = 30;
        }}
        reverse_proxy localhost:${toString cfg.port}
      }

      handle {
        ${mkRateLimit {
          zone = "general_limit";
          events = 60;
        }}
        reverse_proxy localhost:${toString cfg.port}
      }
    '';

    atelier.services.indiko.caddy.enable = false;

    # Data declarations for automatic backup (SQLite for sessions/tokens)
    atelier.services.indiko.data = {
      sqlite = "${cfg.dataDir}/data/indiko.db";
    };
  };
}

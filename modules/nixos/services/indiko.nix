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
      # Caddy passes Cloudflare's headers through, so indiko's own per-endpoint
      # limiters (token, passkey, LDAP) can key on the real visitor instead of
      # seeing every request arrive from localhost.
      TRUSTED_PROXY = "cloudflare";
    };

    # Indiko meters its sensitive endpoints itself; Caddy is only a coarse
    # backstop. An interactive sign-in is four or five /auth/* requests and a
    # conformance run (indieauth.rocks) is dozens in a minute, so the old cap
    # of 10 cut real flows off at the consent step.
    services.caddy.virtualHosts.${cfg.domain}.extraConfig = ''
      tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
      }

      handle /auth/* {
        ${mkRateLimit {
          zone = "auth_limit";
          events = 60;
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

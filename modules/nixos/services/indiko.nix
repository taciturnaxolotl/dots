# Indiko - IndieAuth/OAuth2 server

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
    atelier.services.indiko.environment = {
      ORIGIN = "https://${cfg.domain}";
      RP_ID = cfg.domain;
      DATABASE_URL = "${cfg.dataDir}/data/indiko.db";
      # Caddy passes Cloudflare's headers through, so indiko's own per-endpoint
      # limiters (token, passkey, LDAP) can key on the real visitor instead of
      # seeing every request arrive from localhost.
      TRUSTED_PROXY = "cloudflare";
    };

    # Local resource servers introspect every user's token; via Cloudflare they all shared one address.
    networking.hosts = {
      "127.0.0.1" = [ cfg.domain ];
      "::1" = [ cfg.domain ];
    };

    # Scanner backstop only: real addresses peak at 48/min, indiko meters its own sensitive routes.
    atelier.services.indiko.caddy = {
      rateLimit = {
        enable = true;
        events = 300;
        matcher = "@metered";
      };
      extraConfig = ''
        @metered {
          not remote_ip 127.0.0.1 ::1
          not path /health
        }
      '';
    };

    # Data declarations for automatic backup (SQLite for sessions/tokens)
    atelier.services.indiko.data = {
      sqlite = "${cfg.dataDir}/data/indiko.db";
    };
  };
}

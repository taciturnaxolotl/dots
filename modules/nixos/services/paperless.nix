# Paperless-ngx - Document management system
#
# Wraps the NixOS paperless module with Caddy reverse proxy
# and atelier manifest integration.

{ config, lib, ... }:

let
  cfg = config.atelier.services.paperless;
in
{
  options.atelier.services.paperless = {
    enable = lib.mkEnableOption "Paperless-ngx document management system";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain to serve Paperless-ngx on";
    };

    _description = lib.mkOption {
      type = lib.types.str;
      default = "Paperless-ngx document management system";
      internal = true;
      readOnly = true;
    };

    _runtime = lib.mkOption {
      type = lib.types.str;
      default = "python";
      internal = true;
      readOnly = true;
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 28981;
      readOnly = true;
      internal = true;
    };

    data = {
      postgres = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "PostgreSQL database name (will use pg_dump for backup)";
      };
      sqlite = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to SQLite database";
      };
      files = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional file paths to backup";
      };
      exclude = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "*.log" ];
        description = "Glob patterns to exclude from backup";
      };
    };

    ocrLanguages = lib.mkOption {
      type = lib.types.str;
      default = "eng";
      description = "OCR languages for document processing (e.g. 'eng' or 'deu+eng')";
    };

    consumptionDirIsPublic = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Allow consumption directory to be publicly accessible";
    };

    healthUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Health check URL for monitoring";
    };

    oidc = {
      enable = lib.mkEnableOption "OIDC authentication via Indiko";

      clientId = lib.mkOption {
        type = lib.types.str;
        description = "Indiko OAuth client ID for Paperless";
      };

      clientSecretFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to file containing the Indiko OAuth client secret";
      };

      issuer = lib.mkOption {
        type = lib.types.str;
        description = "Indiko OIDC issuer URL (e.g. https://indiko.dunkirk.sh)";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.paperless = {
      enable = true;
      address = "127.0.0.1";
      port = cfg.port;
      consumptionDirIsPublic = cfg.consumptionDirIsPublic;
      settings = {
        PAPERLESS_URL = "https://${cfg.domain}";
        PAPERLESS_OCR_LANGUAGE = cfg.ocrLanguages;
        PAPERLESS_CONSUMER_IGNORE_PATTERN = [
          ".DS_STORE/*"
          "desktop.ini"
        ];
      }
      // lib.optionalAttrs cfg.oidc.enable {
        PAPERLESS_REDIRECT_LOGIN_TO_SSO = "true";
      };
    };

    atelier.services.paperless.data = {
      sqlite = "/var/lib/paperless/db.sqlite3";
      files = [ "/var/lib/paperless/media" ];
    };

    services.caddy.virtualHosts.${cfg.domain} = {
      extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        }

        reverse_proxy localhost:${toString cfg.port}
      '';
    };

    # The oidc secrets file must contain PAPERLESS_SOCIALACCOUNT_PROVIDERS
    # with the full JSON including the client secret.
    # EnvironmentFile overrides Environment= for the same key.
    systemd.services.paperless-web = lib.mkIf (cfg.oidc.enable && cfg.oidc.clientSecretFile != null) {
      serviceConfig.EnvironmentFile = cfg.oidc.clientSecretFile;
    };
  };
}

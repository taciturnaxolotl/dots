{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.atelier.services.curl-doom;
in {
  options.atelier.services.curl-doom = {
    enable = mkEnableOption "curl-doom";
    
    port = mkOption {
      type = types.port;
      default = 3300;
      description = "Port to listen on";
    };
    
    domain = mkOption {
      type = types.str;
      default = "doom.dunkirk.sh";
      description = "Domain to host curl-doom on";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.curl-doom = {
      description = "curl-doom server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      serviceConfig = {
        ExecStart = "${pkgs.curl-doom}/bin/curl-doom";
        Environment = [
          "PORT=${toString cfg.port}"
          "NODE_ENV=production"
        ];
        Restart = "always";
        DynamicUser = true;
      };
    };

    services.caddy.virtualHosts."${cfg.domain}" = {
      extraConfig = ''
        tls {
          dns cloudflare {env.CLOUDFLARE_API_TOKEN}
        }
        header {
          Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        }
        
        @notcurl {
          not header User-Agent *curl*
        }
        redir @notcurl https://github.com/xsawyerx/curl-doom 302

        reverse_proxy localhost:${toString cfg.port} {
          header_up X-Forwarded-Proto {scheme}
          header_up X-Forwarded-For {remote}
        }
      '';
    };
  };
}

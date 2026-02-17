# mkService - Base service factory for atelier services
#
# Creates a standardized NixOS service module with:
# - Common options (domain, port, dataDir, secrets, etc.)
# - Systemd service with git-based deployment
# - Caddy reverse proxy configuration
# - Automatic backup integration via data declarations
#
# Usage in a service module:
#   let
#     mkService = import ../../lib/mkService.nix;
#   in
#   mkService {
#     name = "myapp";
#     defaultPort = 3000;
#     extraOptions = { ... };
#     extraConfig = cfg: { ... };
#   }

# This file is a function that takes service parameters and returns a NixOS module
{
  # Service identity
  name,
  description ? "${name} service",
  defaultPort ? 3000,
  
  # Runtime configuration
  runtime ? "bun",  # "bun" | "node" | "custom"
  entryPoint ? "src/index.ts",
  startCommand ? null,  # Override the start command entirely
  
  # Additional options specific to this service
  extraOptions ? {},
  
  # Additional config when service is enabled
  # Receives cfg (the service config) as argument
  extraConfig ? cfg: {},
}:

# Return a proper NixOS module
{ config, lib, pkgs, ... }:

let
  cfg = config.atelier.services.${name};
  
  # Generate start command based on runtime
  defaultStartCommand = {
    bun = "${pkgs.unstable.bun}/bin/bun run ${entryPoint}";
    node = "${pkgs.nodejs_20}/bin/node ${entryPoint}";
  }.${runtime} or "";
  
  finalStartCommand = if startCommand != null then startCommand else defaultStartCommand;

in {
  options.atelier.services.${name} = {
    enable = lib.mkEnableOption description;

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Domain to serve ${name} on";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = defaultPort;
      description = "Port to run ${name} on";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/${name}";
      description = "Directory to store ${name} data";
    };

    secretsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to agenix secrets file";
    };

    # Git-based deployment
    deploy = {
      enable = lib.mkEnableOption "Git-based deployment" // { default = true; };
      
      repository = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Git repository URL for auto-deployment";
      };

      autoUpdate = lib.mkEnableOption "Automatically git pull on service restart";
      
      branch = lib.mkOption {
        type = lib.types.str;
        default = "main";
        description = "Git branch to deploy";
      };
    };

    # Data declarations for automatic backup
    data = {
      sqlite = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to SQLite database (will checkpoint WAL and stop service for backup)";
        example = "/var/lib/myapp/data/app.db";
      };

      postgres = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "PostgreSQL database name (will use pg_dump for backup)";
      };

      files = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional file paths to backup (no service interruption)";
        example = [ "/var/lib/myapp/uploads" ];
      };

      exclude = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "*.log" "node_modules" ".git" "cache" "tmp" ];
        description = "Glob patterns to exclude from backup";
      };
    };

    # Caddy configuration
    caddy = {
      enable = lib.mkEnableOption "Caddy reverse proxy" // { default = true; };
      
      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Additional Caddy configuration";
      };
      
      rateLimit = {
        enable = lib.mkEnableOption "Rate limiting";
        
        events = lib.mkOption {
          type = lib.types.int;
          default = 60;
          description = "Number of requests allowed per window";
        };
        
        window = lib.mkOption {
          type = lib.types.str;
          default = "1m";
          description = "Time window for rate limiting";
        };
      };
    };

    # Environment variables (in addition to secretsFile)
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables";
    };
  } // extraOptions;

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Port conflict detection
    {
      assertions = 
        let
          allServices = lib.filterAttrs (n: v: v.enable or false) config.atelier.services;
          portsInUse = lib.mapAttrsToList (serviceName: serviceCfg: {
            inherit serviceName;
            port = serviceCfg.port or null;
          }) allServices;
          portsWithValues = lib.filter (p: p.port != null) portsInUse;
          
          # Find if this service's port conflicts with another service
          conflicts = lib.filter (p: p.port == cfg.port && p.serviceName != name) portsWithValues;
        in [
          {
            assertion = conflicts == [];
            message = ''
              Port conflict detected for ${name}!
              Port ${toString cfg.port} is already used by: ${lib.concatMapStringsSep ", " (c: c.serviceName) conflicts}
              
              Ports currently in use:
              ${lib.concatMapStringsSep "\n  " (p: "${p.serviceName}: ${toString p.port}") portsWithValues}
            '';
          }
        ];
    }
    
    # Base service configuration
    {
      # Create user and group
      users.groups.services = {};
      
      users.users.${name} = {
        isSystemUser = true;
        group = name;
        extraGroups = [ "services" ];
        home = cfg.dataDir;
        createHome = true;
        shell = pkgs.bash;
      };

      users.groups.${name} = {};

      # Allow service user to restart their own service
      security.sudo.extraRules = [
        {
          users = [ name ];
          commands = [
            {
              command = "/run/current-system/sw/bin/systemctl restart ${name}.service";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];

      # Systemd service
      systemd.services.${name} = {
        inherit description;
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        path = [ pkgs.git pkgs.openssh ];

        preStart = lib.optionalString (cfg.deploy.enable && cfg.deploy.repository != null) ''
          set -e
          # Clone repository if not present
          if [ ! -d ${cfg.dataDir}/app/.git ]; then
            ${pkgs.git}/bin/git clone -b ${cfg.deploy.branch} ${cfg.deploy.repository} ${cfg.dataDir}/app
          fi
          
          cd ${cfg.dataDir}/app
        '' + lib.optionalString (cfg.deploy.enable && cfg.deploy.autoUpdate) ''
          ${pkgs.git}/bin/git fetch origin || true
          ${pkgs.git}/bin/git reset --hard origin/${cfg.deploy.branch} || true
        '' + lib.optionalString (runtime == "bun") ''
          
          if [ -f package.json ]; then
            echo "Installing dependencies..."
            ${pkgs.unstable.bun}/bin/bun install || {
              echo "Failed to install dependencies, trying again..."
              ${pkgs.unstable.bun}/bin/bun install
            }
          fi
        '' + lib.optionalString (runtime == "node") ''
          
          if [ -f package.json ]; then
            echo "Installing dependencies..."
            ${pkgs.nodejs_20}/bin/npm ci --production || {
              echo "Failed to install dependencies, trying again..."
              ${pkgs.nodejs_20}/bin/npm ci --production
            }
          fi
        '';

        serviceConfig = {
          Type = "exec";
          User = name;
          Group = name;
          WorkingDirectory = "${cfg.dataDir}/app";
          EnvironmentFile = lib.mkIf (cfg.secretsFile != null) cfg.secretsFile;
          Environment = [
            "NODE_ENV=production"
            "PORT=${toString cfg.port}"
          ] ++ (lib.mapAttrsToList (k: v: "${k}=${v}") cfg.environment);
          ExecStart = "${pkgs.bash}/bin/bash -c '${finalStartCommand}'";
          Restart = "on-failure";
          RestartSec = "10s";
          TimeoutStartSec = "60s";

          # Automatic state directory management
          # Creates /var/lib/${name} with proper ownership before namespace setup
          StateDirectory = name;
          StateDirectoryMode = "0755";

          # Security hardening
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
        };

        serviceConfig.ExecStartPre = [
          # Run before preStart, creates directories so WorkingDirectory exists
          "!${pkgs.writeShellScript "${name}-setup" ''
            mkdir -p ${cfg.dataDir}/app/data
            mkdir -p ${cfg.dataDir}/data
            chown -R ${name}:services ${cfg.dataDir}
            chmod -R g+rwX ${cfg.dataDir}
          ''}"
        ];
      };

      # StateDirectory handles base dir, tmpfiles creates subdirectories
      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir}/app 0755 ${name} services -"
        "d ${cfg.dataDir}/data 0755 ${name} services -"
      ];

      # Caddy reverse proxy
      services.caddy.virtualHosts.${cfg.domain} = lib.mkIf cfg.caddy.enable {
        extraConfig = ''
          tls {
            dns cloudflare {env.CLOUDFLARE_API_TOKEN}
          }

          ${lib.optionalString cfg.caddy.rateLimit.enable ''
          rate_limit {
            zone ${name}_limit {
              key {http.request.remote_ip}
              events ${toString cfg.caddy.rateLimit.events}
              window ${cfg.caddy.rateLimit.window}
            }
          }
          ''}

          ${cfg.caddy.extraConfig}

          reverse_proxy localhost:${toString cfg.port}
        '';
      };
    }

    # Extra config from the service module
    (extraConfig cfg)
  ]);
}

# mkService - Base service factory for atelier services
#
# Creates a standardized NixOS service module with:
# - Common options (domain, port, dataDir, secrets, etc.)
# - Systemd service with initial git clone for scaffolding
# - Caddy reverse proxy configuration
# - Automatic backup integration via data declarations
#
# Subsequent deployments are handled by per-repo GitHub Actions
# workflows that SSH in as the service user, git pull, and restart.
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

    # Git repository for initial scaffolding (clone on first start)
    # Subsequent deploys are handled by GitHub Actions workflows
    repository = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Git repository URL — cloned once on first start for scaffolding";
    };

    healthUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Health check URL for monitoring";
    };

    # Internal metadata set by mkService factory — used by services-manifest
    _description = lib.mkOption {
      type = lib.types.str;
      default = description;
      internal = true;
      readOnly = true;
    };

    _runtime = lib.mkOption {
      type = lib.types.str;
      default = runtime;
      internal = true;
      readOnly = true;
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
        createHome = false;
        shell = pkgs.bash;
      };

      users.groups.${name} = {};

      # Ensure data directories exist with correct permissions on every activation
      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0755 ${name} services -"
        "d ${cfg.dataDir}/app 0750 ${name} services -"
        "d ${cfg.dataDir}/data 0750 ${name} services -"
      ];

      # Allow service user to manage their own service (for CI/CD deploys)
      security.sudo.extraRules = [
        {
          users = [ name ];
          commands = map (cmd: {
            command = "/run/current-system/sw/bin/systemctl ${cmd} ${name}.service";
            options = [ "NOPASSWD" ];
          }) [ "restart" "stop" "start" "status" ];
        }
      ];

      # Systemd service
      systemd.services.${name} = {
        inherit description;
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        path = [ pkgs.git pkgs.openssh ];

        preStart = lib.optionalString (cfg.repository != null) ''
          set -e
          # Clone repository on first start (scaffolding only)
          if [ ! -d ${cfg.dataDir}/app/.git ]; then
            ${pkgs.git}/bin/git clone ${cfg.repository} ${cfg.dataDir}/app
          fi
        '' + lib.optionalString (runtime == "bun") ''

          # Install deps only on first clone (no node_modules yet)
          if [ -f ${cfg.dataDir}/app/package.json ] && [ ! -d ${cfg.dataDir}/app/node_modules ]; then
            cd ${cfg.dataDir}/app
            echo "First start: installing dependencies..."
            ${pkgs.unstable.bun}/bin/bun install
          fi
        '' + lib.optionalString (runtime == "node") ''

          # Install deps only on first clone (no node_modules yet)
          if [ -f ${cfg.dataDir}/app/package.json ] && [ ! -d ${cfg.dataDir}/app/node_modules ]; then
            cd ${cfg.dataDir}/app
            echo "First start: installing dependencies..."
            ${pkgs.nodejs_20}/bin/npm ci --production
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

          # Security hardening
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ReadWritePaths = [ cfg.dataDir ];
          ProtectHome = true;
          PrivateTmp = true;

          # ExecStartPre with ! runs as root before namespace setup,
          # guaranteeing dirs exist before WorkingDirectory is checked
          ExecStartPre = [
            "!${pkgs.writeShellScript "${name}-setup" ''
              mkdir -p ${cfg.dataDir}/app ${cfg.dataDir}/data
              chown ${name}:services ${cfg.dataDir}
              chown ${name}:services ${cfg.dataDir}/app ${cfg.dataDir}/data
              chmod 0755 ${cfg.dataDir}
              chmod g+rwX ${cfg.dataDir}/app ${cfg.dataDir}/data
            ''}"
          ];
        };
      };

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

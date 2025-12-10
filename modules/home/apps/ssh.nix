{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.atelier.ssh;
in
{
  options.atelier.ssh = {
    enable = mkEnableOption "SSH configuration";

    zmx = {
      enable = mkEnableOption "zmx integration for persistent sessions";
      hosts = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "List of host patterns to enable zmx auto-attach (e.g., 'd.*')";
      };
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Extra SSH configuration";
    };

    hosts = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            hostname = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Hostname or IP address";
            };

            port = mkOption {
              type = types.nullOr types.int;
              default = null;
              description = "SSH port";
            };

            user = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Username for SSH connection";
            };

            identityFile = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Path to SSH identity file";
            };

            forwardAgent = mkOption {
              type = types.nullOr types.bool;
              default = null;
              description = "Enable SSH agent forwarding";
            };

            extraOptions = mkOption {
              type = types.attrsOf types.str;
              default = { };
              description = "Additional SSH options for this host";
            };

            zmx = mkOption {
              type = types.bool;
              default = false;
              description = "Enable zmx persistent sessions for this host";
            };
          };
        }
      );
      default = { };
      description = "SSH host configurations";
    };
  };

  config = mkIf cfg.enable {
    # zmx provides pre-built binaries that we download instead of building from source
    # This avoids the zig2nix dependency which causes issues in CI
    home.packages = 
      (optionals cfg.zmx.enable [
        pkgs.zmx-binary
        pkgs.autossh
      ]);

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      matchBlocks =
        let
          # Convert atelier.ssh.hosts to SSH matchBlocks
          hostConfigs = mapAttrs (
            name: hostCfg:
            {
              hostname = mkIf (hostCfg.hostname != null) hostCfg.hostname;
              port = mkIf (hostCfg.port != null) hostCfg.port;
              user = mkIf (hostCfg.user != null) hostCfg.user;
              identityFile = mkIf (hostCfg.identityFile != null) hostCfg.identityFile;
              forwardAgent = mkIf (hostCfg.forwardAgent != null) hostCfg.forwardAgent;
              extraOptions = hostCfg.extraOptions // (
                if hostCfg.zmx then
                  {
                    RemoteCommand = "export PATH=$HOME/.nix-profile/bin:$PATH; zmx attach %n";
                    RequestTTY = "yes";
                    ControlPath = "~/.ssh/cm-%r@%h:%p";
                    ControlMaster = "auto";
                    ControlPersist = "10m";
                  }
                else
                  { }
              );
            }
          ) cfg.hosts;

          # Create zmx pattern hosts if enabled
          zmxPatternHosts = if cfg.zmx.enable then
            listToAttrs (
              map (pattern: 
                let
                  patternHost = cfg.hosts.${pattern} or {};
                in {
                name = pattern;
                value = {
                  hostname = mkIf (patternHost.hostname or null != null) patternHost.hostname;
                  port = mkIf (patternHost.port or null != null) patternHost.port;
                  user = mkIf (patternHost.user or null != null) patternHost.user;
                  extraOptions = {
                    RemoteCommand = "export PATH=$HOME/.nix-profile/bin:$PATH; zmx attach %k";
                    RequestTTY = "yes";
                    ControlPath = "~/.ssh/cm-%r@%h:%p";
                    ControlMaster = "auto";
                    ControlPersist = "10m";
                  };
                };
              }) cfg.zmx.hosts
            )
          else
            { };

          # Default match block for extraConfig
          defaultBlock = if cfg.extraConfig != "" then
            {
              "*" = { };
            }
          else
            { };
        in
        defaultBlock // hostConfigs // zmxPatternHosts;

      extraConfig = cfg.extraConfig;
    };

    # Add shell aliases for easier zmx usage
    programs.zsh.shellAliases = mkIf cfg.zmx.enable {
      zmls = "zmx list";
      zmk = "zmx kill";
      zma = "zmx attach";
      ash = "autossh -M 0 -q";
    };

    programs.bash.shellAliases = mkIf cfg.zmx.enable {
      zmls = "zmx list";
      zmk = "zmx kill";
      zma = "zmx attach";
      ash = "autossh -M 0 -q";
    };

    programs.fish.shellAliases = mkIf cfg.zmx.enable {
      zmls = "zmx list";
      zmk = "zmx kill";
      zma = "zmx attach";
      ash = "autossh -M 0 -q";
    };
  };
}

{
  config,
  lib,
  pkgs,
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
      bypassEnv = mkOption {
        type = types.listOf types.str;
        default = [
          "ZMX_OFF"
          "AI_AGENT"
          "CLAUDECODE"
          "CRUSH"
        ];
        description = ''
          Environment variables that, when non-empty, disable zmx auto-attach
          for zmx hosts. Without this, `ssh host cmd`, `scp` and `rsync` fail
          with "Cannot execute command-line and remote command", which coding
          agents hit constantly.
        '';
      };
    };

    agent = {
      addKeysToAgent = mkOption {
        type = types.enum [
          "yes"
          "no"
          "confirm"
          "ask"
        ];
        default = "yes";
        description = "Automatically add keys to the running agent (maps to AddKeysToAgent)";
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

            setEnv = mkOption {
              type = types.attrsOf (
                types.oneOf [
                  types.str
                  types.path
                  types.int
                  types.float
                ]
              );
              default = { };
              description = "Environment variables to set (maps to SetEnv)";
            };

            remoteCommand = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Remote command to execute (maps to RemoteCommand)";
            };

            requestTTY = mkOption {
              type = types.nullOr (
                types.enum [
                  "yes"
                  "no"
                  "force"
                  "auto"
                ]
              );
              default = null;
              description = "Request a pseudo-terminal (maps to RequestTTY)";
            };

            controlMaster = mkOption {
              type = types.nullOr (
                types.enum [
                  "yes"
                  "no"
                  "ask"
                  "auto"
                  "autoask"
                ]
              );
              default = null;
              description = "Control master setting";
            };

            controlPath = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Control socket path";
            };

            controlPersist = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "Control persist duration";
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
    home.packages = (
      optionals cfg.zmx.enable [
        pkgs.zmx-binary
        pkgs.autossh
      ]
    );

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      settings =
        let
          # Build settings entries from atelier.ssh.hosts
          hostSettings = filterAttrs (_: v: v != { }) (
            mapAttrs (
              name: hostCfg:
              let
                base = filterAttrs (_: v: v != null) {
                  HostName = hostCfg.hostname;
                  Port = hostCfg.port;
                  User = hostCfg.user;
                  IdentityFile = hostCfg.identityFile;
                  ForwardAgent = hostCfg.forwardAgent;
                  RemoteCommand = hostCfg.remoteCommand;
                  RequestTTY = hostCfg.requestTTY;
                  ControlMaster = hostCfg.controlMaster;
                  ControlPath = hostCfg.controlPath;
                  ControlPersist = hostCfg.controlPersist;
                };
                envBlock = optionalAttrs (hostCfg.setEnv != { }) {
                  SetEnv = hostCfg.setEnv;
                };
                zmxBlock = optionalAttrs hostCfg.zmx {
                  RemoteCommand = "export PATH=$HOME/.nix-profile/bin:$PATH; zmx attach %n";
                  RequestTTY = "yes";
                  ControlPath = "~/.ssh/cm-%r@%h:%p";
                  ControlMaster = "auto";
                  ControlPersist = "10m";
                };
              in
              base // envBlock // zmxBlock
            ) cfg.hosts
          );

          # Zmx pattern host settings
          zmxSettings =
            if cfg.zmx.enable then
              listToAttrs (
                map (
                  pattern:
                  let
                    patternHost = cfg.hosts.${pattern} or { };
                  in
                  {
                    name = pattern;
                    value = filterAttrs (_: v: v != null) {
                      HostName = patternHost.hostname or null;
                      Port = patternHost.port or null;
                      User = patternHost.user or null;
                      RemoteCommand = "export PATH=$HOME/.nix-profile/bin:$PATH; zmx attach %k";
                      RequestTTY = "yes";
                      ControlPath = "~/.ssh/cm-%r@%h:%p";
                      ControlMaster = "auto";
                      ControlPersist = "10m";
                    };
                  }
                ) cfg.zmx.hosts
              )
            else
              { };

          # Every host that gets a zmx RemoteCommand, patterns included
          zmxHosts = cfg.zmx.hosts ++ attrNames (filterAttrs (_: h: h.zmx) cfg.hosts);

          # RemoteCommand makes `ssh host cmd`, scp and rsync hard errors. Give
          # them back by cancelling the zmx block whenever a bypass variable is
          # set, so agents get plain ssh and humans still land in a session.
          bypassBlock = optionalAttrs (cfg.zmx.enable && zmxHosts != [ ] && cfg.zmx.bypassEnv != [ ]) {
            zmx-bypass = hm.dag.entryBefore (attrNames (hostSettings // zmxSettings)) {
              header = ''Match originalhost ${concatStringsSep "," zmxHosts} exec "test -n \"${
                concatMapStrings (v: "$" + v) cfg.zmx.bypassEnv
              }\""'';
              RemoteCommand = "none";
              RequestTTY = "auto";
            };
          };

          # Default block for global SSH options
          defaultBlock = {
            "*" = {
              AddKeysToAgent = cfg.agent.addKeysToAgent;
            };
          };
        in
        defaultBlock // hostSettings // zmxSettings // bypassBlock;

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

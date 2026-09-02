# BotThisSite - captcha leaderboard
#
# Python service. Deploys run `uv sync --frozen` over SSH, so the venv lives in
# the checkout and the unit execs its uvicorn directly; uv never runs at start
# time, which keeps a boot from depending on the network.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  mkService = import ../../lib/mkService.nix;
  cfg = config.atelier.services.botme;

  baseModule = mkService {
    name = "botme";
    description = "BotThisSite captcha leaderboard";
    defaultPort = 3012;
    runtime = "custom";
    extraOptions = {
      deployKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "SSH private key used to clone and pull a private repository";
      };
    };

    startCommand = "${cfg.dataDir}/app/.venv/bin/uvicorn main:app --host 127.0.0.1 --port ${toString cfg.port}";

    extraConfig =
      cfg:
      let
        sshCommand =
          "${pkgs.openssh}/bin/ssh -i ${toString cfg.deployKeyFile} -o IdentitiesOnly=yes "
          + "-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${cfg.dataDir}/.ssh/known_hosts";
      in
      {
        # uv resolves at deploy time over SSH, python311 is what the venv links
        # against. uv's own managed interpreters are unpatched binaries and do
        # not run on NixOS, hence UV_PYTHON_DOWNLOADS=never everywhere uv runs.
        # The interpreter goes in through symlinkJoin rather than directly:
        # this machine installs "doc" outputs, and `python311.doc` is a
        # separate sphinx build that fails to build. The join has no such
        # attribute, so system-path stops at the interpreter.
        environment.systemPackages = [
          pkgs.uv
          (pkgs.symlinkJoin {
            name = "python311-interpreter";
            paths = [ pkgs.python311 ];
          })
        ];

        atelier.services.botme = {
          environment = {
            DATABASE_PATH = "${cfg.dataDir}/data/botme.db";
            UV_PYTHON_DOWNLOADS = "never";
          };

          data = {
            sqlite = "${cfg.dataDir}/data/botme.db";
            stopForBackup = false;
          };
        };

        # The repo is private, so both git paths need the key: the unit's env
        # covers the scaffolding clone, and the checkout's own config covers the
        # `git fetch` the deploy workflow runs over SSH as this user.
        systemd.tmpfiles.rules = lib.mkIf (cfg.deployKeyFile != null) [
          "d ${cfg.dataDir}/.ssh 0700 botme services -"
        ];

        systemd.services.botme.environment = lib.mkIf (cfg.deployKeyFile != null) {
          GIT_SSH_COMMAND = sshCommand;
        };

        # preStart's PATH is git + openssh only, and uv needs an interpreter to
        # build the venv against.
        systemd.services.botme.path = [ pkgs.python311 ];

        # First boot has a fresh clone and no venv. Every later deploy syncs over
        # SSH before restarting, so this only ever does work once.
        systemd.services.botme.preStart = lib.mkAfter ''
          ${lib.optionalString (cfg.deployKeyFile != null) ''
            ${pkgs.git}/bin/git -C ${cfg.dataDir}/app config core.sshCommand "${sshCommand}"
          ''}
          if [ ! -x ${cfg.dataDir}/app/.venv/bin/uvicorn ]; then
            cd ${cfg.dataDir}/app
            ${pkgs.uv}/bin/uv sync --frozen
          fi
        '';
      };
  };
in
{
  imports = [ baseModule ];
}

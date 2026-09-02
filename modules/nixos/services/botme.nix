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
    startCommand = "${cfg.dataDir}/app/.venv/bin/uvicorn main:app --host 127.0.0.1 --port ${toString cfg.port}";

    extraConfig = cfg: {
      # uv resolves at deploy time over SSH, python311 is what the venv links
      # against. uv's own managed interpreters are unpatched binaries and do
      # not run on NixOS, hence UV_PYTHON_DOWNLOADS=never everywhere uv runs.
      environment.systemPackages = [
        pkgs.uv
        pkgs.python311
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

      # preStart's PATH is git + openssh only, and uv needs an interpreter to
      # build the venv against.
      systemd.services.botme.path = [ pkgs.python311 ];

      # First boot has a fresh clone and no venv. Every later deploy syncs over
      # SSH before restarting, so this only ever does work once.
      systemd.services.botme.preStart = lib.mkAfter ''
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

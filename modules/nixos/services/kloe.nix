# Kloe — server-authoritative LLM chat (bun + sqlite + SSE)
#
# Deployed the usual way: mkService scaffolds the user/dirs/unit/vhost and
# clones once, the repo's own GitHub Action pushes every later revision.
#
# The one wrinkle is config. kloe reads a single validated `kloe.json`
# (src/settings.ts) whose path comes from KLOE_CONFIG, and that file is
# gitignored — a deploy that `git reset --hard`s the app dir must not be the
# thing that carries it. So the file is generated here from `settings` and
# handed over by path, and every credential inside it stays a `$VAR` reference
# resolved at load time from the agenix EnvironmentFile. Nothing secret reaches
# the world-readable nix store.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  mkService = import ../../lib/mkService.nix;

  # Paths are the module's business, not the operator's: they follow dataDir so
  # the backup declarations below and the running service can never disagree.
  configFile =
    cfg:
    pkgs.writeText "kloe.json" (
      builtins.toJSON (
        lib.recursiveUpdate cfg.settings {
          server = {
            port = cfg.port;
            dbPath = "${cfg.dataDir}/data/kloe.db";
          };
          blobs.path = "${cfg.dataDir}/data/blobs";
          catwalk.cachePath = "${cfg.dataDir}/data/catwalk.json";
          auth.baseUrl = "https://${cfg.domain}";
        }
      )
    );

  baseModule = mkService {
    name = "kloe";
    description = "kloe — server-authoritative LLM chat";
    defaultPort = 3011;
    runtime = "bun";
    startCommand = "${pkgs.unstable.bun}/bin/bun run server.ts";

    extraOptions = {
      settings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        description = ''
          kloe.json, verbatim (see kloe.schema.json in the repo). Free-form on
          purpose: the schema lives in kloe and re-modelling it in Nix would
          only give it a second place to drift.

          `server.port`, `server.dbPath`, `blobs.path`, `catwalk.cachePath` and
          `auth.baseUrl` are set from this module's options and ignored here.
          Secrets belong in secretsFile and are referenced as "$VAR".
        '';
        example = lib.literalExpression ''
          {
            auth.enabled = true;
            providers = [
              {
                id = "hyper";
                apiKey = "$HYPER_API_KEY";
                apiEndpoint = "https://hyper.charm.land/v1";
                type = "hyper";
              }
            ];
          }
        '';
      };
    };

    extraConfig = cfg: {
      atelier.services.kloe.environment.KLOE_CONFIG = toString (configFile cfg);

      # WAL-mode SQLite plus a content-addressed blob dir; both copy safely
      # while the service runs, and stopping it would drop every SSE stream.
      atelier.services.kloe.data = {
        sqlite = "${cfg.dataDir}/data/kloe.db";
        files = [ "${cfg.dataDir}/data/blobs" ];
        stopForBackup = false;
      };
    };
  };

  cfg = config.atelier.services.kloe;
in
{
  imports = [ baseModule ];

  config = lib.mkIf cfg.enable {
    # The `run_shell` tool drives a docker daemon on another machine over the
    # tailnet (sandbox.dockerHost = "ssh://kloe@prattle"), so the CLI and an ssh
    # client have to be on the unit's path.
    systemd.services.kloe.path = [
      pkgs.docker-client
      pkgs.openssh
    ];

    # Tailscale SSH authorizes that hop by node identity, so there is no key to
    # deploy — but docker spawns ssh with no terminal, and an unknown host key
    # would end the connection in a prompt nobody can answer. Same
    # accept-new the deploy workflow uses, with the store of accepted keys
    # inside dataDir where the unit can actually write it.
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir}/.ssh 0700 kloe kloe -"
      "L+ ${cfg.dataDir}/.ssh/config - - - - ${
        pkgs.writeText "kloe-ssh-config" ''
          Host *
            StrictHostKeyChecking accept-new
            UserKnownHostsFile ${cfg.dataDir}/.ssh/known_hosts
        ''
      }"
    ];
  };
}

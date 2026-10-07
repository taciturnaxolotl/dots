{
  config,
  lib,
  pkgs,
  ...
}:

let
  mkService = import ../../lib/mkService.nix;
  cfg = config.atelier.services.cedarplan;

  baseModule = mkService {
    name = "cedarplan";
    description = "cedarplan Cedarville course planner and shared section catalog";
    defaultPort = 3008;
    runtime = "bun";
    # `start` builds before it serves, which is not laziness: the page bundle
    # has the app's own origin compiled into it (an extension manifest has to
    # name the origin it will talk to literally), and the only place that
    # origin is known is this unit's environment. A build in the deploy
    # workflow would run in an SSH shell that has never heard of it and would
    # quietly bake in localhost.
    startCommand = "${pkgs.unstable.bun}/bin/bun start";

    extraConfig = cfg: {
      atelier.services.cedarplan.environment = {
        CATALOG_DB = "${cfg.dataDir}/data/catalog.sqlite";
        HOST = "127.0.0.1";
        # The origin the served page and the downloadable extension agree on.
        APP_ORIGIN = "https://${cfg.domain}";
        # Cedarville put the course catalog behind SSO, so the server can no
        # longer crawl it: the only session that can read a timetable is a
        # student's browser, and the first student to open a term fills the
        # cache for everybody. Left on, the boot crawl fails every half hour
        # against a login page and achieves nothing.
        CRAWL = "off";
      };

      atelier.services.cedarplan.caddy = {
        rateLimit = {
          enable = true;
          events = 600;
          window = "1m";
        };
        # A student's crawl of one term is a few megabytes of JSON posted to
        # the one open write route, so the cap has to clear a real term while
        # still being a cap. The route's own guards decide whether to believe
        # what arrives; this only bounds how much of it there can be.
        extraConfig = ''
          request_body {
            max_size 32MB
          }
        '';
      };

      # WAL lets restic hot copy. The database is the shared catalog: public
      # course data, nobody's transcript, and rebuildable by any signed-in
      # student — worth keeping to save them the crawl, not worth stopping
      # the service for.
      atelier.services.cedarplan.data = {
        sqlite = "${cfg.dataDir}/data/catalog.sqlite";
        stopForBackup = false;
      };
    };
  };
in
{
  imports = [ baseModule ];

  config = lib.mkIf cfg.enable {
    # `bun start` shells out to `bun` again for each half of the build. bun
    # does put itself on a script's PATH, but naming it here means the unit
    # does not depend on that staying true.
    systemd.services.cedarplan.path = lib.mkAfter [ pkgs.unstable.bun ];
  };
}

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.atelier.bore;

  bore = pkgs.callPackage ../../../../packages/bore.nix {
    inherit (cfg) serverAddr serverPort domain;
    authTokenFile = toString cfg.authTokenFile;
  };
in
{
  options.atelier.bore = {
    enable = lib.mkEnableOption "bore tunneling service";

    serverAddr = lib.mkOption {
      type = lib.types.str;
      default = "bore.dunkirk.sh";
      description = "bore server address";
    };

    serverPort = lib.mkOption {
      type = lib.types.port;
      default = 7000;
      description = "bore server port";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "bore.dunkirk.sh";
      description = "Domain for public tunnel URLs";
    };

    authTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to file containing authentication token";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.frp
      bore
    ];
  };
}

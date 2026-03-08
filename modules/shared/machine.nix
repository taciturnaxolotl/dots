{ lib, ... }:

{
  options.atelier.machine = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Include this machine in the services manifest.";
    };

    type = lib.mkOption {
      type = lib.types.enum [ "server" "client" ];
      default = "server";
      description = "Machine type — server or client";
    };

    tailscaleHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Tailscale hostname for reachability checks";
    };

    triageUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "URL of the triage agent webhook for this machine's services";
    };
  };
}

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.atelier.services.dnclient;

  dnclient-bin = pkgs.stdenv.mkDerivation {
    pname = "dnclient";
    version = "0.1.9";
    src = pkgs.fetchurl {
      url = "https://dl.defined.net/02c6d0f9/v0.1.9/linux/arm64/dnclient";
      sha256 = "644596d0f6a1ef0628262f3adad48671297b5823c6a9694ea94234dc75763dd7";
    };
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/dnclient
      chmod +x $out/bin/dnclient
    '';
  };
in
{
  options.atelier.services.dnclient = {
    enable = lib.mkEnableOption "DNClient (Defined Networking client)";

    server = lib.mkOption {
      type = lib.types.str;
      default = "https://api.defined.net";
      description = "Defined Networking API server URL";
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/defined";
      description = "Directory for DNClient configuration and state";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ dnclient-bin ];

    systemd.tmpfiles.rules = [
      "d ${cfg.configDir} 0755 root root -"
    ];

    systemd.services.dnclient = {
      description = "Defined Networking Client";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      path = with pkgs; [ dnclient-bin iproute2 iptables ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${dnclient-bin}/bin/dnclient run -config ${cfg.configDir} -server ${cfg.server} -log /var/log/dnclient.log";
        Restart = "always";
        RestartSec = "5";

        WorkingDirectory = cfg.configDir;

        CapabilityBoundingSet = "CAP_NET_ADMIN CAP_SYS_MODULE";
        AmbientCapabilities = "CAP_NET_ADMIN CAP_SYS_MODULE";

        ProtectSystem = "false";
        ProtectHome = "read-only";
        PrivateTmp = true;
      };
    };

    networking.firewall.allowedUDPPorts = [ 4242 ];
  };
}

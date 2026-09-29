{ lib, config, ... }:

{
  config.atelier.machine = {
    enable = lib.mkDefault (config.services.tailscale.enable or false);
    tailscaleHost = lib.mkDefault (
      if config.services.tailscale.enable or false then config.networking.hostName else null
    );
  };
}

# Generate a JSON-serialisable manifest of all machines and their services.
#
# Called from flake.nix:
#   services-manifest = import ./lib/services-manifest.nix {
#     configSets = [ ... ];
#     extraMachines = { everseen = { type = "client"; tailscaleHost = "everseen"; }; };
#     inherit lib;
#   };
#
# Evaluate with:
#   nix eval --json .#services-manifest

{ configSets, extraMachines ? {}, lib }:

let
  services = import ./services.nix { inherit lib; };

  # Convert simple extraMachines entries into manifest shape
  extras = lib.mapAttrs (name: cfg: {
    hostname = cfg.hostname or name;
    type = cfg.type or "server";
    tailscale_host = cfg.tailscaleHost or null;
    services = [];
  }) extraMachines;
in
(services.mkMachinesManifest configSets) // extras

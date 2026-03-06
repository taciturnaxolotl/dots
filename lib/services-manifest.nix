# Generate a JSON-serialisable manifest of all atelier services.
#
# Called from flake.nix:
#   services-manifest = import ./lib/services-manifest.nix {
#     config = self.nixosConfigurations.terebithia.config;
#     inherit lib;
#   };
#
# Evaluate with:
#   nix eval --json .#services-manifest

{ config, lib }:

let
  services = import ./services.nix { inherit lib; };
in
services.mkManifest config

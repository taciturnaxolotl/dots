{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
{
  options.nixpkgs.enable = lib.mkEnableOption "Enable custom nixpkgs overlays/config";
  config = lib.mkIf config.nixpkgs.enable {
    nixpkgs = {
      overlays = [
        (final: prev: {
          unstable = import inputs.nixpkgs-unstable {
            inherit (pkgs.stdenv.hostPlatform) system;
            config.allowUnfree = true;
          };
        })
      ];
      config = {
        allowUnfree = true;
        allowUnfreePredicate = _: true;
      };
    };
  };
}

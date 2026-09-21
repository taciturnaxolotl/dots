{ config, lib, ... }:
{
  # Darwin half of modules/nixos/nix-cache.nix. Server-only: off the tailnet
  # every nix command pays ~30s of substituter retries, which a laptop can't.
  config = lib.mkMerge [
    (lib.mkIf config.nix.enable {
      nix.settings = {
        extra-substituters = [ "http://prattle:8091/dots" ];
        extra-trusted-public-keys = [ "dots:Mgol9jjaoUcN6pfgLetO3fe/JAm/fVpKXYBZaQ1MhFM=" ];
      };
    })

    # Determinate owns /etc/nix/nix.conf and rewrites it on upgrade; nix.custom.conf
    # is the `!include` seam it leaves for us. Its crash on an unreachable
    # substituter is fixed, unlike the stock 2.34 the NixOS module warns about.
    (lib.mkIf (!config.nix.enable) {
      environment.etc."nix/nix.custom.conf" = {
        # Hash of the installer's stub, so activation replaces it instead of aborting.
        knownSha256Hashes = [
          "3bd68ef979a42070a44f8d82c205cfd8e8cca425d91253ec2c10a88179bb34aa"
        ];
        text = ''
          extra-substituters = http://prattle:8091/dots
          extra-trusted-public-keys = dots:Mgol9jjaoUcN6pfgLetO3fe/JAm/fVpKXYBZaQ1MhFM=
        '';
      };
    })
  ];
}

{ lib, pkgs, inputs }:

inputs.tangle-of-trust.packages.${pkgs.stdenv.hostPlatform.system}.default

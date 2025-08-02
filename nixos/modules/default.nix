{ ... }:
{
  imports = [
    ./authentication.nix
    ./apps
    ./network/wifi.nix
  ];
}

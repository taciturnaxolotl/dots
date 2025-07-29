{ ... }:
{
  imports = [
    ./git.nix
    ./shell.nix
    ./terminal.nix
    ./theming.nix
    ./apps
    ./nixpkgs.nix
    ./wallpapers.nix
    ./wm/hyprland
  ];
}

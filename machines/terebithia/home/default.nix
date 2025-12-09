{ inputs, ... }:
{
  imports = [
    (inputs.import-tree ../../../modules/home)
  ];

  nixpkgs.enable = true;

  home = {
    username = "kierank";
    homeDirectory = "/home/kierank";
  };

  atelier = {
    shell = {
      enable = true;
    };
    apps = {
      helix.enable = true;
      irssi.enable = true;
    };
    ssh = {
      enable = true;
      zmx.enable = true;
    };
  };

  programs.home-manager.enable = true;

  systemd.user.startServices = "sd-switch";

  home.stateVersion = "23.05";
}

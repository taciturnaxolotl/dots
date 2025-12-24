{ inputs, ... }:
{
  imports = [
    (inputs.import-tree ../../../modules/home)
  ];

  home = {
    username = "duncan";
    homeDirectory = "/home/duncan";
  };

  atelier = {
    shell = {
      enable = true;
    };
  };

  programs.home-manager.enable = true;

  systemd.user.startServices = "sd-switch";

  home.stateVersion = "23.05";
}

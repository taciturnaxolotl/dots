{ inputs, ... }:
{
  imports = [
    (inputs.import-tree ../../../modules/home)
  ];

  home = {
    username = "kierank";
    homeDirectory = "/home/kierank";
  };

  atelier = {
    ssh = {
      enable = true;
      zmx.enable = true;
    };
  };

  programs.home-manager.enable = true;

  systemd.user.startServices = "sd-switch";

  home.stateVersion = "23.05";
}

{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    (inputs.import-tree ../../modules/home)
  ];

  nixpkgs.enable = true;

  home = {
    username = "klukas";
    homeDirectory = "/home/students/2029/klukas";

    packages = with pkgs; [ ];
  };

  atelier = {
    shell.enable = true;
  };

  # Enable home-manager
  programs.home-manager.enable = true;

  # keep hm in .local/state since we are using nix-portable
  xdg.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";
}

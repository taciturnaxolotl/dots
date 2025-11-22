{
  pkgs,
  inputs,
  system,
  ...
}:
{
  imports = [
    (inputs.import-tree ../../modules/home)
  ];

  nixpkgs.enable = true;

  home = {
    username = "kierank";
    homeDirectory = "/home/kierank";

    packages = with pkgs; [
      neofetch
      inputs.nixvim.packages.${system}.default
    ];
  };

  atelier = {
    shell.enable = true;
    apps = {
      helix.enable = true;
    };
  };

  # Enable home-manager
  programs.home-manager.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";
}

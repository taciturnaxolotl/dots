{
  pkgs,
  inputs,
  system,
  ...
}:
{
  imports = [
    (inputs.import-tree ../../modules)
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

  dots = {
    shell.enable = true;
  };

  # Enable home-manager
  programs.home-manager.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";
}

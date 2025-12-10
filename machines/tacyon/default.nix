{
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    (inputs.import-tree ../../modules/home)
    ../../modules/home/system/nixpkgs.nix.disabled
  ];

  nixpkgs.enable = true;

  home = {
    username = "pi";
    homeDirectory = "/home/pi";

    packages = with pkgs; [
      inputs.nixvim.packages.${pkgs.stdenv.hostPlatform.system}.default

      # languages
      go
      gopls
      gotools
      go-tools

      # my apps
      inputs.ctfd-alerts.packages.${pkgs.stdenv.hostPlatform.system}.default

      # Fonts
      fira
      fira-code
      fira-code-symbols
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      liberation_ttf
      comic-neue

      # Nerd Fonts (individual packages)
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      nerd-fonts.ubuntu-mono
    ];
  };

  atelier = {
    shell.enable = true;
    theming.enable = true;
  };

  fonts.fontconfig.enable = true;

  # Enable home-manager
  programs.home-manager.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";

  home.file.".config/openbox/lxde-pi-rc.xml".source = ../../dots/lxde-pi-rc.xml;
}

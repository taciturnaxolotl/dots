{
  self,
  config,
  lib,
  pkgs,
  inputs,
  nixpkgs-unstable,
  ...
}:
{
  imports = [
    # inputs
    inputs.catppuccin.homeModules.catppuccin

    # shell
    ../../app/shell.nix
    ../../app/git.nix
  ];

  nixpkgs = {
    overlays = [
      (final: prev: {
        unstable = import inputs.nixpkgs-unstable {
          system = "aarch64-linux";
          config.allowUnfree = true;
        };
      })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
    };
  };

  home = {
    username = "pi";
    homeDirectory = "/home/pi";

    packages = with pkgs; [
      # CLI tools
      bat
      fd
      eza
      xh
      dust
      ripgrep-all
      inputs.terminal-wakatime.packages.aarch64-linux.default
      jq
      htop
      btop
      fzf
      curl
      wget
      git
      neofetch
      tmux
      unzip
      inputs.nixvim.packages.aarch64-linux.default
      dog

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

  fonts.fontconfig.enable = true;

  # Enable home-manager
  programs.home-manager.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";

  # catppuccin
  catppuccin = {
    enable = true;
    accent = "green";
    flavor = "macchiato";
    cursors = {
      enable = true;
      accent = "blue";
      flavor = "macchiato";
    };
    gtk = {
      enable = true;
      tweaks = [ "normal" ];
    };
    qutebrowser.enable = true;
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  gtk = {
    enable = true;
  };

  qt = {
    style.name = "kvantum";
    platformTheme.name = "kvantum";
    enable = true;
  };

  home.file.".config/openbox/lxde-pi-rc.xml".source = ../../dots/lxde-pi-rc.xml;
}

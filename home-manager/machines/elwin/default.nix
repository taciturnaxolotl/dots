{ self, config, lib, pkgs, inputs, nixpkgs-unstable, ... }: {
  imports = [
    # inputs
    inputs.catppuccin.homeManagerModules.catppuccin

    # shell
    ../../app/shell.nix

    # apps
    ../../app/neovim.nix
    ../../app/git.nix
  ];

  nixpkgs = {
    overlays = [
      (final: prev: {
        unstable = import inputs.nixpkgs-unstable {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
      })
      inputs.catppuccin-vsc.overlays.default
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
    username = "kierank";
    homeDirectory = "/home/kierank";
  };

  # Enable home-manager
  programs.home-manager.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";


  ###########
  # theming #
  ###########

  # catppuccin
  catppuccin = {
    enable = true;
    accent = "blue";
    flavor = "macchiato";
  };
}

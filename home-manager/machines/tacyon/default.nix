{ self, config, lib, pkgs, inputs, nixpkgs-unstable, ... }: {
  imports = [
    # shell
    ../../app/shell.nix
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
    ];
  };

  # Enable home-manager
  programs.home-manager.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";
}

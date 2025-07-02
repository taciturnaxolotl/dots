{
  pkgs,
  inputs,
  system,
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
          inherit system;
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
    username = "kierank";
    homeDirectory = "/home/kierank";

    packages = with pkgs; [
      # CLI tools
      bat
      fd
      eza
      xh
      dust
      ripgrep-all
      inputs.terminal-wakatime.packages.${system}.default
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
      inputs.nixvim.packages.${system}.default
      dog

      # apps
      iodine
    ];
  };

  # Enable home-manager
  programs.home-manager.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";
}

{ self, config, lib, pkgs, inputs, nixpkgs-unstable, ... }: {
  imports = [
    # inputs
    inputs.catppuccin.homeManagerModules.catppuccin

    # window manager
    ../../wm/hyprland

    # shell
    ../../app/shell.nix
    ../../app/alacritty.nix

    # apps
    ../../app/neovim.nix
    ../../app/git.nix
    ../../app/foot.nix
    #../../app/spotify.nix
    ../../app/tofi.nix
    ../../app/vscode.nix
    ../../app/obs.nix
    ../../app/ghostty.nix
    ../../app/irssi.nix
  ];

  nixpkgs = {
    overlays = [
      (final: prev: {
        unstable = import inputs.nixpkgs-unstable {
          system = "x86_64-linux";
          config.allowUnfree = true;
        };
      })
      inputs.nix-vscode-extensions.overlays.default
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

  # Add stuff for your user as you see fit:
  # programs.neovim.enable = true;
  # home.packages = with pkgs; [ steam ];

  # Enable home-manager and git
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

  ############
  # services #
  ############

  # auto disk mounting
  services.udiskie = {
    enable = true;
    settings = {
      program_options = {
        udisks_version = 2;
        tray = false;
      };
      notifications = {
        device_unmounted = false;
        device_added = -1;
        device_removed = -1;
        device_mounted = -1;
      };
    };
  };

  # notifications
  services.mako = {
    enable = true;
    defaultTimeout = 4000;
    margin = "58,6";
    font = "Fira Sans 12";
    borderRadius = 5;
  };
}

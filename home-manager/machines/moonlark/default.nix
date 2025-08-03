{ inputs, ... }:
{
  imports = [
    (inputs.import-tree ../../modules)
  ];

  nixpkgs.enable = true;

  home = {
    username = "kierank";
    homeDirectory = "/home/kierank";
  };

  dots = {
    shell = {
      enable = true;
    };
    terminal = {
      alacritty.enable = true;
      ghostty.enable = true;
    };
    apps = {
      irssi.enable = true;
      qutebrowser.enable = true;
      spotify.enable = true;
      vscode.enable = true;
      crush.enable = true;
    };
    theming.enable = true;
    wm.hyprland.enable = true;
  };

  # Enable home-manager and git
  programs.home-manager.enable = true;

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";
}

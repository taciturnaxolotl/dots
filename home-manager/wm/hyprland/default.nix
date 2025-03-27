{ self, config, lib, pkgs, inputs, ... }: {
  imports = [
    ./hypridle.nix
    ./waybar.nix
  ];

  # catppuccin theme shared between hyprlock and hyprland itself
  xdg.configFile."hypr/macchiato.conf".source = ../../dots/macchiato.conf;

  # hyprland config
  xdg.configFile."hypr/hyprland.conf".source = ../../dots/hyprland.conf;
  xdg.configFile."hypr/prettify-ss.sh".source = ../../dots/prettify-ss.sh;
  xdg.configFile."hypr/tofi-emoji.sh".source = ../../dots/tofi-emoji.sh;

  # hyprlock config
  xdg.configFile."hypr/hyprlock.conf".source = ../../dots/hyprlock.conf;
  xdg.configFile."face.jpeg".source = ../../dots/face.jpeg;
  programs.hyprlock.enable = true;

  # sunpaper
  xdg.configFile."sunpaper/config".source = ../../dots/sunpaperconfig;
  xdg.configFile."sunpaper/images/".source = "${pkgs.sunpaper}/share/sunpaper/images";

  # hyprpaper
  xdg.configFile."hypr/hyprpaper.conf".source = ../../dots/hyprpaper.conf;
  xdg.configFile."hypr/frameworks.jpg".source = ../../dots/frameworks.jpg;

  # portal
  xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
      configPackages = with pkgs; [ xdg-desktop-portal-gtk ];
  };
}

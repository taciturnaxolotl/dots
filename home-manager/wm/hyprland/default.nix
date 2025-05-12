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

  # hyprpaper
  xdg.configFile."hypr/hyprpaper.conf".source = ../../dots/hyprpaper.conf;
  xdg.configFile."hypr/randomize.sh".source = ../../dots/randomize-wallpaper.sh;
  xdg.configFile."hypr/wall/acon-pier.jpg".source = ../../dots/wallpapers/acon-pier.jpg;
  xdg.configFile."hypr/wall/clouds-tongyu.jpg".source = ../../dots/wallpapers/clouds-tongyu.jpg;
  xdg.configFile."hypr/wall/frameworks.jpg".source = ../../dots/wallpapers/frameworks.jpg;
  xdg.configFile."hypr/wall/acon-forest.jpg".source = ../../dots/wallpapers/acon-forest.jpg;
  xdg.configFile."hypr/wall/acon-gradient-clouds.jpg".source = ../../dots/wallpapers/acon-gradient-clouds.jpg;
  xdg.configFile."hypr/wall/kailing-forest.jpg".source = ../../dots/wallpapers/kailing-forest.jpg;
  xdg.configFile."hypr/wall/acon-fsh.jpg".source = ../../dots/wallpapers/acon-fsh.jpg;
  xdg.configFile."hypr/wall/tongyu-waves.jpg".source = ../../dots/wallpapers/tongyu-waves.jpg;
  xdg.configFile."hypr/wall/acon-rocks.jpg".source = ../../dots/wallpapers/acon-rocks.jpg;
  xdg.configFile."hypr/wall/kailing-comet.jpg".source = ../../dots/wallpapers/kailing-comet.jpg;
  xdg.configFile."hypr/wall/acon-star.jpg".source = ../../dots/wallpapers/acon-star.jpg;

  # hyprrec.sh
  xdg.configFile."hypr/hyprrec.sh".source = ../../dots/hyprrec.sh;

  # portal
  xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
      configPackages = with pkgs; [ xdg-desktop-portal-gtk ];
  };
}

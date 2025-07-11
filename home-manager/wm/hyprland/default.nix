{
  pkgs,
  ...
}:
{
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
  xdg.configFile."hypr/wall/acon-forest.jpg".source = ../../dots/wallpapers/acon-forest.jpg;
  xdg.configFile."hypr/wall/acon-gradient-clouds.jpg".source =
    ../../dots/wallpapers/acon-gradient-clouds.jpg;
  xdg.configFile."hypr/wall/acon-fsh.jpg".source = ../../dots/wallpapers/acon-fsh.jpg;
  xdg.configFile."hypr/wall/tongyu-waves.jpg".source = ../../dots/wallpapers/tongyu-waves.jpg;
  xdg.configFile."hypr/wall/acon-rocks.jpg".source = ../../dots/wallpapers/acon-rocks.jpg;
  xdg.configFile."hypr/wall/kailing-comet.jpg".source = ../../dots/wallpapers/kailing-comet.jpg;
  xdg.configFile."hypr/wall/acon-star.jpg".source = ../../dots/wallpapers/acon-star.jpg;
  xdg.configFile."hypr/wall/kailing-canyon.jpg".source = ../../dots/wallpapers/kailing-canyon.jpg;
  xdg.configFile."hypr/wall/kailing-swirls.jpg".source = ../../dots/wallpapers/kailing-swirls.jpg;
  xdg.configFile."hypr/wall/highway.jpg".source = ../../dots/wallpapers/highway.jpg;
  xdg.configFile."hypr/wall/kailing-shooting-star.jpg".source =
    ../../dots/wallpapers/kailing-shooting-star.jpg;
  xdg.configFile."hypr/wall/yessa-cat.jpg".source = ../../dots/wallpapers/yessa-cat.jpg;
  xdg.configFile."hypr/wall/annie-athena.jpg".source = ../../dots/wallpapers/annie-athena.jpg;
  xdg.configFile."hypr/wall/candy-stained-glass.jpg".source =
    ../../dots/wallpapers/candy-stained-glass.jpg;
  xdg.configFile."hypr/wall/tongyu-catcat.jpg".source = ../../dots/wallpapers/tongyu-catcat.jpg;

  # hyprrec.sh
  xdg.configFile."hypr/hyprrec.sh".source = ../../dots/hyprrec.sh;

  # charge-alert.sh
  xdg.configFile."hypr/charge-alert.sh".source = ../../dots/charge-alert.sh;

  # portal
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
    configPackages = with pkgs; [ xdg-desktop-portal-gtk ];
  };
}

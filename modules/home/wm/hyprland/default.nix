{
  lib,
  pkgs,
  config,
  ...
}:
{
  options.atelier.wm.hyprland.enable = lib.mkEnableOption "Enable Hyprland config";
  config = lib.mkIf config.atelier.wm.hyprland.enable {
    atelier.apps.tofi.enable = true;
    programs.hyprlock.enable = true;

    atelier.wallpapers.enable = true;

    xdg.configFile."hypr/macchiato.conf".source = ../../../../dots/macchiato.conf;
    xdg.configFile."hypr/hyprland.conf".source = ../../../../dots/hyprland.conf;
    xdg.configFile."hypr/prettify-ss.sh".source = ../../../../dots/prettify-ss.sh;
    xdg.configFile."hypr/tofi-emoji.sh".source = ../../../../dots/tofi-emoji.sh;
    xdg.configFile."hypr/hyprlock.conf".source = ../../../../dots/hyprlock.conf;
    xdg.configFile."face.jpeg".source = ../../../../dots/face.jpeg;
    xdg.configFile."hypr/hyprpaper.conf".source = ../../../../dots/hyprpaper.conf;
    xdg.configFile."hypr/hyprrec.sh".source = ../../../../dots/hyprrec.sh;
    xdg.configFile."hypr/charge-alert.sh".source = ../../../../dots/charge-alert.sh;

    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
      configPackages = with pkgs; [ xdg-desktop-portal-gtk ];
    };

    services.mako = {
      enable = true;
      settings = {
        default-timeout = 4000;
        margin = "58,6";
        font = "Fira Sans 12";
        border-radius = 5;
      };
    };

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
  };
}

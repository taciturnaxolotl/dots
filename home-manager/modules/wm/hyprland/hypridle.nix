{
  lib,
  config,
  ...
}:
{
  config = lib.mkIf config.dots.wm.hyprland.enable {
    services.hypridle = {
      enable = true;
      settings = {
        general = {
          after_sleep_cmd = "hyprctl dispatch dpms on";
          before_sleep_cmd = "hyprlock";
          ignore_dbus_inhibit = false;
          lock_cmd = "pidof hyprlock || hyprlock";
        };

        listener = [
          {
            timeout = 30;
            on-timeout = "kill $(pidof wluma); brightnessctl -s set 10";
            on-resume = "brightnessctl -r; wluma &";
          }
          {
            timeout = 45;
            on-timeout = "loginctl lock-session";
          }
          {
            timeout = 90;
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
          {
            timeout = 150;
            on-timeout = "systemctl suspend";
          }
        ];
      };
    };
  };
}

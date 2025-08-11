{ lib, config, ... }:
{
  options.atelier.terminal.alacritty.enable = lib.mkEnableOption "Enable Alacritty terminal config";
  config = lib.mkIf config.atelier.terminal.alacritty.enable {
    catppuccin.alacritty.flavor = "mocha";
    programs.alacritty = {
      enable = true;
      settings = {
        general.live_config_reload = true;
        cursor = {
          unfocused_hollow = true;
          style = {
            blinking = "On";
          };
        };
        window = {
          opacity = 0.88;
          padding = {
            x = 12;
            y = 12;
          };
        };
        font = {
          size = 13;
          normal = {
            family = "JetBrainsMono Nerd Font";
          };
        };
        colors = {
          normal = {
            magenta = lib.mkForce "#db87c5";
          };
          primary = {
            foreground = lib.mkForce "#ABB2BF";
          };
        };
      };
    };
  };
}

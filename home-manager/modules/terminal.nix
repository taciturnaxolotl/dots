{ lib, config, ... }:
{
  options.dots.terminal.alacritty.enable = lib.mkEnableOption "Enable Alacritty terminal config";
  options.dots.terminal.ghostty.enable = lib.mkEnableOption "Enable Ghostty terminal config";
  config = lib.mkMerge [
    (lib.mkIf config.dots.terminal.alacritty.enable {
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
    })
    (lib.mkIf config.dots.terminal.ghostty.enable {
      home.file.".config/ghostty/config".text = ''
        foreground = "#a7b1d3"
        mouse-hide-while-typing = true
        resize-overlay = "never"
        theme = "catppuccin-mocha"
        window-decoration = false
        window-padding-x = 12
        window-padding-y = 12
        keybind = ctrl+shift+w=close_surface
      '';
    })
  ];
}

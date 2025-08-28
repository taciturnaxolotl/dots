{ lib, config, ... }:
{
  options.atelier.terminal.ghostty = {
    enable = lib.mkEnableOption "Enable Ghostty terminal config";
    windowDecoration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable window decorations for Ghostty";
    };
  };

  config = lib.mkIf config.atelier.terminal.ghostty.enable {
    home.file.".config/ghostty/config".text = ''
      foreground = "#a7b1d3"
      mouse-hide-while-typing = true
      resize-overlay = "never"
      theme = "catppuccin-mocha"
      window-decoration = ${if config.atelier.terminal.ghostty.windowDecoration then "true" else "false"}
      window-padding-x = 12
      window-padding-y = 12
      keybind = ctrl+shift+w=close_surface
    '';
  };
}

{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  home.file.".config/ghostty/config".source = (pkgs.formats.toml { }).generate "ghostty.toml" {
        theme = "catppuccin-mocha";
        foreground = "#a7b1d3";
        "mouse-hide-while-typing" = true;
        "window-decoration" = false;
        "window-padding-y" = 12;
        "window-padding-x" = 12;
  };
}

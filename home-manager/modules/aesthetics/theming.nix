{
  lib,
  inputs,
  config,
  ...
}:
{
  imports = [
    inputs.catppuccin.homeModules.catppuccin
  ];

  options.dots.theming.enable = lib.mkEnableOption "Enable Catppuccin and GTK/QT themeing";
  config = lib.mkIf config.dots.theming.enable {
    catppuccin = {
      enable = true;
      accent = "green";
      flavor = "macchiato";
      cursors = {
        enable = true;
        accent = "blue";
        flavor = "macchiato";
      };
      gtk = {
        enable = true;
        tweaks = [ "normal" ];
      };
      qutebrowser.enable = true;
    };

    dconf.settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
      };
    };

    gtk = {
      enable = true;
    };

    qt = {
      style.name = "kvantum";
      platformTheme.name = "kvantum";
      enable = true;
    };
  };
}

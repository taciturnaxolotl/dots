{ lib, config, ... }:
{
  options.dots.apps.irssi.enable = lib.mkEnableOption "Enable irssi config";
  config = lib.mkIf config.dots.apps.irssi.enable {
    programs.irssi = {
      enable = true;
      extraConfig = ''
        settings = {
          core = {
            real_name = "kieran klukas";
            user_name = "kierank";
            nick = "taciturnaxolotl";
          };
          "fe-common/core" = { theme = "override"; };
        };
      '';
    };
    home.file."/home/kierank/.irssi/override.theme".text = ''
      abstracts = {
          sb_background = "%0%w";
          window_border = "%0%w";
      };
    '';
  };
}

{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.atelier.shell.jj.enable = lib.mkEnableOption {
    description = "Enable jujutsu (jj) configuration";
  };
  
  config = lib.mkIf config.atelier.shell.jj.enable {
    home.packages = [ pkgs.lazyjj ];
  
    programs.jujutsu = {
      enable = true;
      settings = {
        user = {
          name = "Kieran Klukas";
          email = "kieran@dunkirk.sh";
        };
        ui = {
          default-command = "log";
          pager = "delta";
        };
        signing = {
          sign-all = true;
          backend = "ssh";
          key = "~/.ssh/id_rsa.pub";
        };
        git = {
          push-new-bookmarks = true;
          auto-local-bookmark = true;
        };
        "revset-aliases" = {
          "mine()" = "author(kieran@dunkirk.sh) | author(me@dunkirk.sh)";
        };
      };
    };
  };
}

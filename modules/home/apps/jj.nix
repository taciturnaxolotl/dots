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
          pager = "less -RS";
        };
        "--scope" = [
          {
            "--when".commands = [ "diff" "show" ];
            ui = {
              pager = "delta";
              diff-formatter = ":git";
            };
          }
        ];
        signing = {
          behavior = "force";
          backend = "ssh";
          key = "~/.ssh/id_rsa.pub";
        };
        remotes.origin.auto-track-bookmarks = "*";
        "revset-aliases" = {
          "mine()" = "author(kieran@dunkirk.sh) | author(me@dunkirk.sh)";
          "closest_bookmark(to)" = "heads(::to & bookmarks())";
        };
        aliases = {
          tug = [
            "bookmark"
            "move"
            "--from"
            "closest_bookmark(@-)"
            "--to"
            "@-"
          ];
          pull = [
            "git"
            "fetch"
          ];
          s = [ "squash" ];
          si = [
            "squash"
            "--interactive"
          ];
        };
        "template-aliases" = {
          "format_short_change_id(id)" = "id.shortest()";
        };
      };
    };
  };
}

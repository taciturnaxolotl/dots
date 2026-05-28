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
          default-command = "log-recent";
          pager = "delta";
        };
        signing = {
          behavior = "force";
          backend = "ssh";
          key = "~/.ssh/id_rsa.pub";
        };
        remotes.origin.auto-track-bookmarks = "*";
        "revset-aliases" = {
          "mine()" = "author(kieran@dunkirk.sh) | author(me@dunkirk.sh)";
          "closest_bookmark(to)" = "heads(::to & bookmarks())";
          "default()" = ''coalesce(trunk(),root())::present(@) | ancestors(visible_heads() & recent(), 2)'';
          "recent()" = ''committer_date(after:"1 month ago")'';
        };
        aliases = {
          tug = [ "bookmark" "move" "--from" "closest_bookmark(@-)" "--to" "@-" ];
          pull = [ "git" "fetch" ];
          s = [ "squash" ];
          si = [ "squash" "--interactive" ];
          log-recent = [ "log" "-r" "default() & recent()" ];
        };
        "template-aliases" = {
          "format_short_change_id(id)" = "id.shortest()";
        };
      };
    };
  };
}

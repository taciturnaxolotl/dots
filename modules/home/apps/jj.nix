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
          track-github-PR = [
            "util"
            "exec"
            "--"
            "sh"
            "-euxc"
            ''
              PR=$1
              gh pr view --json headRepository,headRefName,headRepositoryOwner $PR --jq '"
                set_remote() {
                  jj 2>/dev/null git remote add \"$1\" \"$2\" ||
                  jj git remote set-url \"$1\" \"$2\";
                }
                set_remote \(.headRepositoryOwner.login) git@github.com:\(.headRepositoryOwner.login)/\(.headRepository.name)
                jj git fetch --remote \(.headRepositoryOwner.login) --branch \(.headRefName)
                jj bookmark track \(.headRefName) --remote=\(.headRepositoryOwner.login)
              "' |
              bash -euxs
            ''
            "jj-track-github-PR"
          ];
          push-pr = [
            "util"
            "exec"
            "--"
            "sh"
            "-euxc"
            ''
              INFO=$(jj bookmark list --color never --all-remotes \
                -r 'closest_bookmark(@-)' \
                -T 'if(remote && remote != "git" && remote != "origin", name ++ "\t" ++ remote ++ "\n", "")')
              if [ -z "$INFO" ]; then
                echo "No non-origin tracked bookmark found on @-, falling back to origin" >&2
                BRANCH=$(jj bookmark list --color never -r 'closest_bookmark(@-)' -T 'name ++ "\n"' | head -1)
                jj git push --bookmark "$BRANCH"
              else
                BRANCH=$(echo "$INFO" | head -1 | cut -f1)
                REMOTE=$(echo "$INFO" | head -1 | cut -f2)
                jj git push --bookmark "$BRANCH" --remote "$REMOTE"
              fi
            ''
            "jj-push-pr"
          ];
        };
        "template-aliases" = {
          "format_short_change_id(id)" = "id.shortest()";
        };
      };
    };
  };
}

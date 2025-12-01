{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.atelier.shell.git.enable = lib.mkEnableOption {
    description = "Enable global Git configuration";
  };
  config = lib.mkIf config.atelier.shell.git.enable {
    programs.git = {
      enable = true;
      includes = [
        {
          path = pkgs.writeText "git-user-config" ''
            [user]
              name = Kieran Klukas
              email = kieranklukas@cedarville.edu
              signingKey = ~/.ssh/id_ed25519_cedarville.pub
            [core]
              sshCommand = ssh -i ~/.ssh/id_ed25519_cedarville
          '';
          condition = "gitdir:~/code/school/";
        }
      ];
      settings = {
        user = {
          name = "Kieran Klukas";
          email = "me@dunkirk.sh";
          signingKey = "~/.ssh/id_rsa.pub";
        };
        alias = {
          c = "commit";
          p = "push";
          ch = "checkout";
          pushfwl = "push --force-with-lease --force-if-includes";
        };
        branch.sort = "-committerdate";
        pager.branch = false;
        column.ui = "auto";
        commit.gpgsign = true;
        gpg.format = "ssh";
        gpg.ssh.allowedSignersFile = "~/.ssh/allowedSigners";
        pull.rebase = true;
        push.autoSetupRemote = true;
        init.defaultBranch = "main";
      };
    };
    programs.delta = {
      enable = true;
      enableGitIntegration = true;
    };
    programs.gh.enable = true;
    programs.lazygit = {
      enable = true;
      settings = {
        gui.theme = {
          lightTheme = false;
          activeBorderColor = [
            "blue"
            "bold"
          ];
          inactiveBorderColor = [ "black" ];
          selectedLineBgColor = [ "default" ];
        };
      };
    };
    programs.gh-dash = {
      enable = true;
      settings = {
        prSections = [
          {
            title = "Mine";
            filters = "is:open author:@me updated:>={{ nowModify \"-3w\" }} sort:updated-desc archived:false";
            layout.author.hidden = true;
          }
          {
            title = "Review";
            filters = "sort:updated-desc is:pr is:open review-requested:taciturnaxolotl archived:false";
          }
          {
            title = "All";
            filters = "sort:updated-desc is:pr is:open user:@me archived:false";
          }
        ];
        issuesSections = [
          {
            title = "Open";
            filters = "user:@me is:open archived:false -author:@me sort:updated-desc";
          }
          {
            title = "Assigned";
            filters = "is:issue state:open archived:false assignee:@me sort:updated-desc ";
          }
          {
            title = "Creator";
            filters = "author:@me is:open archived:false";
          }
          {
            title = "Hackclub";
            filters = "is:issue org:hackclub archived:false involves:@me sort:updated-desc is:open";
          }
          {
            title = "All";
            filters = "is:issue involves:@me archived:false sort:updated-desc is:open";
          }
        ];
        pager.diff = "diffnav";
        defaults = {
          view = "prs";
          refetchIntervalMinutes = 5;
          layout.prs = {
            repoName = {
              grow = true;
              width = 10;
              hidden = false;
            };
            base.hidden = true;
          };
          preview = {
            open = true;
            width = 84;
          };
          prsLimit = 20;
          issuesLimit = 20;
        };
        repoPaths = {
          "taciturnaxolotl/*" = "~/code/personal/*";
          "hackclub/*" = "~/code/hackclub/*";
        };
        keybindings = {
          universal = [
            {
              key = "g";
              name = "lazygit";
              command = "cd {{.RepoPath}} && lazygit";
            }
          ];
          prs = [
            {
              key = "O";
              builtin = "checkout";
            }
            {
              key = "m";
              command = "gh pr merge --admin --repo {{.RepoName}} {{.PrNumber}}";
            }
            {
              key = "C";
              name = "code review";
              command = "tmux new-window -c {{.RepoPath}} 'nvim -c \":silent Octo pr edit {{.PrNumber}}\"'";
            }
            {
              key = "a";
              name = "lazygit add";
              command = "cd {{.RepoPath}} && git add -A && lazygit";
            }
            {
              key = "v";
              name = "approve";
              command = "gh pr review --repo {{.RepoName}} --approve --body \"$(gum input --prompt='Approval Comment: ')\" {{.PrNumber}}";
            }
          ];
        };
        theme = {
          ui = {
            sectionsShowCount = true;
            table.compact = false;
          };
        };
      };
    };
  };
}

{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: {
  programs.oh-my-posh = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      version = 2;
      final_space = true;
      console_title_template = "{{ .Shell }} in {{ .Folder }}";
      blocks = [
        {
          type = "prompt";
          alignment = "left";
          newline = true;
          segments = [
            {
              type = "path";
              style = "plain";
              background = "transparent";
              foreground = "blue";
              template = "{{ .Path }} ";
              properties = {
                style = "full";
              };
            }
            {
              type = "git";
              style = "plain";
              foreground = "p:grey";
              background = "transparent";
              template = "{{if not .Detached}}{{ .HEAD }}{{else}}@{{ printf \"%.7s\" .Commit.Sha }}{{end}}{{ if .Staging.Changed }} ({{ .Staging.String }}){{ end }}{{ if .Working.Changed }}*{{ end }} <cyan>{{ if .BranchStatus }}{{ .BranchStatus }}{{ end }}</>";
              properties = {
                branch_icon = "";
                branch_identical_icon = "";
                branch_gone_icon = "";
                branch_ahead_icon = "⇡";
                branch_behind_icon = "⇣";
                commit_icon = "@";
                fetch_status = true;
              };
            }
          ];
        }
        {
          type = "rprompt";
          overflow = "hidden";
          segments = [
            {
              type = "executiontime";
              style = "plain";
              foreground = "yellow";
              background = "transparent";
              template = "{{ .FormattedMs }}";
              properties = {
                threshold = 3000;
              };
            }
          ];
        }
        {
          type = "prompt";
          alignment = "left";
          newline = true;
          segments = [
            {
              type = "text";
              style = "plain";
              foreground_templates = [
                "{{if gt .Code 0}}red{{end}}"
                "{{if eq .Code 0}}magenta{{end}}"
              ];
              background = "transparent";
              template = "❯";
            }
          ];
        }
      ];
      transient_prompt = {
        foreground_templates = [
          "{{if gt .Code 0}}red{{end}}"
          "{{if eq .Code 0}}magenta{{end}}"
        ];
        background = "transparent";
        template = "❯ ";
      };
      secondary_prompt = {
        foreground = "p:gray";
        background = "transparent";
        template = "❯❯ ";
      };
      palette = {
        grey = "#6c6c6c";
      };
    };
  };


  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ll = "ls -l";
      la = "ls -la";
      gc = "git commit";
      gp = "git push";
      rr = "rm -Rf";
      ghrpc = "gh repo create -c";
    };
    initExtra = ''
      #ssh auto reconnect
      assh() {
          local host=$1
          local port=$2
        while true; do
              ssh -p $port -o "BatchMode yes" $host || sleep 1
          done
      }
      # hackatime summary
      summary() {
        local user_id=$1
        curl -X 'GET' \
          "https://waka.hackclub.com/api/summary?user=''${user_id}&interval=high_seas" \
            -H 'accept: application/json' \
            -H 'Authorization: Bearer 2ce9e698-8a16-46f0-b49a-ac121bcfd608' | jq '. + {
              "total_categories_sum": (.categories | map(.total) | add),
              "total_categories_human_readable": (
                (.categories | map(.total) | add) as $total_seconds |
                "\($total_seconds / 3600 | floor)h \(($total_seconds % 3600) / 60 | floor)m \($total_seconds % 60)s"
              ),
              "projectsKeys": (
                  .projects | sort_by(-.total) | map(.key)
                )
        }'
      }

      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
      zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
      zstyle ':completion:*' menu no
      zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
      zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'
    '';
    history = {
      size = 10000;
      path = "${config.xdg.dataHome}/zsh/history";
      ignoreDups = true;
      ignoreAllDups = true;
      ignoreSpace = true;
      expireDuplicatesFirst = true;
      share = true;
      extended = true;
      append = true;
    };

    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "sudo" "docker" "git" "command-not-found" "colored-man-pages" ];
    };

    plugins = [
      {
        # will source zsh-autosuggestions.plugin.zsh
        name = "zsh-autosuggestions";
        src = pkgs.fetchFromGitHub {
          owner = "zsh-users";
          repo = "zsh-autosuggestions";
          rev = "v0.7.0";
          sha256 = "sha256-KLUYpUu4DHRumQZ3w59m9aTW6TBKMCXl2UcKi4uMd7w=";
        };
      }
      {
        # will source zsh-sytax-highlighting
         name = "zsh-sytax-highlighting";
         src = pkgs.fetchFromGitHub {
          owner = "zsh-users";
          repo = "zsh-syntax-highlighting";
          rev = "0.8.0";
         sha256 = "sha256-iJdWopZwHpSyYl5/FQXEW7gl/SrKaYDEtTH9cGP7iPo=";
        };
      }
      {
        # fzf tab completion
        name = "fzf-tab";
        src = pkgs.fetchFromGitHub {
          owner = "aloxaf";
          repo = "fzf-tab";
          rev = "v1.1.2";
          sha256 = "sha256-Qv8zAiMtrr67CbLRrFjGaPzFZcOiMVEFLg1Z+N6VMhg=";
        };
      }
    ];
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    colors = {
      bg = lib.mkForce "";
    };
  };
}

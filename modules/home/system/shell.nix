{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
{
  options.atelier.shell.enable = lib.mkEnableOption "Custom shell config";
  config = lib.mkIf config.atelier.shell.enable {
    programs.oh-my-posh = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        upgrade = {
          notice = false;
          interval = "2w";
          auto = false;
        };
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
                type = "session";
                background = "transparent";
                foreground = "yellow";
                template = "{{ if .SSHSession }}{{.HostName}} {{ end }}";
              }
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
              {
                type = "nix-shell";
                style = "plain";
                foreground = "red";
                background = "transparent";
                template = ''{{if ne .Type "unknown" }} {{ .Type }}{{ end }}'';
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
        cat = "bat";
        ls = "eza";
        ll = "eza -l";
        la = "eza -la";
        gc = "git commit";
        gp = "git push";
        rr = "rm -Rf";
        ghrpc = "gh repo create -c";
        goops = "git commit --amend --no-edit && git push --force-with-lease";
        vi = "nvim";
        vim = "nvim";
      };
      initContent = ''
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
            "https://waka.hackclub.com/api/summary?user=''${user_id}&interval=month" \
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

        tangled() {
          # Configuration variables - set these to your defaults
          local default_plc_id="did:plc:krxbvxvis5skq7jj6eot23ul"
          local default_github_username="taciturnaxolotl"
          local default_knot_host="knot.dunkirk.sh"
          local extracted_github_username=""

          # Check if current directory is a git repository
          if ! git rev-parse --is-inside-work-tree &>/dev/null; then
            echo "Not a git repository"
            return 1
          fi

          # Get the repository name from the current directory
          local repo_name=$(basename "$(git rev-parse --show-toplevel)")

          # Check if origin remote exists and points to knot
          local origin_url=$(git remote get-url origin 2>/dev/null)
          local origin_knot=false

          if [[ -n "$origin_url" ]]; then
            # Try to extract GitHub username if origin is a GitHub URL
            if [[ "$origin_url" == *"github.com"* ]]; then
              extracted_github_username=$(echo "$origin_url" | sed -E 's/.*github\.com[:/]([^/]+)\/.*$/\1/')
              # Override the default username with the extracted one
              default_github_username=$extracted_github_username
            fi

            if [[ "$origin_url" == *"$default_knot_host"* || "$origin_url" == *"knot.dunkirk.sh"* ]]; then
              origin_knot=true
              echo "✅ Origin remote exists and points to knot"
            else
              echo "⚠️ Origin remote exists but doesn't point to knot"
            fi
          else
            echo "⚠️ Origin remote doesn't exist"
          fi

          # Check if github remote exists
          local github_exists=false
          if git remote get-url github &>/dev/null; then
            github_exists=true
            echo "✅ GitHub remote exists"
          else
            echo "⚠️ GitHub remote doesn't exist"
          fi

          # Fix remotes if needed
          if [[ "$origin_knot" = false || "$github_exists" = false ]]; then
            # Prompt for PLC identifier if needed
            local plc_id=""
            local should_fix_origin=false
            
            if [[ "$origin_knot" = false ]]; then
              if [[ -n "$origin_url" ]]; then
                echo -n "Migrate origin from $origin_url to knot.dunkirk.sh? [Y/n]: "
                read fix_input
                if [[ -z "$fix_input" || "$fix_input" =~ ^[Yy]$ ]]; then
                  should_fix_origin=true
                fi
              else
                should_fix_origin=true
              fi
              
              if [[ "$should_fix_origin" = true ]]; then
                echo -n "Enter your PLC identifier [default: $default_plc_id]: "
                read plc_input
                plc_id=''${plc_input:-$default_plc_id}
              fi
            fi

            # Prompt for GitHub username with default from origin if available
            local github_username=""
            if [[ "$github_exists" = false ]]; then
              echo -n "Enter your GitHub username [default: $default_github_username]: "
              read github_input
              github_username=''${github_input:-$default_github_username}
            fi

            # Set up origin remote if needed
            if [[ "$should_fix_origin" = true && -n "$plc_id" ]]; then
              if git remote get-url origin &>/dev/null; then
                git remote remove origin
              fi
              git remote add origin "git@$default_knot_host:''${plc_id}/''${repo_name}"
              echo "✅ Set up origin remote: git@$default_knot_host:''${plc_id}/''${repo_name}"
            fi

            # Set up GitHub remote if needed
            if [[ "$github_exists" = false && -n "$github_username" ]]; then
              git remote add github "git@github.com:''${github_username}/''${repo_name}.git"
              echo "✅ Set up GitHub remote: git@github.com:''${github_username}/''${repo_name}.git"
            fi
          else
            echo "Remotes are correctly configured"
          fi
        }

        # Post AtProto status updates
        now() {
          local message=""
          local prompt_message=true
          local account1_name=""
          local account2_name=""
          local account1_jwt=""
          local account2_jwt=""

          # Load account information from agenix secrets
          if [[ -f "/run/agenix/bluesky" ]]; then
            source "/run/agenix/bluesky"
          else
            echo "Error: Bluesky credentials file not found at /run/agenix/bluesky"
            return 1
          fi

          # Parse arguments
          while [[ $# -gt 0 ]]; do
            case "$1" in
              -m|--message)
                message="$2"
                prompt_message=false
                shift 2
                ;;
              *)
                echo "Usage: now [-m|--message \"your message\"]"
                return 1
                ;;
            esac
          done

          # Prompt for message if none provided
          if [[ "$prompt_message" = true ]]; then
            echo -n "$ACCOUNT1 is: "
            read message

            if [[ -z "$message" ]]; then
              echo "No message provided. Aborting."
              return 1
            fi
          fi

          # Generate JWT for ACCOUNT1
          local account1_response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -d '{
              "identifier": "'$ACCOUNT1'",
              "password": "'$ACCOUNT1_PASSWORD'"
            }' \
            "https://bsky.social/xrpc/com.atproto.server.createSession")

          account1_jwt=$(echo "$account1_response" | jq -r '.accessJwt')

          if [[ -z "$account1_jwt" || "$account1_jwt" == "null" ]]; then
            echo "Failed to authenticate account $ACCOUNT1"
            echo "Response: $account1_response"
            return 1
          fi

          # Generate JWT for ACCOUNT2
          local account2_response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -d '{
              "identifier": "'$ACCOUNT2'",
              "password": "'$ACCOUNT2_PASSWORD'"
            }' \
            "https://bsky.social/xrpc/com.atproto.server.createSession")

          account2_jwt=$(echo "$account2_response" | jq -r '.accessJwt')

          if [[ -z "$account2_jwt" || "$account2_jwt" == "null" ]]; then
            echo "Failed to authenticate account $ACCOUNT2"
            echo "Response: $account2_response"
            return 1
          fi

          # Post to ACCOUNT1 as a.status.updates
          local account1_post_response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $account1_jwt" \
            -d '{
              "collection": "a.status.update",
              "repo": "'$ACCOUNT1'",
              "record": {
                "$type": "a.status.update",
                "text": "'"$message"'",
                "createdAt": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
              }
            }' \
            "https://bsky.social/xrpc/com.atproto.repo.createRecord")

          if [[ $(echo "$account1_post_response" | jq -r 'has("error")') == "true" ]]; then
            echo "Error posting to $ACCOUNT1:"
            echo "$account1_post_response" | jq
            return 1
          fi

          # Post to ACCOUNT2 as normal post
          local account2_post_response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $account2_jwt" \
            -d '{
              "collection": "app.bsky.feed.post",
              "repo": "'$ACCOUNT2'",
              "record": {
                "$type": "app.bsky.feed.post",
                "text": "'"$message"'",
                "createdAt": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
              }
            }' \
            "https://bsky.social/xrpc/com.atproto.repo.createRecord")

          if [[ $(echo "$account2_post_response" | jq -r 'has("error")') == "true" ]]; then
            echo "Error posting to $ACCOUNT2:"
            echo "$account2_post_response" | jq
            return 1
          fi

          echo "done"
        }

        ghostty_setup() {
          local target="$1"

          if [[ -z "$target" ]]; then
            echo "Usage: ghostty_setup <user@host>"
            return 1
          fi

          # Copy SSH key
          echo "Copying SSH key to $target..."
          ssh-copy-id "$target" || { echo "ssh-copy-id failed"; return 2; }

          # Pipe infocmp output to tic on remote host
          echo "Sending xterm-ghostty terminfo to $target..."
          infocmp -x xterm-ghostty | ssh "$target" 'tic -x -' || { echo "Terminfo transfer failed"; return 3; }

          echo "Done."
        }

        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
        zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
        zstyle ':completion:*' menu no
        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
        zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

        eval "$(terminal-wakatime init)"
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
        plugins = [
          "git"
          "sudo"
          "docker"
          "git"
          "command-not-found"
          "colored-man-pages"
        ];
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
    programs.atuin = {
      enable = true;
      settings = {
        auto_sync = true;
        sync_frequency = "5m";
        sync_address = "https://api.atuin.sh";
        search_mode = "fuzzy";
        update_check = false;
        style = "auto";
        sync.records = true;
        dotfiles.enabled = false;
      };
    };
    programs.yazi = {
      enable = true;
      enableZshIntegration = true;
    };

    home.packages = with pkgs; [
      pkgs.unstable.wakatime-cli
      inputs.terminal-wakatime.packages.${pkgs.system}.default
      unzip
      dog
      dust
      wget
      curl
      jq
      fd
      eza
      bat
      ripgrep
      ripgrep-all
      neofetch
      glow
    ];

    atelier.shell.git.enable = lib.mkDefault true;
  };
}

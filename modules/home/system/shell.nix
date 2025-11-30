{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  tangled-setup = pkgs.writeShellScriptBin "tangled-setup" ''
    # Configuration
    default_plc_id="did:plc:krxbvxvis5skq7jj6eot23ul"
    default_github_username="taciturnaxolotl"
    default_knot_host="knot.dunkirk.sh"

    # Verify git repository
    if ! ${pkgs.git}/bin/git rev-parse --is-inside-work-tree &>/dev/null; then
      ${pkgs.gum}/bin/gum style --foreground 196 "Not a git repository"
      exit 1
    fi

    repo_name=$(basename "$(${pkgs.git}/bin/git rev-parse --show-toplevel)")
    ${pkgs.gum}/bin/gum style --bold --foreground 212 "Configuring tangled remotes for: $repo_name"
    echo

    # Check current remotes
    origin_url=$(${pkgs.git}/bin/git remote get-url origin 2>/dev/null)
    github_url=$(${pkgs.git}/bin/git remote get-url github 2>/dev/null)
    origin_is_knot=false
    github_username="$default_github_username"

    # Extract GitHub username from existing origin if it's GitHub
    if [[ "$origin_url" == *"github.com"* ]]; then
      github_username=$(echo "$origin_url" | ${pkgs.gnused}/bin/sed -E 's/.*github\.com[:/]([^/]+)\/.*$/\1/')
    fi

    # Check if origin points to knot
    if [[ "$origin_url" == *"$default_knot_host"* ]]; then
      origin_is_knot=true
      ${pkgs.gum}/bin/gum style --foreground 35 "✓ Origin → knot ($origin_url)"
    elif [[ -n "$origin_url" ]]; then
      ${pkgs.gum}/bin/gum style --foreground 214 "! Origin → $origin_url (not knot)"
    else
      ${pkgs.gum}/bin/gum style --foreground 214 "! Origin not configured"
    fi

    # Check github remote
    if [[ -n "$github_url" ]]; then
      ${pkgs.gum}/bin/gum style --foreground 35 "✓ GitHub → $github_url"
    else
      ${pkgs.gum}/bin/gum style --foreground 214 "! GitHub remote not configured"
    fi

    echo

    # Configure origin remote if needed
    if [[ "$origin_is_knot" = false ]]; then
      should_migrate=true
      if [[ -n "$origin_url" ]]; then
        ${pkgs.gum}/bin/gum confirm "Migrate origin from $origin_url to knot?" || should_migrate=false
      fi

      if [[ "$should_migrate" = true ]]; then
        plc_id=$(${pkgs.gum}/bin/gum input --placeholder "$default_plc_id" --prompt "PLC ID: " --value "$default_plc_id")
        plc_id=''${plc_id:-$default_plc_id}

        if ${pkgs.git}/bin/git remote get-url origin &>/dev/null; then
          ${pkgs.git}/bin/git remote remove origin
        fi
        ${pkgs.git}/bin/git remote add origin "git@$default_knot_host:''${plc_id}/''${repo_name}"
        ${pkgs.gum}/bin/gum style --foreground 35 "✓ Configured origin → git@$default_knot_host:''${plc_id}/''${repo_name}"
      fi
    fi

    # Configure github remote if needed
    if [[ -z "$github_url" ]]; then
      username=$(${pkgs.gum}/bin/gum input --placeholder "$github_username" --prompt "GitHub username: " --value "$github_username")
      username=''${username:-$github_username}

      ${pkgs.git}/bin/git remote add github "git@github.com:''${username}/''${repo_name}.git"
      ${pkgs.gum}/bin/gum style --foreground 35 "✓ Configured github → git@github.com:''${username}/''${repo_name}.git"
    fi

    echo

    # Configure default push remote
    current_remote=$(${pkgs.git}/bin/git config --get branch.main.remote 2>/dev/null)
    if [[ -z "$current_remote" ]]; then
      if ${pkgs.gum}/bin/gum confirm "Set origin (knot) as default push remote?"; then
        ${pkgs.git}/bin/git config branch.main.remote origin
        ${pkgs.gum}/bin/gum style --foreground 35 "✓ Default push remote → origin"
      fi
    elif [[ "$current_remote" != "origin" ]]; then
      ${pkgs.gum}/bin/gum style --foreground 117 "Current default: $current_remote"
      if ${pkgs.gum}/bin/gum confirm "Change default push remote to origin (knot)?"; then
        ${pkgs.git}/bin/git config branch.main.remote origin
        ${pkgs.gum}/bin/gum style --foreground 35 "✓ Default push remote → origin"
      fi
    else
      ${pkgs.gum}/bin/gum style --foreground 35 "✓ Default push remote is origin"
    fi
  '';
in
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
      tangled-setup
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

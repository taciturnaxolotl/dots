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

  assh = pkgs.writeShellScriptBin "assh" ''
    # SSH auto-reconnect
    host=$1
    port=$2

    if [[ -z "$host" || -z "$port" ]]; then
      ${pkgs.gum}/bin/gum style --foreground 196 "Usage: assh <host> <port>"
      exit 1
    fi

    ${pkgs.gum}/bin/gum style --foreground 212 "Connecting to $host:$port (auto-reconnect enabled)..."
    
    while true; do
      ${pkgs.openssh}/bin/ssh -p "$port" -o "BatchMode yes" "$host" || {
        ${pkgs.gum}/bin/gum style --foreground 214 "Connection lost. Reconnecting in 1s..."
        sleep 1
      }
    done
  '';

  hackatime-summary = pkgs.writeShellScriptBin "hackatime-summary" ''
    # Hackatime summary
    user_id=""
    use_waka=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --waka)
          use_waka=true
          shift
          ;;
        *)
          user_id="$1"
          shift
          ;;
      esac
    done

    if [[ -z "$user_id" ]]; then
      user_id=$(${pkgs.gum}/bin/gum input --placeholder "Enter user ID" --prompt "User ID: ")
      if [[ -z "$user_id" ]]; then
        ${pkgs.gum}/bin/gum style --foreground 196 "No user ID provided"
        exit 1
      fi
    fi

    if [[ "$use_waka" = true ]]; then
      host="waka.hackclub.com"
    else
      host="hackatime.hackclub.com"
    fi

    ${pkgs.gum}/bin/gum spin --spinner dot --title "Fetching summary from $host for $user_id..." -- \
      ${pkgs.curl}/bin/curl -s -X 'GET' \
        "https://$host/api/summary?user=''${user_id}&interval=month" \
        -H 'accept: application/json' \
        -H 'Authorization: Bearer 2ce9e698-8a16-46f0-b49a-ac121bcfd608' \
      > /tmp/hackatime-$$.json

    ${pkgs.gum}/bin/gum style --bold --foreground 212 "Summary for $user_id"
    echo

    # Extract and display total time
    total_seconds=$(${pkgs.jq}/bin/jq -r '
      if (.categories | length) > 0 then
        (.categories | map(.total) | add)
      elif (.projects | length) > 0 then
        (.projects | map(.total) | add)
      else
        0
      end
    ' /tmp/hackatime-$$.json)

    if [[ "$total_seconds" -gt 0 ]]; then
      hours=$((total_seconds / 3600))
      minutes=$(((total_seconds % 3600) / 60))
      seconds=$((total_seconds % 60))
      ${pkgs.gum}/bin/gum style --foreground 35 "Total time: ''${hours}h ''${minutes}m ''${seconds}s"
    else
      ${pkgs.gum}/bin/gum style --foreground 214 "No activity recorded"
    fi

    echo

    # Top projects
    ${pkgs.gum}/bin/gum style --bold "Top Projects:"
    ${pkgs.jq}/bin/jq -r '
      if (.projects | length) > 0 then
        .projects | sort_by(-.total) | .[0:10] | .[] | 
        "  \(.key): \((.total / 3600 | floor))h \(((.total % 3600) / 60) | floor)m"
      else
        "  No projects"
      end
    ' /tmp/hackatime-$$.json

    echo

    # Top languages
    ${pkgs.gum}/bin/gum style --bold "Top Languages:"
    ${pkgs.jq}/bin/jq -r '
      if (.languages | length) > 0 then
        .languages | sort_by(-.total) | .[0:10] | .[] | 
        "  \(.key): \((.total / 3600 | floor))h \(((.total % 3600) / 60) | floor)m"
      else
        "  No languages"
      end
    ' /tmp/hackatime-$$.json

    rm -f /tmp/hackatime-$$.json
  '';

  now = pkgs.writeShellScriptBin "now" ''
    # Post AtProto status updates
    message=""
    prompt_message=true

    # Parse arguments
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -m|--message)
          message="$2"
          prompt_message=false
          shift 2
          ;;
        *)
          ${pkgs.gum}/bin/gum style --foreground 196 "Usage: now [-m|--message \"your message\"]"
          exit 1
          ;;
      esac
    done

    # Load account information from agenix secrets
    if [[ -f "/run/agenix/bluesky" ]]; then
      source "/run/agenix/bluesky"
    else
      ${pkgs.gum}/bin/gum style --foreground 196 "Error: Bluesky credentials file not found at /run/agenix/bluesky"
      exit 1
    fi

    # Prompt for message if none provided
    if [[ "$prompt_message" = true ]]; then
      message=$(${pkgs.gum}/bin/gum input --placeholder "What's happening?" --prompt "$ACCOUNT1 is: ")
      if [[ -z "$message" ]]; then
        ${pkgs.gum}/bin/gum style --foreground 214 "No message provided. Aborting."
        exit 1
      fi
    fi

    ${pkgs.gum}/bin/gum spin --spinner dot --title "Posting to Bluesky..." -- /bin/bash <<EOF
    # Generate JWT for ACCOUNT1
    account1_response=\$(${pkgs.curl}/bin/curl -s -X POST \
      -H "Content-Type: application/json" \
      -d '{
        "identifier": "'$ACCOUNT1'",
        "password": "'$ACCOUNT1_PASSWORD'"
      }' \
      "https://bsky.social/xrpc/com.atproto.server.createSession")

    account1_jwt=\$(echo "\$account1_response" | ${pkgs.jq}/bin/jq -r '.accessJwt')

    if [[ -z "\$account1_jwt" || "\$account1_jwt" == "null" ]]; then
      echo "Failed to authenticate account $ACCOUNT1" >&2
      echo "Response: \$account1_response" >&2
      exit 1
    fi

    # Generate JWT for ACCOUNT2
    account2_response=\$(${pkgs.curl}/bin/curl -s -X POST \
      -H "Content-Type: application/json" \
      -d '{
        "identifier": "'$ACCOUNT2'",
        "password": "'$ACCOUNT2_PASSWORD'"
      }' \
      "https://bsky.social/xrpc/com.atproto.server.createSession")

    account2_jwt=\$(echo "\$account2_response" | ${pkgs.jq}/bin/jq -r '.accessJwt')

    if [[ -z "\$account2_jwt" || "\$account2_jwt" == "null" ]]; then
      echo "Failed to authenticate account $ACCOUNT2" >&2
      echo "Response: \$account2_response" >&2
      exit 1
    fi

    # Post to ACCOUNT1 as a.status.updates
    account1_post_response=\$(${pkgs.curl}/bin/curl -s -X POST \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer \$account1_jwt" \
      -d '{
        "collection": "a.status.update",
        "repo": "'$ACCOUNT1'",
        "record": {
          "\$type": "a.status.update",
          "text": "'"$message"'",
          "createdAt": "'\$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
        }
      }' \
      "https://bsky.social/xrpc/com.atproto.repo.createRecord")

    if [[ \$(echo "\$account1_post_response" | ${pkgs.jq}/bin/jq -r 'has("error")') == "true" ]]; then
      echo "Error posting to $ACCOUNT1:" >&2
      echo "\$account1_post_response" | ${pkgs.jq}/bin/jq >&2
      exit 1
    fi

    # Post to ACCOUNT2 as normal post
    account2_post_response=\$(${pkgs.curl}/bin/curl -s -X POST \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer \$account2_jwt" \
      -d '{
        "collection": "app.bsky.feed.post",
        "repo": "'$ACCOUNT2'",
        "record": {
          "\$type": "app.bsky.feed.post",
          "text": "'"$message"'",
          "createdAt": "'\$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
        }
      }' \
      "https://bsky.social/xrpc/com.atproto.repo.createRecord")

    if [[ \$(echo "\$account2_post_response" | ${pkgs.jq}/bin/jq -r 'has("error")') == "true" ]]; then
      echo "Error posting to $ACCOUNT2:" >&2
      echo "\$account2_post_response" | ${pkgs.jq}/bin/jq >&2
      exit 1
    fi
EOF

    if [[ $? -eq 0 ]]; then
      ${pkgs.gum}/bin/gum style --foreground 35 "✓ Posted successfully!"
    else
      ${pkgs.gum}/bin/gum style --foreground 196 "✗ Failed to post"
      exit 1
    fi
  '';

  ghostty-setup = pkgs.writeShellScriptBin "ghostty-setup" ''
    # Copy Ghostty terminfo to remote host
    target="$1"

    if [[ -z "$target" ]]; then
      target=$(${pkgs.gum}/bin/gum input --placeholder "user@host" --prompt "Remote host: ")
      if [[ -z "$target" ]]; then
        ${pkgs.gum}/bin/gum style --foreground 196 "No target provided"
        exit 1
      fi
    fi

    ${pkgs.gum}/bin/gum style --bold --foreground 212 "Setting up Ghostty on $target"
    echo

    ${pkgs.gum}/bin/gum spin --spinner dot --title "Copying SSH key to $target..." -- \
      ${pkgs.openssh}/bin/ssh-copy-id "$target" 2>&1

    if [[ $? -ne 0 ]]; then
      ${pkgs.gum}/bin/gum style --foreground 196 "✗ SSH key copy failed"
      exit 2
    fi

    ${pkgs.gum}/bin/gum style --foreground 35 "✓ SSH key copied"

    ${pkgs.gum}/bin/gum spin --spinner dot --title "Installing xterm-ghostty terminfo on $target..." -- \
      bash -c "${pkgs.ncurses}/bin/infocmp -x xterm-ghostty | ${pkgs.openssh}/bin/ssh '$target' 'tic -x -'" 2>&1

    if [[ $? -ne 0 ]]; then
      ${pkgs.gum}/bin/gum style --foreground 196 "✗ Terminfo transfer failed"
      exit 3
    fi

    ${pkgs.gum}/bin/gum style --foreground 35 "✓ Terminfo installed"
    echo
    ${pkgs.gum}/bin/gum style --foreground 35 --bold "Done! Ghostty is ready on $target"
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
                type = "text";
                style = "plain";
                background = "transparent";
                foreground = "green";
                template = "{{ if .Env.ZMX_SESSION }}[{{ .Env.ZMX_SESSION }}] {{ end }}";
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
                  "{{if eq .Code 0}}{{if .Env.SSH_CONNECTION}}cyan{{else}}magenta{{end}}{{end}}"
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
            "{{if eq .Code 0}}{{if .Env.SSH_CONNECTION}}cyan{{else}}magenta{{end}}{{end}}"
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
      assh
      hackatime-summary
      now
      ghostty-setup
      pkgs.unstable.wakatime-cli
      inputs.terminal-wakatime.packages.${pkgs.stdenv.hostPlatform.system}.default
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

{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:
let
  cfg = config.atelier.shell;
  tangled = cfg.tangled;

  tangled-setup = pkgs.writeShellScriptBin "tangled-setup" ''
        set -euo pipefail

        # Defaults (configured by Nix)
        PLC_ID="${tangled.plcId}"
        GITHUB_USER="${tangled.githubUser}"
        KNOT_HOST="${tangled.knotHost}"
        BRANCH="${tangled.defaultBranch}"
        FORCE=false

        usage() {
          cat <<EOF
    Usage: tangled-setup [OPTIONS]

    Configure git remotes for tangled workflow.
    Sets: origin → knot, github → GitHub

    Options:
      --plc ID              PLC ID (default: $PLC_ID)
      --github-user USER    GitHub username (default: $GITHUB_USER)
      --knot HOST           Knot host (default: $KNOT_HOST)
      --branch BRANCH       Default branch (default: $BRANCH)
      -f, --force           Overwrite existing remotes without checking
      -h, --help            Show this help
    EOF
          exit 0
        }

        while [[ $# -gt 0 ]]; do
          case "$1" in
            -h|--help) usage ;;
            --plc) PLC_ID="$2"; shift 2 ;;
            --github-user) GITHUB_USER="$2"; shift 2 ;;
            --knot) KNOT_HOST="$2"; shift 2 ;;
            --branch) BRANCH="$2"; shift 2 ;;
            -f|--force) FORCE=true; shift ;;
            -*) echo "Unknown option: $1" >&2; exit 1 ;;
            *) shift ;;
          esac
        done

        if ! ${pkgs.git}/bin/git rev-parse --is-inside-work-tree &>/dev/null; then
          ${pkgs.gum}/bin/gum style --foreground 196 "Error: Not a git repository"
          exit 1
        fi

        repo_name=$(basename "$(${pkgs.git}/bin/git rev-parse --show-toplevel)")
        knot_url="git@$KNOT_HOST:$PLC_ID/$repo_name"
        github_url="git@github.com:$GITHUB_USER/$repo_name.git"

        ${pkgs.gum}/bin/gum style --bold --foreground 212 "Configuring tangled remotes for: $repo_name"
        echo

        # Configure origin → knot
        current_origin=$(${pkgs.git}/bin/git remote get-url origin 2>/dev/null || true)
        if [[ -z "$current_origin" ]]; then
          ${pkgs.git}/bin/git remote add origin "$knot_url"
          ${pkgs.gum}/bin/gum style --foreground 35 "✓ origin → $knot_url"
        elif [[ "$current_origin" == *"$KNOT_HOST"* ]]; then
          ${pkgs.gum}/bin/gum style --foreground 35 "✓ origin → $current_origin (already knot)"
        elif [[ "$FORCE" == true ]]; then
          ${pkgs.git}/bin/git remote set-url origin "$knot_url"
          ${pkgs.gum}/bin/gum style --foreground 35 "✓ origin → $knot_url (was: $current_origin)"
        else
          ${pkgs.gum}/bin/gum style --foreground 214 "! origin → $current_origin (use -f to override)"
        fi

        # Configure github remote
        current_github=$(${pkgs.git}/bin/git remote get-url github 2>/dev/null || true)
        if [[ -z "$current_github" ]]; then
          ${pkgs.git}/bin/git remote add github "$github_url"
          ${pkgs.gum}/bin/gum style --foreground 35 "✓ github → $github_url"
        elif [[ "$FORCE" == true ]]; then
          ${pkgs.git}/bin/git remote set-url github "$github_url"
          ${pkgs.gum}/bin/gum style --foreground 35 "✓ github → $github_url (was: $current_github)"
        else
          ${pkgs.gum}/bin/gum style --foreground 35 "✓ github → $current_github"
        fi

        # Set default push to origin
        ${pkgs.git}/bin/git config branch.$BRANCH.remote origin 2>/dev/null || true

        echo
        ${pkgs.gum}/bin/gum style --foreground 117 "Remotes:"
        ${pkgs.git}/bin/git remote -v
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
        # Function to resolve DID to PDS endpoint
        resolve_pds() {
          local identifier="\$1"
          local did=""

          # If identifier is a handle, resolve to DID first
          if [[ ! "\$identifier" =~ ^did: ]]; then
            # Try to resolve handle via DNS first, fallback to bsky.social
            did=\$(${pkgs.curl}/bin/curl -sf "https://bsky.social/xrpc/com.atproto.identity.resolveHandle?handle=\$identifier" | ${pkgs.jq}/bin/jq -r '.did // empty')
            if [[ -z "\$did" ]]; then
              echo "Failed to resolve handle: \$identifier" >&2
              return 1
            fi
          else
            did="\$identifier"
          fi

          # Resolve DID document
          local pds_endpoint=""
          if [[ "\$did" =~ ^did:plc: ]]; then
            # Resolve via PLC directory
            pds_endpoint=\$(${pkgs.curl}/bin/curl -sf "https://plc.directory/\$did" | ${pkgs.jq}/bin/jq -r '.service[] | select(.type == "AtprotoPersonalDataServer") | .serviceEndpoint' | head -n1)
          elif [[ "\$did" =~ ^did:web: ]]; then
            # Resolve via did:web
            local domain="\''${did#did:web:}"
            pds_endpoint=\$(${pkgs.curl}/bin/curl -sf "https://\$domain/.well-known/did.json" | ${pkgs.jq}/bin/jq -r '.service[] | select(.type == "AtprotoPersonalDataServer") | .serviceEndpoint' | head -n1)
          else
            echo "Unsupported DID method: \$did" >&2
            return 1
          fi

          if [[ -z "\$pds_endpoint" ]]; then
            echo "Failed to resolve PDS endpoint for: \$did" >&2
            return 1
          fi

          echo "\$pds_endpoint"
        }

        # Resolve PDS endpoints for both accounts
        account1_pds=\$(resolve_pds "$ACCOUNT1")
        if [[ -z "\$account1_pds" ]]; then
          echo "Failed to resolve PDS for $ACCOUNT1" >&2
          exit 1
        fi

        account2_pds=\$(resolve_pds "$ACCOUNT2")
        if [[ -z "\$account2_pds" ]]; then
          echo "Failed to resolve PDS for $ACCOUNT2" >&2
          exit 1
        fi

        # Generate JWT for ACCOUNT1
        account1_response=\$(${pkgs.curl}/bin/curl -s -X POST \
          -H "Content-Type: application/json" \
          -d '{
            "identifier": "'$ACCOUNT1'",
            "password": "'$ACCOUNT1_PASSWORD'"
          }' \
          "\$account1_pds/xrpc/com.atproto.server.createSession")

        account1_jwt=\$(echo "\$account1_response" | ${pkgs.jq}/bin/jq -r '.accessJwt')
        account1_did=\$(echo "\$account1_response" | ${pkgs.jq}/bin/jq -r '.did')

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
          "\$account2_pds/xrpc/com.atproto.server.createSession")

        account2_jwt=\$(echo "\$account2_response" | ${pkgs.jq}/bin/jq -r '.accessJwt')
        account2_did=\$(echo "\$account2_response" | ${pkgs.jq}/bin/jq -r '.did')

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
            "repo": "'\$account1_did'",
            "record": {
              "\$type": "a.status.update",
              "text": "'"$message"'",
              "createdAt": "'\$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
            }
          }' \
          "\$account1_pds/xrpc/com.atproto.repo.createRecord")

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
            "repo": "'\$account2_did'",
            "record": {
              "\$type": "app.bsky.feed.post",
              "text": "'"$message"'",
              "createdAt": "'\$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
            }
          }' \
          "\$account2_pds/xrpc/com.atproto.repo.createRecord")

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

  ghrpc = pkgs.callPackage ../../../packages/ghrpc.nix {
    inherit (tangled)
      plcId
      githubUser
      knotHost
      domain
      defaultBranch
      ;
  };

  # nixpkgs' util-linux only builds col on Linux; on Darwin it comes with the OS.
  colBin = if pkgs.stdenv.isDarwin then "/usr/bin/col" else "${pkgs.util-linux}/bin/col";

  # Pre-generated shell init scripts to avoid eval "$(cmd)" subprocess overhead at startup.
  zoxide-init = pkgs.runCommand "zoxide-init.zsh" { } ''
    ${pkgs.zoxide}/bin/zoxide init zsh > $out
  '';
  direnv-hook = pkgs.runCommand "direnv-hook.zsh" { } ''
    ${pkgs.direnv}/bin/direnv hook zsh > $out
  '';
  fzf-init = pkgs.runCommand "fzf-init.zsh" { } ''
    ${pkgs.fzf}/bin/fzf --zsh > $out
  '';
  # atuin init is handled by programs.atuin.enableZshIntegration

  # Everything sourced into interactive zsh, in order. Each entry is a store
  # path holding ready-to-source zsh; nothing is eval'd at startup.
  shell-init = [
    zoxide-init
    fzf-init
    direnv-hook
    "${ghrpc}/share/ghrpc/init.zsh"
  ];

  # Pre-compiled instant prompt (zsh auto-uses .zwc next to .zsh).
  instant-prompt = pkgs.runCommand "instant-prompt" { } ''
    mkdir -p $out
    cp ${inputs.impure}/instant-prompt.zsh $out/instant-prompt.zsh
    ${pkgs.zsh}/bin/zsh -c 'zcompile "$1"' _ $out/instant-prompt.zsh
  '';

in
{
  options.atelier.shell = {
    enable = lib.mkEnableOption "Custom shell config";

    ephemeral = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Mark this as an ephemeral environment (red prompt)";
    };

    tangled = {
      plcId = lib.mkOption {
        type = lib.types.str;
        default = "did:plc:krxbvxvis5skq7jj6eot23ul";
        description = "PLC ID for Tangled";
      };

      githubUser = lib.mkOption {
        type = lib.types.str;
        default = "taciturnaxolotl";
        description = "GitHub username";
      };

      knotHost = lib.mkOption {
        type = lib.types.str;
        default = "knot.dunkirk.sh";
        description = "Knot host for git remotes";
      };

      domain = lib.mkOption {
        type = lib.types.str;
        default = "dunkirk.sh";
        description = "Tangled domain for repo creation";
      };

      defaultBranch = lib.mkOption {
        type = lib.types.str;
        default = "main";
        description = "Default git branch";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      # Cache compinit using fpath hash for accurate invalidation.
      # https://lobste.rs/s/k0sbbv/life_is_too_short_for_slow_terminal#c_mmuxpd
      # Based on dullmirror's approach: cache key includes completion file count,
      # uses locking for parallel shell safety, and zcompile for faster loading.
      completionInit = ''
        () {
          emulate -L zsh
          [[ -o interactive ]] || return
          autoload -Uz compinit complist
          # Use fpath directory count as cache key (sub-ms vs 89ms for full file glob).
          local zcd="''${ZDOTDIR:-$HOME}/.zcompdump-''${ZSH_VERSION}-''${#fpath}"
          local zcdc=$zcd.zwc
          local zcda=$zcd.last
          if [[ -e $zcda && -n $zcda(#qN.mh+24) ]]; then
            # Stale: rebuild in background, use cached dump this session.
            { compinit -u -d $zcd; : > $zcda; rm -f $zcdc && zcompile $zcd } &!
            compinit -C -d $zcd
          elif [[ -f $zcd ]]; then
            compinit -C -d $zcd
          else
            # First run or missing dump: full init
            compinit -u -d $zcd
            : > $zcda
            [[ ! -f $zcdc || $zcd -nt $zcdc ]] && rm -f $zcdc && zcompile $zcd &!
          fi
        }
      '';
      syntaxHighlighting.enable = false;

      shellAliases = {
        cat = "bat";
        ls = "eza";
        ll = "eza -l";
        la = "eza -la";
        g = "git";
        ga = "git add";
        gc = "git commit";
        gp = "git push";
        gb = "git branch";
        rr = "rm -Rf";
        goops = "git commit --amend --no-edit && git push --force-with-lease";
        vi = "nvim";
        vim = "nvim";
      };
      initContent = ''
                bindkey -e

                # Instant prompt: print minimal prompt before heavy init (pre-compiled)
                source ${instant-prompt}/instant-prompt.zsh

                # Impure prompt
                source ${inputs.impure}/async.zsh
                IMPURE_CMD_MAX_EXEC_TIME=3
                source ${inputs.impure}/impure.zsh

                # Colored man pages
                man() {
                  env \
                    LESS_TERMCAP_mb=$(printf "\e[1;31m") \
                    LESS_TERMCAP_md=$(printf "\e[1;31m") \
                    LESS_TERMCAP_me=$(printf "\e[0m") \
                    LESS_TERMCAP_se=$(printf "\e[0m") \
                    LESS_TERMCAP_so=$(printf "\e[1;44;33m") \
                    LESS_TERMCAP_ue=$(printf "\e[0m") \
                    LESS_TERMCAP_us=$(printf "\e[1;32m") \
                    command man "$@"
                }

                zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
                zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
                zstyle ':completion:*' menu no
                zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
                zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

                ${lib.concatMapStringsSep "\n" (f: "source ${f}") shell-init}

                eval "$(command terminal-wakatime init)"

                # Edit command buffer in $EDITOR (Ctrl+X, Ctrl+E)
                autoload -Uz edit-command-line
                zle -N edit-command-line
                bindkey '^X^E' edit-command-line

                # Magic space - expand history expressions like !! or !$
                bindkey ' ' magic-space

                # Suffix aliases - open files by extension
                alias -s json=jless
                alias -s md=bat
                alias -s go='$EDITOR'
                alias -s rs='$EDITOR'
                alias -s txt=bat
                alias -s log=bat
                alias -s py='$EDITOR'
                alias -s js='$EDITOR'
                alias -s ts='$EDITOR'
                ${if pkgs.stdenv.isDarwin then "alias -s html=open" else ""}

                ${lib.optionalString pkgs.stdenv.isDarwin ''
                  # Use Apple's toolchain for native builds. nix's cc/clang
                  # don't wire in the macOS SDK, so cgo/cargo/cmake links fail
                  # with "library not found" (e.g. -lresolv). Apple's cc
                  # handles SDK, frameworks, and code signing natively.
                  # Respected by cgo ($CC), cargo, cmake, etc.
                  export CC=/usr/bin/cc
                  export CXX=/usr/bin/c++
                ''}

                # Global aliases
                alias -g NE='2>/dev/null'
                alias -g NO='>/dev/null'
                alias -g NUL='>/dev/null 2>&1'
                alias -g J='| jq'

                # Override source to handle .env files safely
                function source() {
                  if [[ "$1" == *.env ]]; then
                    [[ ! -f "$1" ]] && { echo "File not found: $1" >&2; return 1; }
                    while IFS= read -r line || [[ -n "$line" ]]; do
                      [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
                      if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)=(.*)$ ]]; then
                        export "''${match[1]}=''${match[2]}"
                      fi
                    done < "$1"
                  else
                    builtin source "$1"
                  fi
                }

                # OSC 52 clipboard (works over SSH)
                function osc52copy() {
                  local data=$(cat "$@" | base64 | tr -d '\n')
                  printf "\033]52;c;%s\a" "$data"
                }
                alias -g C='| osc52copy'

                # zmv - advanced batch rename/move
                autoload -Uz zmv
                alias zcp='zmv -C'
                alias zln='zmv -L'

                # Clear screen but keep current command buffer (Ctrl+X, Ctrl+L)
                function clear-screen-and-scrollback() {
                  echoti civis >"$TTY"
                  printf '%b' '\e[H\e[2J\e[3J' >"$TTY"
                  echoti cnorm >"$TTY"
                  zle redisplay
                }
                zle -N clear-screen-and-scrollback
                bindkey '^X^L' clear-screen-and-scrollback

                # Copy current command buffer to clipboard (Ctrl+X, Ctrl+C) - OSC 52 for SSH support
                function copy-buffer-to-clipboard() {
                  local data=$(echo -n "$BUFFER" | base64 | tr -d '\n')
                  printf "\033]52;c;%s\a" "$data"
                  zle -M "Copied to clipboard"
                }
                zle -N copy-buffer-to-clipboard
                bindkey '^X^C' copy-buffer-to-clipboard

                # Double-tap escape to prepend sudo (from oh-my-zsh sudo plugin)
                __sudo-replace-buffer() {
                  local old=$1 new=$2 space=''${2:+ }
                  if [[ $CURSOR -le ''${#old} ]]; then
                    BUFFER="''${new}''${space}''${BUFFER#$old }"
                    CURSOR=''${#new}
                  else
                    LBUFFER="''${new}''${space}''${LBUFFER#$old }"
                  fi
                }
                sudo-command-line() {
                  [[ -z $BUFFER ]] && LBUFFER="$(fc -ln -1)"
                  local WHITESPACE=""
                  if [[ ''${LBUFFER:0:1} = " " ]]; then
                    WHITESPACE=" "
                    LBUFFER="''${LBUFFER:1}"
                  fi
                  {
                    local EDITOR=''${SUDO_EDITOR:-''${VISUAL:-$EDITOR}}
                    if [[ -z "$EDITOR" ]]; then
                      case "$BUFFER" in
                        sudo\ -e\ *) __sudo-replace-buffer "sudo -e" "" ;;
                        sudo\ *) __sudo-replace-buffer "sudo" "" ;;
                        *) LBUFFER="sudo $LBUFFER" ;;
                      esac
                      return
                    fi
                    local cmd="''${''${(Az)BUFFER}[1]}"
                    local realcmd="''${''${(Az)aliases[$cmd]}[1]:-$cmd}"
                    local editorcmd="''${''${(Az)EDITOR}[1]}"
                    if [[ "$realcmd" = (\$EDITOR|$editorcmd|''${editorcmd:c}) \
                      || "''${realcmd:c}" = ($editorcmd|''${editorcmd:c}) ]] \
                      || builtin which -a "$realcmd" | command grep -Fx -q "$editorcmd"; then
                      __sudo-replace-buffer "$cmd" "sudo -e"
                      return
                    fi
                    case "$BUFFER" in
                      $editorcmd\ *) __sudo-replace-buffer "$editorcmd" "sudo -e" ;;
                      \$EDITOR\ *) __sudo-replace-buffer '$EDITOR' "sudo -e" ;;
                      sudo\ -e\ *) __sudo-replace-buffer "sudo -e" "$EDITOR" ;;
                      sudo\ *) __sudo-replace-buffer "sudo" "" ;;
                      *) LBUFFER="sudo $LBUFFER" ;;
                    esac
                  } always {
                    LBUFFER="''${WHITESPACE}''${LBUFFER}"
                    zle && zle redisplay
                  }
                }
                zle -N sudo-command-line
                bindkey -M emacs '\e\e' sudo-command-line
                bindkey -M vicmd '\e\e' sudo-command-line
                bindkey -M viins '\e\e' sudo-command-line

                # chpwd hooks
                autoload -Uz add-zsh-hook

                function auto_venv() {
                  if [[ -n "$VIRTUAL_ENV" && ! -f "$VIRTUAL_ENV/bin/activate" ]]; then
                    deactivate
                  fi
                  [[ -n "$VIRTUAL_ENV" ]] && return
                  local dir="$PWD"
                  while [[ "$dir" != "/" ]]; do
                    if [[ -f "$dir/.venv/bin/activate" ]]; then
                      source "$dir/.venv/bin/activate"
                      return
                    fi
                    dir="''${dir:h}"
                  done
                }

                function auto_nix() {
                  [[ -n "$IN_NIX_SHELL" ]] && return
                  local dir="$PWD"
                  while [[ "$dir" != "/" ]]; do
                    if [[ -f "$dir/flake.nix" ]]; then
                      if [[ ! -f "$dir/.envrc" ]]; then
                        local arch
                        arch="$(nix eval --impure --expr 'builtins.currentSystem' 2>/dev/null | tr -d '"')"
                        if nix eval --json "$dir#devShells.$arch" \
                             --apply 'x: true' >/dev/null 2>&1; then
                          cat > "$dir/.envrc" <<'EOF'
        use flake
        EOF
                          command direnv allow "$dir" >/dev/null 2>&1
                        fi
                      fi
                      if [[ -f "$dir/.envrc" ]]; then
                        command direnv reload >/dev/null 2>&1
                      fi
                      return
                    fi
                    dir="''${dir:h}"
                  done
                }

                add-zsh-hook chpwd auto_venv
                add-zsh-hook chpwd auto_nix

                # zsh-patina: Rust-based syntax highlighting (must be last)
                eval "$(${
                  inputs.zsh-patina.packages.${pkgs.stdenv.hostPlatform.system}.default
                }/bin/zsh-patina activate)"

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

      oh-my-zsh.enable = false;

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
      enableZshIntegration = false;
    };
    programs.direnv = {
      enable = true;
      enableZshIntegration = false;
      nix-direnv.enable = true;
    };
    programs.fzf = {
      enable = true;
      enableZshIntegration = false;
      colors = {
        bg = lib.mkForce "";
      };
    };
    programs.atuin = {
      enable = true;
      enableZshIntegration = true;
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
      shellWrapperName = "yy";
    };

    home.packages = with pkgs; [
      tangled-setup
      ghrpc
      assh
      hackatime-summary
      now
      ghostty-setup
      pkgs.unstable.wakatime-cli
      inputs.terminal-wakatime.packages.${pkgs.stdenv.hostPlatform.system}.default
      inputs.zsh-patina.packages.${pkgs.stdenv.hostPlatform.system}.default
      pkgs.gitstatus
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
      fastfetch
      glow
      tree
      jless
    ];

    home.sessionPath = [
      "$HOME/go/bin"
      "$HOME/.local/bin"
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      "/opt/homebrew/bin"
      "/opt/homebrew/sbin"
      "/opt/local/bin"
      "/opt/local/sbin"
      "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"
    ];

    home.sessionVariables = {
      GITSTATUS_DIR = "${pkgs.gitstatus}/share/gitstatus";
      CRUSH_ALGORITHMIC_COMPACT = "1";

      # Colourful man pages: -c stops groff emitting its own escapes, col
      # strips the overstrike it uses for bold and underline, and bat
      # highlights what is left with the usual theme.
      MANROFFOPT = "-c";
      MANPAGER = "sh -c '${colBin} -bx | ${pkgs.bat}/bin/bat -l man -p --theme=ansi'";
    }
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
      HOMEBREW_PREFIX = "/opt/homebrew";
      HOMEBREW_CELLAR = "/opt/homebrew/Cellar";
      HOMEBREW_REPOSITORY = "/opt/homebrew";
      INFOPATH = "/opt/homebrew/share/info:\${INFOPATH:-}";
    };

    atelier.shell.git.enable = lib.mkDefault true;
    atelier.shell.jj.enable = lib.mkDefault true;
    atelier.shell.wut.enable = lib.mkDefault true;

    xdg.configFile."direnv/direnv.toml".text = ''
      [global]
      hide_env_diff = true
      warn_timeout = "10s"
    '';
  };
}

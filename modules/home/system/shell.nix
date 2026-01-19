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

  ghrpc = pkgs.writeShellScriptBin "ghrpc" ''
       set -euo pipefail

       # Defaults (configured by Nix)
       PLC_ID="${tangled.plcId}"
       GITHUB_USER="${tangled.githubUser}"
       KNOT_HOST="${tangled.knotHost}"
       TANGLED_DOMAIN="${tangled.domain}"
       BRANCH="${tangled.defaultBranch}"
       VISIBILITY="public"
       DESCRIPTION=""
       GITHUB=true
       TANGLED=true
       NAME=""

       usage() {
         cat <<EOF
    Usage: ghrpc [OPTIONS] [NAME]

    Create repositories on GitHub and/or Tangled.
    Remotes: origin → knot (tangled), github → GitHub

    Arguments:
      NAME                    Repository name (defaults to current directory name)

    Options:
      -d, --description STR   Repository description
      -p, --public            Make repository public (default)
      --private               Make repository private
      -g, --github-only       Only create on GitHub
      -t, --tangled-only      Only create on Tangled
      --no-github             Skip GitHub
      --no-tangled            Skip Tangled
      --plc ID                PLC ID (default: $PLC_ID)
      --domain DOMAIN         Tangled domain (default: $TANGLED_DOMAIN)
      -h, --help              Show this help
    EOF
         exit 0
       }

       while [[ $# -gt 0 ]]; do
         case "$1" in
           -h|--help) usage ;;
           -d|--description) DESCRIPTION="$2"; shift 2 ;;
           -p|--public) VISIBILITY="public"; shift ;;
           --private) VISIBILITY="private"; shift ;;
           -g|--github-only) TANGLED=false; shift ;;
           -t|--tangled-only) GITHUB=false; shift ;;
           --no-github) GITHUB=false; shift ;;
           --no-tangled) TANGLED=false; shift ;;
           --plc) PLC_ID="$2"; shift 2 ;;
           --domain) TANGLED_DOMAIN="$2"; shift 2 ;;
           -*) echo "Unknown option: $1" >&2; exit 1 ;;
           *) NAME="$1"; shift ;;
         esac
       done

       # Determine repo name
       if [[ -z "$NAME" ]]; then
         if ${pkgs.git}/bin/git rev-parse --is-inside-work-tree &>/dev/null; then
           NAME=$(basename "$(${pkgs.git}/bin/git rev-parse --show-toplevel)")
         else
           NAME=$(${pkgs.gum}/bin/gum input --placeholder "my-repo" --header "Repository name")
           if [[ -z "$NAME" ]]; then
             ${pkgs.gum}/bin/gum style --foreground 196 "Error: Repository name is required"
             exit 1
           fi
         fi
       fi

       # Prompt for description if not provided
       if [[ -z "$DESCRIPTION" ]]; then
         DESCRIPTION=$(${pkgs.gum}/bin/gum input --placeholder "A cool project" --header "Description (optional)")
       fi

       # Choose visibility if not set via flags
       if [[ "$VISIBILITY" == "public" ]] && [[ -t 0 ]]; then
         VISIBILITY=$(${pkgs.gum}/bin/gum choose --header "Visibility" "public" "private")
       fi

       # Choose where to create
       if [[ "$GITHUB" == true ]] && [[ "$TANGLED" == true ]] && [[ -t 0 ]]; then
         TARGET=$(${pkgs.gum}/bin/gum choose --header "Create on" "Both GitHub and Tangled" "GitHub only" "Tangled only")
         case "$TARGET" in
           "GitHub only") TANGLED=false ;;
           "Tangled only") GITHUB=false ;;
         esac
       fi

       ${pkgs.gum}/bin/gum style --foreground 212 --bold "Creating repository: $NAME"

       # Create on Tangled
       if [[ "$TANGLED" == true ]]; then
         tangled_cookie=""
         if [[ -f "/run/agenix/tangled-session" ]]; then
           tangled_cookie=$(cat /run/agenix/tangled-session)
         fi

         if [[ -z "$tangled_cookie" ]]; then
           ${pkgs.gum}/bin/gum style --foreground 214 "Warning: No tangled session cookie found at /run/agenix/tangled-session"
         else
           encoded_desc=$(printf '%s' "$DESCRIPTION" | ${pkgs.gnused}/bin/sed 's/ /%20/g; s/!/%21/g; s/"/%22/g; s/#/%23/g; s/\$/%24/g; s/&/%26/g; s/'"'"'/%27/g; s/(/%28/g; s/)/%29/g; s/\*/%2A/g; s/+/%2B/g; s/,/%2C/g; s/\//%2F/g; s/:/%3A/g; s/;/%3B/g; s/=/%3D/g; s/?/%3F/g; s/@/%40/g; s/\[/%5B/g; s/\]/%5D/g')

           response=$(${pkgs.curl}/bin/curl -s 'https://tangled.org/repo/new' \
             -H 'Accept: */*' \
             -H 'Content-Type: application/x-www-form-urlencoded' \
             -b "appview-session-v2=$tangled_cookie" \
             -H 'HX-Request: true' \
             -H 'Origin: https://tangled.org' \
             --data-raw "name=$NAME&description=$encoded_desc&branch=$BRANCH&domain=$TANGLED_DOMAIN")

           if echo "$response" | grep -qi "error\|failed"; then
             ${pkgs.gum}/bin/gum style --foreground 196 "✗ Failed to create Tangled repository"
           else
             ${pkgs.gum}/bin/gum style --foreground 35 "✓ Tangled: https://tangled.org/$TANGLED_DOMAIN/$NAME"
           fi
         fi
       fi

       # Create on GitHub
       if [[ "$GITHUB" == true ]]; then
         gh_flags="--$VISIBILITY"
         [[ -n "$DESCRIPTION" ]] && gh_flags="$gh_flags --description \"$DESCRIPTION\""

         if ${pkgs.git}/bin/git rev-parse --is-inside-work-tree &>/dev/null; then
           if eval "${pkgs.gh}/bin/gh repo create \"$NAME\" $gh_flags --source=. --push --remote=github 2>/dev/null"; then
             ${pkgs.gum}/bin/gum style --foreground 35 "✓ GitHub: https://github.com/$GITHUB_USER/$NAME"
           else
             ${pkgs.gum}/bin/gum style --foreground 196 "✗ Failed to create GitHub repository"
           fi
         else
           if eval "${pkgs.gh}/bin/gh repo create \"$NAME\" $gh_flags --clone 2>/dev/null"; then
             ${pkgs.gum}/bin/gum style --foreground 35 "✓ GitHub: created and cloned $NAME"
             cd "$NAME"
           else
             ${pkgs.gum}/bin/gum style --foreground 196 "✗ Failed to create GitHub repository"
           fi
         fi
       fi

       # Configure remotes: origin → knot, github → GitHub
       if ${pkgs.git}/bin/git rev-parse --is-inside-work-tree &>/dev/null; then
         knot_url="git@$KNOT_HOST:$PLC_ID/$NAME"
         github_url="git@github.com:$GITHUB_USER/$NAME.git"

         # Set origin to knot
         if [[ "$TANGLED" == true ]]; then
           if ${pkgs.git}/bin/git remote get-url origin &>/dev/null; then
             current_origin=$(${pkgs.git}/bin/git remote get-url origin)
             if [[ "$current_origin" != *"$KNOT_HOST"* ]]; then
               ${pkgs.git}/bin/git remote set-url origin "$knot_url"
             fi
           else
             ${pkgs.git}/bin/git remote add origin "$knot_url"
           fi
         fi

         # Set github remote
         if [[ "$GITHUB" == true ]]; then
           ${pkgs.git}/bin/git remote add github "$github_url" 2>/dev/null || \
             ${pkgs.git}/bin/git remote set-url github "$github_url"
         fi

         # Set default push to origin (knot)
         ${pkgs.git}/bin/git config branch.$BRANCH.remote origin 2>/dev/null || true

         echo
         ${pkgs.git}/bin/git remote -v
       fi
  '';

in
{
  options.atelier.shell = {
    enable = lib.mkEnableOption "Custom shell config";

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
        default = "knot.dunkirk.sh";
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
                template = "{{if not .Detached}}{{ .HEAD }}{{else}}@{{ printf \"%.7s\" .Commit.Sha }}{{end}}{{ if .Staging.Changed }} ({{ .Staging.String }}){{ end }}{{ if .Working.Changed }}*{{ end }}{{ if .BranchStatus }}<cyan> {{ .BranchStatus }}</>{{ end }}";
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

                # Global aliases
                alias -g NE='2>/dev/null'
                alias -g NO='>/dev/null'
                alias -g NUL='>/dev/null 2>&1'
                alias -g J='| jq'

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
                        cat > "$dir/.envrc" <<'EOF'
        use flake
        EOF
                        command direnv allow "$dir" >/dev/null 2>&1
                      fi
                      command direnv reload >/dev/null 2>&1
                      return
                    fi
                    dir="''${dir:h}"
                  done
                }

                add-zsh-hook chpwd auto_venv
                add-zsh-hook chpwd auto_nix
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
      ghrpc
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
      tree
      jless
    ];

    home.sessionPath = [
      "$HOME/go/bin"
    ];

    atelier.shell.git.enable = lib.mkDefault true;
  };
}

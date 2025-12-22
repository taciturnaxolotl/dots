{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.atelier.apps.anthropic-manager;

  anthropicManagerScript = pkgs.writeShellScript "anthropic-manager" ''
        # Manage Anthropic OAuth credential profiles
        # Implements the same functionality as anthropic-api-key but with profile management
        
        set -uo pipefail
        
        CONFIG_DIR="''${ANTHROPIC_CONFIG_DIR:-$HOME/.config/crush}"
        CLIENT_ID="9d1c250a-e61b-44d9-88ed-5944d1962f5e"
        
        # Utilities
        base64url() {
          ${pkgs.coreutils}/bin/base64 -w0 | ${pkgs.gnused}/bin/sed 's/=//g; s/+/-/g; s/\//_/g'
        }
        
        sha256() {
          echo -n "$1" | ${pkgs.openssl}/bin/openssl dgst -binary -sha256
        }
        
        pkce_pair() {
          verifier=$(${pkgs.openssl}/bin/openssl rand 32 | base64url)
          challenge=$(printf '%s' "$verifier" | ${pkgs.openssl}/bin/openssl dgst -binary -sha256 | base64url)
          echo "$verifier $challenge"
        }
        
        authorize_url() {
          local challenge="$1"
          local state="$2"
          echo "https://claude.ai/oauth/authorize?response_type=code&client_id=$CLIENT_ID&redirect_uri=https://console.anthropic.com/oauth/code/callback&scope=org:create_api_key+user:profile+user:inference+user:sessions:claude_code&code_challenge=$challenge&code_challenge_method=S256&state=$state"
        }
        
        clean_pasted_code() {
          local input="$1"
          input="''${input#code:}"
          input="''${input#code=}"
          input="''${input#\"}"
          input="''${input%\"}"
          input="''${input#\'}"
          input="''${input%\'}"
          input="''${input#\`}"
          input="''${input%\`}"
          echo "$input" | ${pkgs.gnused}/bin/sed -E 's/[^A-Za-z0-9._~#-]//g'
        }
        
        exchange_code() {
          local code="$1"
          local verifier="$2"
          local cleaned
          cleaned=$(clean_pasted_code "$code")
          local pure="''${cleaned%%#*}"
          local state="''${cleaned#*#}"
          [[ "$state" == "$pure" ]] && state=""
          
          ${pkgs.curl}/bin/curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "User-Agent: anthropic-manager/1.0" \
            -d "$(${pkgs.jq}/bin/jq -n \
              --arg code "$pure" \
              --arg state "$state" \
              --arg verifier "$verifier" \
              '{
                code: $code,
                state: $state,
                grant_type: "authorization_code",
                client_id: "9d1c250a-e61b-44d9-88ed-5944d1962f5e",
                redirect_uri: "https://console.anthropic.com/oauth/code/callback",
                code_verifier: $verifier
              }')" \
            "https://console.anthropic.com/v1/oauth/token"
        }
        
        exchange_refresh() {
          local refresh_token="$1"
          ${pkgs.curl}/bin/curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "User-Agent: anthropic-manager/1.0" \
            -d "$(${pkgs.jq}/bin/jq -n \
              --arg refresh "$refresh_token" \
              '{
                grant_type: "refresh_token",
                refresh_token: $refresh,
                client_id: "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
              }')" \
            "https://console.anthropic.com/v1/oauth/token"
        }
        
        save_tokens() {
          local profile_dir="$1"
          local access_token="$2"
          local refresh_token="$3"
          local expires_at="$4"
          
          mkdir -p "$profile_dir"
          echo -n "$access_token" > "$profile_dir/bearer_token"
          echo -n "$refresh_token" > "$profile_dir/refresh_token"
          echo -n "$expires_at" > "$profile_dir/bearer_token.expires"
          chmod 600 "$profile_dir/bearer_token" "$profile_dir/refresh_token" "$profile_dir/bearer_token.expires"
        }
        
        load_tokens() {
          local profile_dir="$1"
          [[ -f "$profile_dir/bearer_token" ]] || return 1
          [[ -f "$profile_dir/refresh_token" ]] || return 1
          [[ -f "$profile_dir/bearer_token.expires" ]] || return 1
          
          cat "$profile_dir/bearer_token"
          cat "$profile_dir/refresh_token"
          cat "$profile_dir/bearer_token.expires"
          return 0
        }
        
        get_token() {
          local profile_dir="$1"
          local print_token="''${2:-true}"
          
          if ! load_tokens "$profile_dir" >/dev/null 2>&1; then
            return 1
          fi
          
          local bearer refresh expires
          read -r bearer < "$profile_dir/bearer_token"
          read -r refresh < "$profile_dir/refresh_token"
          read -r expires < "$profile_dir/bearer_token.expires"
          
          local now
          now=$(date +%s)
          
          # If token valid for more than 60s, return it
          if [[ $now -lt $((expires - 60)) ]]; then
            [[ "$print_token" == "true" ]] && echo "$bearer"
            return 0
          fi
          
          # Try to refresh
          local response
          response=$(exchange_refresh "$refresh")
          
          if ! echo "$response" | ${pkgs.jq}/bin/jq -e '.access_token' >/dev/null 2>&1; then
            return 1
          fi
          
          local new_access new_refresh new_expires_in
          new_access=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.access_token')
          new_refresh=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.refresh_token // empty')
          new_expires_in=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.expires_in')
          
          [[ -z "$new_refresh" ]] && new_refresh="$refresh"
          local new_expires=$((now + new_expires_in))
          
          save_tokens "$profile_dir" "$new_access" "$new_refresh" "$new_expires"
          [[ "$print_token" == "true" ]] && echo "$new_access"
          return 0
        }
        
        oauth_flow() {
          local profile_dir="$1"
          
          ${pkgs.gum}/bin/gum style --foreground 212 "Starting OAuth flow..."
          echo
          
          read -r verifier challenge < <(pkce_pair)
          local state
          state=$(${pkgs.openssl}/bin/openssl rand -base64 32 | ${pkgs.gnused}/bin/sed 's/[^A-Za-z0-9]//g')
          local auth_url
          auth_url=$(authorize_url "$challenge" "$state")
          
          ${pkgs.gum}/bin/gum style --foreground 35 "Opening browser for authorization..."
          ${pkgs.gum}/bin/gum style --foreground 117 "$auth_url"
          echo
          
          if command -v ${pkgs.xdg-utils}/bin/xdg-open &>/dev/null; then
            ${pkgs.xdg-utils}/bin/xdg-open "$auth_url" 2>/dev/null &
          elif command -v open &>/dev/null; then
            open "$auth_url" 2>/dev/null &
          fi
          
          local code
          code=$(${pkgs.gum}/bin/gum input --placeholder "Paste the authorization code from Anthropic" --prompt "Code: ")
          
          if [[ -z "$code" ]]; then
            ${pkgs.gum}/bin/gum style --foreground 196 "No code provided"
            return 1
          fi
          
          ${pkgs.gum}/bin/gum style --foreground 212 "Exchanging code for tokens..."
          
          local response
          response=$(exchange_code "$code" "$verifier")
          
          if ! echo "$response" | ${pkgs.jq}/bin/jq -e '.access_token' >/dev/null 2>&1; then
            ${pkgs.gum}/bin/gum style --foreground 196 "Failed to exchange code"
            echo "$response" | ${pkgs.jq}/bin/jq '.' 2>&1 || echo "$response"
            return 1
          fi
          
          local access_token refresh_token expires_in
          access_token=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.access_token')
          refresh_token=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.refresh_token')
          expires_in=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.expires_in')
          
          local expires_at
          expires_at=$(($(date +%s) + expires_in))
          
          save_tokens "$profile_dir" "$access_token" "$refresh_token" "$expires_at"
          ${pkgs.gum}/bin/gum style --foreground 35 "✓ Authenticated successfully"
          return 0
        }
        
        list_profiles() {
          ${pkgs.gum}/bin/gum style --bold --foreground 212 "Available Anthropic profiles:"
          echo
          
          local current_profile=""
          if [[ -L "$CONFIG_DIR/anthropic" ]]; then
            current_profile=$(basename "$(readlink "$CONFIG_DIR/anthropic")" | ${pkgs.gnused}/bin/sed 's/^anthropic\.//')
          fi
          
          local found_any=false
          for profile_dir in "$CONFIG_DIR"/anthropic.*; do
            if [[ -d "$profile_dir" ]]; then
              found_any=true
              local profile_name
              profile_name=$(basename "$profile_dir" | ${pkgs.gnused}/bin/sed 's/^anthropic\.//')
              
              local status=""
              if get_token "$profile_dir" false 2>/dev/null; then
                local expires
                read -r expires < "$profile_dir/bearer_token.expires"
                local now
                now=$(date +%s)
                if [[ $now -lt $expires ]]; then
                  status=" (valid)"
                else
                  status=" (expired)"
                fi
              else
                status=" (invalid)"
              fi
              
              if [[ "$profile_name" == "$current_profile" ]]; then
                ${pkgs.gum}/bin/gum style --foreground 35 "  ✓ $profile_name$status (active)"
              else
                echo "    $profile_name$status"
              fi
            fi
          done
          
          if [[ "$found_any" == "false" ]]; then
            ${pkgs.gum}/bin/gum style --foreground 214 "No profiles found. Use 'anthropic-manager --init <name>' to create one."
          fi
        }
        
        show_current() {
          if [[ -L "$CONFIG_DIR/anthropic" ]]; then
            local current
            current=$(basename "$(readlink "$CONFIG_DIR/anthropic")" | ${pkgs.gnused}/bin/sed 's/^anthropic\.//')
            ${pkgs.gum}/bin/gum style --foreground 35 "Current profile: $current"
          else
            ${pkgs.gum}/bin/gum style --foreground 214 "No active profile"
          fi
        }
        
        init_profile() {
          local profile="$1"
          
          if [[ -z "$profile" ]]; then
            profile=$(${pkgs.gum}/bin/gum input --placeholder "Profile name (e.g., work, personal)" --prompt "Profile name: ")
            if [[ -z "$profile" ]]; then
              ${pkgs.gum}/bin/gum style --foreground 196 "No profile name provided"
              exit 1
            fi
          fi
          
          local profile_dir="$CONFIG_DIR/anthropic.$profile"
          
          if [[ -d "$profile_dir" ]]; then
            ${pkgs.gum}/bin/gum style --foreground 214 "Profile '$profile' already exists"
            if ${pkgs.gum}/bin/gum confirm "Re-authenticate?"; then
              rm -rf "$profile_dir"
            else
              exit 1
            fi
          fi
          
          if ! oauth_flow "$profile_dir"; then
            rm -rf "$profile_dir"
            exit 1
          fi
          
          # Ask to set as active
          if [[ ! -L "$CONFIG_DIR/anthropic" ]] || ${pkgs.gum}/bin/gum confirm "Set '$profile' as active profile?"; then
            [[ -L "$CONFIG_DIR/anthropic" ]] && rm "$CONFIG_DIR/anthropic"
            ln -sf "anthropic.$profile" "$CONFIG_DIR/anthropic"
            ${pkgs.gum}/bin/gum style --foreground 35 "✓ Set as active profile"
          fi
        }
        
        delete_profile() {
          local target="$1"
          
          if [[ -z "$target" ]]; then
            # Interactive selection
            local profiles=()
            for profile_dir in "$CONFIG_DIR"/anthropic.*; do
              if [[ -d "$profile_dir" ]]; then
                profiles+=("$(basename "$profile_dir" | ${pkgs.gnused}/bin/sed 's/^anthropic\.//')")
              fi
            done
            
            if [[ ''${#profiles[@]} -eq 0 ]]; then
              ${pkgs.gum}/bin/gum style --foreground 196 "No profiles found"
              exit 1
            fi
            
            target=$(printf '%s\n' "''${profiles[@]}" | ${pkgs.gum}/bin/gum choose --header "Select profile to delete:")
            [[ -z "$target" ]] && exit 0
          fi
          
          local target_dir="$CONFIG_DIR/anthropic.$target"
          if [[ ! -d "$target_dir" ]]; then
            ${pkgs.gum}/bin/gum style --foreground 196 "Profile '$target' does not exist"
            exit 1
          fi
          
          if ! ${pkgs.gum}/bin/gum confirm "Delete profile '$target'?"; then
            exit 0
          fi
          
          # Check if this is the active profile
          if [[ -L "$CONFIG_DIR/anthropic" ]]; then
            local current
            current=$(basename "$(readlink "$CONFIG_DIR/anthropic")" | ${pkgs.gnused}/bin/sed 's/^anthropic\.//')
            if [[ "$current" == "$target" ]]; then
              rm "$CONFIG_DIR/anthropic"
              ${pkgs.gum}/bin/gum style --foreground 214 "Unlinked active profile"
            fi
          fi
          
          rm -rf "$target_dir"
          ${pkgs.gum}/bin/gum style --foreground 35 "✓ Deleted profile '$target'"
        }
        
        swap_profile() {
          local target="$1"
          
          if [[ -n "$target" ]]; then
            local target_dir="$CONFIG_DIR/anthropic.$target"
            if [[ ! -d "$target_dir" ]]; then
              ${pkgs.gum}/bin/gum style --foreground 196 "Profile '$target' does not exist"
              echo
              list_profiles
              exit 1
            fi
            
            [[ -L "$CONFIG_DIR/anthropic" ]] && rm "$CONFIG_DIR/anthropic"
            ln -sf "anthropic.$target" "$CONFIG_DIR/anthropic"
            ${pkgs.gum}/bin/gum style --foreground 35 "✓ Switched to profile '$target'"
            exit 0
          fi
          
          # Interactive selection
          local profiles=()
          for profile_dir in "$CONFIG_DIR"/anthropic.*; do
            if [[ -d "$profile_dir" ]]; then
              profiles+=("$(basename "$profile_dir" | ${pkgs.gnused}/bin/sed 's/^anthropic\.//')")
            fi
          done
          
          if [[ ''${#profiles[@]} -eq 0 ]]; then
            ${pkgs.gum}/bin/gum style --foreground 196 "No profiles found"
            ${pkgs.gum}/bin/gum style --foreground 214 "Use 'anthropic-manager --init <name>' to create one"
            exit 1
          fi
          
          local selected
          selected=$(printf '%s\n' "''${profiles[@]}" | ${pkgs.gum}/bin/gum choose --header "Select profile:")
          
          if [[ -n "$selected" ]]; then
            [[ -L "$CONFIG_DIR/anthropic" ]] && rm "$CONFIG_DIR/anthropic"
            ln -sf "anthropic.$selected" "$CONFIG_DIR/anthropic"
            ${pkgs.gum}/bin/gum style --foreground 35 "✓ Switched to profile '$selected'"
          fi
        }
        
        print_token() {
          if [[ ! -L "$CONFIG_DIR/anthropic" ]]; then
            echo "Error: No active profile" >&2
            exit 1
          fi
          
          local profile_dir
          profile_dir=$(readlink -f "$CONFIG_DIR/anthropic")
          
          if ! get_token "$profile_dir" true 2>/dev/null; then
            echo "Error: Token invalid or expired" >&2
            exit 1
          fi
        }
        
        interactive_menu() {
          echo
          ${pkgs.gum}/bin/gum style --bold --foreground 212 "Anthropic Profile Manager"
          echo
          
          local current_profile=""
          if [[ -L "$CONFIG_DIR/anthropic" ]]; then
            current_profile=$(basename "$(readlink "$CONFIG_DIR/anthropic")" | ${pkgs.gnused}/bin/sed 's/^anthropic\.//')
            ${pkgs.gum}/bin/gum style --foreground 117 "Active: $current_profile"
          else
            ${pkgs.gum}/bin/gum style --foreground 214 "No active profile"
          fi
          
          echo
          
          local choice
          choice=$(${pkgs.gum}/bin/gum choose \
            "Switch profile" \
            "Create new profile" \
            "Delete profile" \
            "List all profiles" \
            "Get current token")
          
          case "$choice" in
            "Switch profile")
              swap_profile ""
              ;;
            "Create new profile")
              init_profile ""
              ;;
            "Delete profile")
              echo
              delete_profile ""
              ;;
            "List all profiles")
              echo
              list_profiles
              ;;
            "Get current token")
              echo
              print_token
              ;;
          esac
        }
        
        # Main
        mkdir -p "$CONFIG_DIR"
        
        case "''${1:-}" in
          --init|-i)
            init_profile "''${2:-}"
            ;;
          --list|-l)
            list_profiles
            ;;
          --current|-c)
            show_current
            ;;
          --token|-t|token)
            print_token
            ;;
          --swap|-s|swap)
            swap_profile "''${2:-}"
            ;;
          --delete|-d|delete)
            delete_profile "''${2:-}"
            ;;
          --help|-h|help)
            ${pkgs.gum}/bin/gum style --bold --foreground 212 "anthropic-manager - Manage Anthropic OAuth profiles"
            echo
            echo "Usage:"
            echo "  anthropic-manager                     Interactive menu"
            echo "  anthropic-manager --init [profile]    Initialize/create a new profile"
            echo "  anthropic-manager --swap [profile]    Switch to a profile (interactive if no profile given)"
            echo "  anthropic-manager --delete [profile]  Delete a profile (interactive if no profile given)"
            echo "  anthropic-manager --token             Print current bearer token (refresh if needed)"
            echo "  anthropic-manager --list              List all profiles with status"
            echo "  anthropic-manager --current           Show current active profile"
            echo "  anthropic-manager --help              Show this help"
            echo
            echo "Examples:"
            echo "  anthropic-manager                     Open interactive menu"
            echo "  anthropic-manager --init work         Create 'work' profile"
            echo "  anthropic-manager --swap work         Switch to 'work' profile"
            echo "  anthropic-manager --delete work       Delete 'work' profile"
            echo "  anthropic-manager --token             Get current bearer token"
            ;;
          "")
            # No args - check if interactive
            if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
              echo "Error: anthropic-manager requires an interactive terminal when called without arguments" >&2
              exit 1
            fi
            interactive_menu
            ;;
          *)
            ${pkgs.gum}/bin/gum style --foreground 196 "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        esac
  '';

  anthropicManager = pkgs.stdenv.mkDerivation {
    pname = "anthropic-manager";
    version = "1.0";

    dontUnpack = true;

    nativeBuildInputs = with pkgs; [ pandoc installShellFiles ];

    manPageSrc = ./anthropic-manager.1.md;
    bashCompletionSrc = ./completions/anthropic-manager.bash;
    zshCompletionSrc = ./completions/anthropic-manager.zsh;
    fishCompletionSrc = ./completions/anthropic-manager.fish;

    buildPhase = ''
      # Convert markdown man page to man format
      ${pkgs.pandoc}/bin/pandoc -s -t man $manPageSrc -o anthropic-manager.1
    '';

    installPhase = ''
      mkdir -p $out/bin

      # Install binary
      cp ${anthropicManagerScript} $out/bin/anthropic-manager
      chmod +x $out/bin/anthropic-manager

      # Install man page
      installManPage anthropic-manager.1

      # Install completions
      installShellCompletion --bash --name anthropic-manager $bashCompletionSrc
      installShellCompletion --zsh --name _anthropic-manager $zshCompletionSrc
      installShellCompletion --fish --name anthropic-manager.fish $fishCompletionSrc
    '';

    meta = with lib; {
      description = "Anthropic OAuth profile manager";
      homepage = "https://github.com/taciturnaxolotl/dots";
      license = licenses.mit;
      maintainers = [ ];
    };
  };
in
{
  options.atelier.apps.anthropic-manager.enable = lib.mkEnableOption "Enable anthropic-manager";
  
  config = lib.mkIf cfg.enable {
    home.packages = [
      anthropicManager
    ];
  };
}

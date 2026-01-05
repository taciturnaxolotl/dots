{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.atelier.pbnj;

  hostArg = if cfg.host != null then ''"${cfg.host}"'' else "\"\"";
  authKeyFileArg = if cfg.authKeyFile != null then ''"${cfg.authKeyFile}"'' else "\"\"";

  # Platform-specific clipboard commands
  clipboardCopy = if pkgs.stdenv.isDarwin then
    "printf '%s' \"$url\" | pbcopy 2>/dev/null"
  else
    "echo \"$url\" | ${pkgs.wl-clipboard}/bin/wl-copy 2>/dev/null || echo \"$url\" | ${pkgs.xclip}/bin/xclip -selection clipboard 2>/dev/null";

  pbnjScript = pkgs.writeShellScript "pbnj" ''
    set -e
    set -o pipefail

    CONFIG_FILE="''${PBNJ_CONFIG:-$HOME/.pbnj.json}"
    CONFIGURED_HOST=${hostArg}
    CONFIGURED_AUTH_KEY_FILE=${authKeyFileArg}
    
    # Load config
    load_config() {
      # Priority: env var > nix config > config file
      if [ -n "$PBNJ_HOST" ]; then
        HOST="$PBNJ_HOST"
      elif [ -n "$CONFIGURED_HOST" ]; then
        HOST="$CONFIGURED_HOST"
      elif [ -f "$CONFIG_FILE" ]; then
        HOST=$(${pkgs.jq}/bin/jq -r '.host // empty' "$CONFIG_FILE" 2>/dev/null)
      fi
      
      if [ -n "$PBNJ_AUTH_KEY" ]; then
        AUTH_KEY="$PBNJ_AUTH_KEY"
      elif [ -n "$CONFIGURED_AUTH_KEY_FILE" ] && [ -f "$CONFIGURED_AUTH_KEY_FILE" ]; then
        AUTH_KEY=$(${pkgs.coreutils}/bin/cat "$CONFIGURED_AUTH_KEY_FILE")
      elif [ -f "$CONFIG_FILE" ]; then
        AUTH_KEY=$(${pkgs.jq}/bin/jq -r '.auth_key // empty' "$CONFIG_FILE" 2>/dev/null)
      fi
    }
    
    check_config() {
      if [ -z "$HOST" ] || [ -z "$AUTH_KEY" ]; then
        ${pkgs.gum}/bin/gum style --foreground 196 "Not configured. Run 'pbnj init' first."
        exit 1
      fi
    }
    
    # Detect language from filename
    detect_language() {
      local filename="$1"
      local ext="''${filename##*.}"
      case "$ext" in
        go) echo "go" ;;
        py) echo "python" ;;
        js) echo "javascript" ;;
        ts) echo "typescript" ;;
        rs) echo "rust" ;;
        rb) echo "ruby" ;;
        java) echo "java" ;;
        c|h) echo "c" ;;
        cpp|hpp|cc) echo "cpp" ;;
        cs) echo "csharp" ;;
        php) echo "php" ;;
        sh|bash|zsh) echo "bash" ;;
        html) echo "html" ;;
        css) echo "css" ;;
        json) echo "json" ;;
        yaml|yml) echo "yaml" ;;
        xml) echo "xml" ;;
        sql) echo "sql" ;;
        md) echo "markdown" ;;
        swift) echo "swift" ;;
        kt) echo "kotlin" ;;
        scala) echo "scala" ;;
        nix) echo "nix" ;;
        lua) echo "lua" ;;
        vim) echo "vim" ;;
        toml) echo "toml" ;;
        *) echo "" ;;
      esac
    }
    
    # Format age
    format_age() {
      local created="$1"
      local now=$(${pkgs.coreutils}/bin/date +%s)
      local then=$(${pkgs.coreutils}/bin/date -d "$created" +%s 2>/dev/null || echo "$now")
      local diff=$((now - then))
      
      if [ $diff -lt 60 ]; then
        echo "just now"
      elif [ $diff -lt 3600 ]; then
        echo "$((diff / 60))m ago"
      elif [ $diff -lt 86400 ]; then
        echo "$((diff / 3600))h ago"
      elif [ $diff -lt 604800 ]; then
        echo "$((diff / 86400))d ago"
      else
        echo "$((diff / 604800))w ago"
      fi
    }
    
    # Commands
    cmd_init() {
      ${pkgs.gum}/bin/gum style --bold --foreground 212 "Configure pbnj"
      echo
      
      host=$(${pkgs.gum}/bin/gum input --placeholder "https://paste.example.com" --prompt "Host URL: ")
      if [ -z "$host" ]; then
        ${pkgs.gum}/bin/gum style --foreground 196 "No host provided"
        exit 1
      fi
      
      auth_key=$(${pkgs.gum}/bin/gum input --placeholder "your-auth-key" --prompt "Auth Key: " --password)
      if [ -z "$auth_key" ]; then
        ${pkgs.gum}/bin/gum style --foreground 196 "No auth key provided"
        exit 1
      fi
      
      # Remove trailing slash
      host="''${host%/}"
      
      echo "{\"host\": \"$host\", \"auth_key\": \"$auth_key\"}" > "$CONFIG_FILE"
      chmod 600 "$CONFIG_FILE"
      
      ${pkgs.gum}/bin/gum style --foreground 35 "✓ Configuration saved to $CONFIG_FILE"
    }
    
    cmd_config() {
      load_config
      
      if [ -z "$HOST" ] || [ -z "$AUTH_KEY" ]; then
        ${pkgs.gum}/bin/gum style --foreground 117 "Not configured. Run 'pbnj init' first."
        exit 0
      fi
      
      ${pkgs.gum}/bin/gum style --bold --foreground 212 "pbnj config"
      echo
      echo "  Host: $HOST"
      # Mask auth key
      masked="''${AUTH_KEY:0:4}...''${AUTH_KEY: -4}"
      echo "  Auth: $masked"
    }
    
    cmd_list() {
      load_config
      check_config
      
      local limit="''${1:-10}"
      
      response=$(${pkgs.curl}/bin/curl -s -f -X GET \
        -H "Authorization: Bearer $AUTH_KEY" \
        "$HOST/api?limit=$limit" 2>&1) || {
        ${pkgs.gum}/bin/gum style --foreground 196 "Failed to fetch pastes"
        exit 1
      }
      
      count=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.pastes | length')
      
      if [ "$count" = "0" ] || [ -z "$count" ]; then
        ${pkgs.gum}/bin/gum style --foreground 117 "No pastes found."
        exit 0
      fi
      
      ${pkgs.gum}/bin/gum style --bold --foreground 212 "Recent pastes"
      echo
      
      echo "$response" | ${pkgs.jq}/bin/jq -r '.pastes[] | "\(.id)|\(.language // "-")|\(.created_at // "-")|\(.filename // "-")"' | while IFS='|' read -r id lang created filename; do
        age=$(format_age "$created")
        printf "  %-24s  %-10s  %-10s  %s\n" "$id" "$lang" "$age" "$filename"
      done
      
      echo
      ${pkgs.gum}/bin/gum style --foreground 117 "Select paste to copy URL:"
      
      selected=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.pastes[].id' | ${pkgs.gum}/bin/gum choose --no-limit=false)
      
      if [ -n "$selected" ]; then
        url="$HOST/$selected"
        ${clipboardCopy} || true
        ${pkgs.gum}/bin/gum style --foreground 35 "✓ Copied: $url"
      fi
    }
    
    cmd_delete() {
      load_config
      check_config
      
      local id="$1"
      
      if [ -z "$id" ]; then
        ${pkgs.gum}/bin/gum style --foreground 196 "Usage: pbnj delete <id>"
        exit 1
      fi
      
      if ! ${pkgs.gum}/bin/gum confirm "Delete paste $id?"; then
        ${pkgs.gum}/bin/gum style --foreground 117 "Cancelled."
        exit 0
      fi
      
      ${pkgs.curl}/bin/curl -s -f -X DELETE \
        -H "Authorization: Bearer $AUTH_KEY" \
        "$HOST/api/$id" >/dev/null || {
        ${pkgs.gum}/bin/gum style --foreground 196 "Failed to delete paste"
        exit 1
      }
      
      ${pkgs.gum}/bin/gum style --foreground 35 "✓ Deleted"
    }
    
    cmd_delete_all() {
      load_config
      check_config
      
      if ! ${pkgs.gum}/bin/gum confirm "Delete ALL pastes? This cannot be undone."; then
        ${pkgs.gum}/bin/gum style --foreground 117 "Cancelled."
        exit 0
      fi
      
      ${pkgs.curl}/bin/curl -s -f -X DELETE \
        -H "Authorization: Bearer $AUTH_KEY" \
        "$HOST/api" >/dev/null || {
        ${pkgs.gum}/bin/gum style --foreground 196 "Failed to delete pastes"
        exit 1
      }
      
      ${pkgs.gum}/bin/gum style --foreground 35 "✓ All pastes deleted"
    }
    
    cmd_upload() {
      load_config
      check_config
      
      local content=""
      local filename=""
      local language=""
      local private="false"
      local key=""
      local update_id=""
      local no_copy="false"
      
      # Parse arguments
      while [ $# -gt 0 ]; do
        case "$1" in
          -L|--language)
            language="$2"
            shift 2
            ;;
          -f|--filename)
            filename="$2"
            shift 2
            ;;
          -p|--private)
            private="true"
            shift
            ;;
          -k|--key)
            key="$2"
            shift 2
            ;;
          -u|--update)
            update_id="$2"
            shift 2
            ;;
          -n|--no-copy)
            no_copy="true"
            shift
            ;;
          -|/dev/stdin)
            shift
            ;;
          *)
            # Assume it's a file
            if [ -f "$1" ]; then
              content=$(${pkgs.coreutils}/bin/cat "$1")
              if [ -z "$filename" ]; then
                filename=$(${pkgs.coreutils}/bin/basename "$1")
              fi
            else
              ${pkgs.gum}/bin/gum style --foreground 196 "File not found: $1"
              exit 1
            fi
            shift
            ;;
        esac
      done
      
      # Read from stdin if no file provided
      if [ -z "$content" ]; then
        if [ -t 0 ]; then
          ${pkgs.gum}/bin/gum style --foreground 196 "No input provided (pipe content or specify a file)"
          exit 1
        fi
        content=$(${pkgs.coreutils}/bin/cat)
      fi
      
      # Detect language if not specified
      if [ -z "$language" ] && [ -n "$filename" ]; then
        language=$(detect_language "$filename")
      fi
      
      # Build JSON payload
      payload=$(${pkgs.jq}/bin/jq -n \
        --arg content "$content" \
        --arg filename "$filename" \
        --arg language "$language" \
        --argjson private "$private" \
        --arg key "$key" \
        '{code: $content} + 
         (if $filename != "" then {filename: $filename} else {} end) +
         (if $language != "" then {language: $language} else {} end) +
         (if $private then {private: true} else {} end) +
         (if $key != "" then {key: $key} else {} end)')
      
      # Make request
      local method="POST"
      local url="$HOST/api"
      
      if [ -n "$update_id" ]; then
        method="PUT"
        url="$HOST/api/$update_id"
      fi
      
      response=$(echo "$payload" | ${pkgs.curl}/bin/curl -s -f -X "$method" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AUTH_KEY" \
        -d @- \
        "$url" 2>&1) || {
        ${pkgs.gum}/bin/gum style --foreground 196 "Failed to upload paste"
        echo "$response" >&2
        exit 1
      }
      
      paste_id=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.id // empty')
      paste_url=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.url // empty')
      
      if [ -z "$paste_url" ] && [ -n "$paste_id" ]; then
        paste_url="$HOST/$paste_id"
      fi
      
      # Copy to clipboard
      if [ "$no_copy" != "true" ]; then
        url="$paste_url"
        if ${clipboardCopy}; then
          ${pkgs.gum}/bin/gum style --foreground 35 "✓ Copied to clipboard"
        fi
      fi
      
      ${pkgs.gum}/bin/gum style --foreground 35 "$paste_url"
    }
    
    # Main
    case "''${1:-}" in
      init|--init)
        cmd_init
        ;;
      config|--show-config)
        cmd_config
        ;;
      list)
        shift
        cmd_list "$@"
        ;;
      -l|--list)
        shift
        cmd_list "$@"
        ;;
      delete|-d)
        shift
        cmd_delete "$@"
        ;;
      delete-all|-D)
        cmd_delete_all
        ;;
      -h|--help)
        ${pkgs.gum}/bin/gum style --bold --foreground 212 "pbnj - pastebin CLI"
        echo
        echo "Usage: pbnj [options] [file]"
        echo "       cat file | pbnj"
        echo
        echo "Commands:"
        echo "  init          Configure pbnj instance"
        echo "  config        Show current configuration"
        echo "  list [n]      List recent pastes (default: 10)"
        echo "  delete <id>   Delete a paste"
        echo "  delete-all    Delete all pastes"
        echo
        echo "Options:"
        echo "  -L, --language <lang>   Override language detection"
        echo "  -f, --filename <name>   Set custom filename"
        echo "  -p, --private           Create private paste"
        echo "  -k, --key <key>         Add secret key"
        echo "  -u, --update <id>       Update existing paste"
        echo "  -n, --no-copy           Don't copy URL to clipboard"
        echo "  -l, --list [n]          List recent pastes"
        echo "  -h, --help              Show this help"
        ;;
      -*)
        # Flags for upload
        cmd_upload "$@"
        ;;
      "")
        # No args, try stdin
        cmd_upload "$@"
        ;;
      *)
        # File argument
        cmd_upload "$@"
        ;;
    esac
  '';

  pbnj = pkgs.stdenv.mkDerivation {
    pname = "pbnj";
    version = "1.0";

    dontUnpack = true;

    nativeBuildInputs = with pkgs; [ pandoc installShellFiles ];

    manPageSrc = ./pbnj.1.md;
    bashCompletionSrc = ./completions/pbnj.bash;
    zshCompletionSrc = ./completions/pbnj.zsh;
    fishCompletionSrc = ./completions/pbnj.fish;

    buildPhase = ''
      ${pkgs.pandoc}/bin/pandoc -s -t man $manPageSrc -o pbnj.1
    '';

    installPhase = ''
      mkdir -p $out/bin

      cp ${pbnjScript} $out/bin/pbnj
      chmod +x $out/bin/pbnj

      installManPage pbnj.1

      installShellCompletion --bash --name pbnj $bashCompletionSrc
      installShellCompletion --zsh --name _pbnj $zshCompletionSrc
      installShellCompletion --fish --name pbnj.fish $fishCompletionSrc
    '';

    meta = with lib; {
      description = "Pastebin CLI with charm";
      homepage = "https://github.com/bhavnicksm/pbnj";
      license = licenses.mit;
      maintainers = [ ];
    };
  };
in
{
  options.atelier.pbnj = {
    enable = lib.mkEnableOption "pbnj pastebin CLI";

    host = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "pbnj instance URL";
    };

    authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to file containing auth key (e.g. agenix secret)";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pbnj ];
  };
}

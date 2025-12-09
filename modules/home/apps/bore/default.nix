{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.atelier.bore;

  boreScript = pkgs.writeShellScript "bore" ''
    CONFIG_FILE="bore.toml"
    
    # Check for flags
    if [ "$1" = "--list" ] || [ "$1" = "-l" ]; then
      ${pkgs.gum}/bin/gum style --bold --foreground 212 "Active tunnels"
      echo
      
      tunnels=$(${pkgs.curl}/bin/curl -s https://${cfg.domain}/api/proxy/http)
      
      if ! echo "$tunnels" | ${pkgs.jq}/bin/jq -e '.proxies | length > 0' >/dev/null 2>&1; then
        ${pkgs.gum}/bin/gum style --foreground 117 "No active tunnels"
        exit 0
      fi
      
      # Filter only online tunnels with valid conf
      echo "$tunnels" | ${pkgs.jq}/bin/jq -r '.proxies[] | select(.status == "online" and .conf != null) | "\(.name) → https://\(.conf.subdomain).${cfg.domain}"' | while read -r line; do
        ${pkgs.gum}/bin/gum style --foreground 35 "✓ $line"
      done
      exit 0
    fi

    if [ "$1" = "--saved" ] || [ "$1" = "-s" ]; then
      if [ ! -f "$CONFIG_FILE" ]; then
        ${pkgs.gum}/bin/gum style --foreground 117 "No bore.toml found in current directory"
        exit 0
      fi
      
      ${pkgs.gum}/bin/gum style --bold --foreground 212 "Saved tunnels in bore.toml"
      echo
      
      # Parse TOML and show tunnels
      while IFS= read -r line; do
        if [[ "$line" =~ ^\[([^]]+)\] ]]; then
          current_tunnel="''${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^port[[:space:]]*=[[:space:]]*([0-9]+) ]]; then
          port="''${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^label[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
          label="''${BASH_REMATCH[1]}"
          ${pkgs.gum}/bin/gum style --foreground 35 "✓ $current_tunnel → localhost:$port [$label]"
          label=""
        elif [[ -z "$line" ]] && [[ -n "$current_tunnel" ]] && [[ -n "$port" ]]; then
          ${pkgs.gum}/bin/gum style --foreground 35 "✓ $current_tunnel → localhost:$port"
          current_tunnel=""
          port=""
        fi
      done < "$CONFIG_FILE"
      
      # Handle last entry if file doesn't end with blank line
      if [[ -n "$current_tunnel" ]] && [[ -n "$port" ]]; then
        if [[ -n "$label" ]]; then
          ${pkgs.gum}/bin/gum style --foreground 35 "✓ $current_tunnel → localhost:$port [$label]"
        else
          ${pkgs.gum}/bin/gum style --foreground 35 "✓ $current_tunnel → localhost:$port"
        fi
      fi
      exit 0
    fi

    # Get subdomain
    if [ -n "$1" ]; then
      subdomain="$1"
    else
      # Check if we have a bore.toml in current directory
      if [ -f "$CONFIG_FILE" ]; then
        # Count tunnels in TOML
        tunnel_count=$(${pkgs.gnugrep}/bin/grep -c '^\[' "$CONFIG_FILE" 2>/dev/null || echo "0")
        
        if [ "$tunnel_count" -gt 0 ]; then
          ${pkgs.gum}/bin/gum style --bold --foreground 212 "Creating bore tunnel"
          echo
          
          # Show choice between new or saved
          choice=$(${pkgs.gum}/bin/gum choose "New tunnel" "Use saved tunnel")
          
          if [ "$choice" = "Use saved tunnel" ]; then
            # Extract tunnel names from TOML
            saved_names=$(${pkgs.gnugrep}/bin/grep '^\[' "$CONFIG_FILE" | ${pkgs.gnused}/bin/sed 's/^\[\(.*\)\]$/\1/')
            subdomain=$(echo "$saved_names" | ${pkgs.gum}/bin/gum choose)
            
            if [ -z "$subdomain" ]; then
              ${pkgs.gum}/bin/gum style --foreground 196 "No tunnel selected"
              exit 1
            fi
            
            # Parse TOML for this tunnel's config
            in_section=false
            while IFS= read -r line; do
              if [[ "$line" =~ ^\[([^]]+)\] ]]; then
                if [[ "''${BASH_REMATCH[1]}" = "$subdomain" ]]; then
                  in_section=true
                else
                  in_section=false
                fi
              elif [[ "$in_section" = true ]]; then
                if [[ "$line" =~ ^port[[:space:]]*=[[:space:]]*([0-9]+) ]]; then
                  port="''${BASH_REMATCH[1]}"
                elif [[ "$line" =~ ^label[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
                  label="''${BASH_REMATCH[1]}"
                fi
              fi
            done < "$CONFIG_FILE"
            
            ${pkgs.gum}/bin/gum style --foreground 35 "✓ Loaded from bore.toml: $subdomain → localhost:$port''${label:+ [$label]}"
          else
            # New tunnel
            subdomain=$(${pkgs.gum}/bin/gum input --placeholder "myapp" --prompt "Subdomain: ")
            if [ -z "$subdomain" ]; then
              ${pkgs.gum}/bin/gum style --foreground 196 "No subdomain provided"
              exit 1
            fi
          fi
        else
          ${pkgs.gum}/bin/gum style --bold --foreground 212 "Creating bore tunnel"
          echo
          subdomain=$(${pkgs.gum}/bin/gum input --placeholder "myapp" --prompt "Subdomain: ")
          if [ -z "$subdomain" ]; then
            ${pkgs.gum}/bin/gum style --foreground 196 "No subdomain provided"
            exit 1
          fi
        fi
      else
        ${pkgs.gum}/bin/gum style --bold --foreground 212 "Creating bore tunnel"
        echo
        subdomain=$(${pkgs.gum}/bin/gum input --placeholder "myapp" --prompt "Subdomain: ")
        if [ -z "$subdomain" ]; then
          ${pkgs.gum}/bin/gum style --foreground 196 "No subdomain provided"
          exit 1
        fi
      fi
    fi

    # Validate subdomain
    if ! echo "$subdomain" | ${pkgs.gnugrep}/bin/grep -qE '^[a-z0-9-]+$'; then
      ${pkgs.gum}/bin/gum style --foreground 196 "Invalid subdomain (use only lowercase letters, numbers, and hyphens)"
      exit 1
    fi

    # Get port (skip if loaded from saved config)
    if [ -z "$port" ]; then
      if [ -n "$2" ]; then
        port="$2"
      else
        port=$(${pkgs.gum}/bin/gum input --placeholder "8000" --prompt "Local port: ")
        if [ -z "$port" ]; then
          ${pkgs.gum}/bin/gum style --foreground 196 "No port provided"
          exit 1
        fi
      fi
    fi

    # Validate port
    if ! echo "$port" | ${pkgs.gnugrep}/bin/grep -qE '^[0-9]+$'; then
      ${pkgs.gum}/bin/gum style --foreground 196 "Invalid port (must be a number)"
      exit 1
    fi

    # Get optional label and save flag (skip if loaded from saved config)
    save_config=false
    if [ -z "$label" ]; then
      shift 2 2>/dev/null || true
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --label|-l)
            label="$2"
            shift 2
            ;;
          --save)
            save_config=true
            shift
            ;;
          *)
            shift
            ;;
        esac
      done
    fi

    # Check if local port is accessible
    if ! ${pkgs.netcat}/bin/nc -z 127.0.0.1 "$port" 2>/dev/null; then
      ${pkgs.gum}/bin/gum style --foreground 214 "! Warning: Nothing listening on localhost:$port"
    fi

    # Save configuration if requested
    if [ "$save_config" = true ]; then
      # Check if tunnel already exists in TOML
      if [ -f "$CONFIG_FILE" ] && ${pkgs.gnugrep}/bin/grep -q "^\[$subdomain\]" "$CONFIG_FILE"; then
        # Update existing entry
        ${pkgs.gnused}/bin/sed -i "/^\[$subdomain\]/,/^\[/{ 
          s/^port[[:space:]]*=.*/port = $port/
          ''${label:+s/^label[[:space:]]*=.*/label = \"$label\"/}
        }" "$CONFIG_FILE"
      else
        # Append new entry
        {
          echo ""
          echo "[$subdomain]"
          echo "port = $port"
          if [ -n "$label" ]; then
            echo "label = \"$label\""
          fi
        } >> "$CONFIG_FILE"
      fi
      
      ${pkgs.gum}/bin/gum style --foreground 35 "✓ Configuration saved to bore.toml"
      echo
    fi

    # Create config file
    config_file=$(${pkgs.coreutils}/bin/mktemp)
    trap "${pkgs.coreutils}/bin/rm -f $config_file" EXIT

    # Encode label into proxy name if provided (format: subdomain[label])
    proxy_name="$subdomain"
    if [ -n "$label" ]; then
      proxy_name="''${subdomain}[''${label}]"
    fi

    ${pkgs.coreutils}/bin/cat > $config_file <<EOF
    serverAddr = "${cfg.serverAddr}"
    serverPort = ${toString cfg.serverPort}

    auth.method = "token"
    auth.tokenSource.type = "file"
    auth.tokenSource.file.path = "${cfg.authTokenFile}"

    [[proxies]]
    name = "$proxy_name"
    type = "http"
    localIP = "127.0.0.1"
    localPort = $port
    subdomain = "$subdomain"
    EOF

    # Start tunnel
    public_url="https://$subdomain.${cfg.domain}"
    echo
    ${pkgs.gum}/bin/gum style --foreground 35 "✓ Tunnel configured"
    ${pkgs.gum}/bin/gum style --foreground 117 "  Local:  localhost:$port"
    ${pkgs.gum}/bin/gum style --foreground 117 "  Public: $public_url"
    echo
    ${pkgs.gum}/bin/gum style --foreground 214 "Connecting to ${cfg.serverAddr}:${toString cfg.serverPort}..."

    exec ${pkgs.frp}/bin/frpc -c $config_file
  '';

  bore = pkgs.stdenv.mkDerivation {
    pname = "bore";
    version = "1.0";

    dontUnpack = true;

    nativeBuildInputs = with pkgs; [ pandoc installShellFiles ];

    manPageSrc = ./bore.1.md;
    bashCompletionSrc = ./completions/bore.bash;
    zshCompletionSrc = ./completions/bore.zsh;
    fishCompletionSrc = ./completions/bore.fish;

    buildPhase = ''
      # Convert markdown man page to man format
      ${pkgs.pandoc}/bin/pandoc -s -t man $manPageSrc -o bore.1
    '';

    installPhase = ''
      mkdir -p $out/bin

      # Install binary
      cp ${boreScript} $out/bin/bore
      chmod +x $out/bin/bore

      # Install man page
      installManPage bore.1

      # Install completions
      installShellCompletion --bash --name bore $bashCompletionSrc
      installShellCompletion --zsh --name _bore $zshCompletionSrc
      installShellCompletion --fish --name bore.fish $fishCompletionSrc
    '';

    meta = with lib; {
      description = "Secure tunneling service CLI";
      homepage = "https://bore.dunkirk.sh";
      license = licenses.mit;
      maintainers = [ ];
    };
  };
in
{
  options.atelier.bore = {
    enable = lib.mkEnableOption "bore tunneling service";

    serverAddr = lib.mkOption {
      type = lib.types.str;
      default = "bore.dunkirk.sh";
      description = "bore server address";
    };

    serverPort = lib.mkOption {
      type = lib.types.port;
      default = 7000;
      description = "bore server port";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "bore.dunkirk.sh";
      description = "Domain for public tunnel URLs";
    };

    authTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to file containing authentication token";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.frp
      bore
    ];
  };
}

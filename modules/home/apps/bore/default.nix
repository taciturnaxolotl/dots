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
    
    # Trap exit signals to ensure cleanup and exit immediately
    trap 'exit 130' INT
    trap 'exit 143' TERM
    trap 'exit 129' HUP
    
    # Enable immediate exit on error or pipe failure
    set -e
    set -o pipefail
    
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
      echo "$tunnels" | ${pkgs.jq}/bin/jq -r '.proxies[] | select(.status == "online" and .conf != null) | if .type == "http" then "\(.name) → https://\(.conf.subdomain).${cfg.domain} [http]" elif .type == "tcp" then "\(.name) → tcp://\(.conf.remotePort) → localhost:\(.conf.localPort) [tcp]" elif .type == "udp" then "\(.name) → udp://\(.conf.remotePort) → localhost:\(.conf.localPort) [udp]" else "\(.name) [\(.type)]" end' | while read -r line; do
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
        elif [[ "$line" =~ ^protocol[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
          protocol="''${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^label[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
          label="''${BASH_REMATCH[1]}"
          proto_display="''${protocol:-http}"
          ${pkgs.gum}/bin/gum style --foreground 35 "✓ $current_tunnel → localhost:$port [$proto_display] [$label]"
          label=""
          protocol=""
        elif [[ -z "$line" ]] && [[ -n "$current_tunnel" ]] && [[ -n "$port" ]]; then
          proto_display="''${protocol:-http}"
          ${pkgs.gum}/bin/gum style --foreground 35 "✓ $current_tunnel → localhost:$port [$proto_display]"
          current_tunnel=""
          port=""
          protocol=""
        fi
      done < "$CONFIG_FILE"
      
      # Handle last entry if file doesn't end with blank line
      if [[ -n "$current_tunnel" ]] && [[ -n "$port" ]]; then
        proto_display="''${protocol:-http}"
        if [[ -n "$label" ]]; then
          ${pkgs.gum}/bin/gum style --foreground 35 "✓ $current_tunnel → localhost:$port [$proto_display] [$label]"
        else
          ${pkgs.gum}/bin/gum style --foreground 35 "✓ $current_tunnel → localhost:$port [$proto_display]"
        fi
      fi
      exit 0
    fi

    # Get tunnel name/subdomain
    if [ -n "$1" ]; then
      tunnel_name="$1"
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
            tunnel_name=$(echo "$saved_names" | ${pkgs.gum}/bin/gum choose)
            
            if [ -z "$tunnel_name" ]; then
              ${pkgs.gum}/bin/gum style --foreground 196 "No tunnel selected"
              exit 1
            fi
            
            # Parse TOML for this tunnel's config
            in_section=false
            while IFS= read -r line; do
              if [[ "$line" =~ ^\[([^]]+)\] ]]; then
                if [[ "''${BASH_REMATCH[1]}" = "$tunnel_name" ]]; then
                  in_section=true
                else
                  in_section=false
                fi
              elif [[ "$in_section" = true ]]; then
                if [[ "$line" =~ ^port[[:space:]]*=[[:space:]]*([0-9]+) ]]; then
                  port="''${BASH_REMATCH[1]}"
                elif [[ "$line" =~ ^protocol[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
                  protocol="''${BASH_REMATCH[1]}"
                elif [[ "$line" =~ ^label[[:space:]]*=[[:space:]]*\"([^\"]+)\" ]]; then
                  label="''${BASH_REMATCH[1]}"
                fi
              fi
            done < "$CONFIG_FILE"
            
            proto_display="''${protocol:-http}"
            ${pkgs.gum}/bin/gum style --foreground 35 "✓ Loaded from bore.toml: $tunnel_name → localhost:$port [$proto_display]''${label:+ [$label]}"
          else
            # New tunnel - prompt for protocol first to determine what to ask for
            protocol=$(${pkgs.gum}/bin/gum choose --header "Protocol:" "http" "tcp" "udp")
            if [ -z "$protocol" ]; then
              protocol="http"
            fi
            
            if [ "$protocol" = "http" ]; then
              tunnel_name=$(${pkgs.gum}/bin/gum input --placeholder "myapp" --prompt "Subdomain: ")
            else
              tunnel_name=$(${pkgs.gum}/bin/gum input --placeholder "my-tunnel" --prompt "Tunnel name: ")
            fi
            
            if [ -z "$tunnel_name" ]; then
              ${pkgs.gum}/bin/gum style --foreground 196 "No name provided"
              exit 1
            fi
          fi
        else
          ${pkgs.gum}/bin/gum style --bold --foreground 212 "Creating bore tunnel"
          echo
          # Prompt for protocol first
          protocol=$(${pkgs.gum}/bin/gum choose --header "Protocol:" "http" "tcp" "udp")
          if [ -z "$protocol" ]; then
            protocol="http"
          fi
          
          if [ "$protocol" = "http" ]; then
            tunnel_name=$(${pkgs.gum}/bin/gum input --placeholder "myapp" --prompt "Subdomain: ")
          else
            tunnel_name=$(${pkgs.gum}/bin/gum input --placeholder "my-tunnel" --prompt "Tunnel name: ")
          fi
          
          if [ -z "$tunnel_name" ]; then
            ${pkgs.gum}/bin/gum style --foreground 196 "No name provided"
            exit 1
          fi
        fi
      else
        ${pkgs.gum}/bin/gum style --bold --foreground 212 "Creating bore tunnel"
        echo
        # Prompt for protocol first
        protocol=$(${pkgs.gum}/bin/gum choose --header "Protocol:" "http" "tcp" "udp")
        if [ -z "$protocol" ]; then
          protocol="http"
        fi
        
        if [ "$protocol" = "http" ]; then
          tunnel_name=$(${pkgs.gum}/bin/gum input --placeholder "myapp" --prompt "Subdomain: ")
        else
          tunnel_name=$(${pkgs.gum}/bin/gum input --placeholder "my-tunnel" --prompt "Tunnel name: ")
        fi
        
        if [ -z "$tunnel_name" ]; then
          ${pkgs.gum}/bin/gum style --foreground 196 "No name provided"
          exit 1
        fi
      fi
    fi

    # Validate tunnel name (only for http subdomains)
    if [ "$protocol" = "http" ]; then
      if ! echo "$tunnel_name" | ${pkgs.gnugrep}/bin/grep -qE '^[a-z0-9-]+$'; then
        ${pkgs.gum}/bin/gum style --foreground 196 "Invalid subdomain (use only lowercase letters, numbers, and hyphens)"
        exit 1
      fi
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

    # Get optional protocol, label and save flag (skip if loaded from saved config)
    save_config=false
    if [ -z "$label" ]; then
      shift 2 2>/dev/null || true
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --protocol|-p)
            protocol="$2"
            shift 2
            ;;
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
      
      # Prompt for protocol if not provided via flag and not loaded from saved config and not already set
      if [ -z "$protocol" ]; then
        protocol=$(${pkgs.gum}/bin/gum choose --header "Protocol:" "http" "tcp" "udp")
        if [ -z "$protocol" ]; then
          protocol="http"
        fi
      fi
      
      # Prompt for label if not provided via flag and not loaded from saved config
      if [ -z "$label" ]; then
        # Allow multiple labels selection
        labels=$(${pkgs.gum}/bin/gum choose --no-limit --header "Labels (select multiple):" "dev" "prod" "custom")
        
        if [ -n "$labels" ]; then
          # Check if custom was selected
          if echo "$labels" | ${pkgs.gnugrep}/bin/grep -q "custom"; then
            custom_label=$(${pkgs.gum}/bin/gum input --placeholder "my-label" --prompt "Custom label: ")
            if [ -z "$custom_label" ]; then
              ${pkgs.gum}/bin/gum style --foreground 196 "No custom label provided"
              exit 1
            fi
            # Replace 'custom' with the actual custom label
            labels=$(echo "$labels" | ${pkgs.gnused}/bin/sed "s/custom/$custom_label/")
          fi
          # Join labels with comma
          label=$(echo "$labels" | ${pkgs.coreutils}/bin/tr '\n' ',' | ${pkgs.gnused}/bin/sed 's/,$//')
        fi
      fi
    fi
    
    # Default protocol to http if still not set
    if [ -z "$protocol" ]; then
      protocol="http"
    fi

    # Check if local port is accessible
    if ! ${pkgs.netcat}/bin/nc -z 127.0.0.1 "$port" 2>/dev/null; then
      ${pkgs.gum}/bin/gum style --foreground 214 "! Warning: Nothing listening on localhost:$port"
    fi

    # Save configuration if requested
    if [ "$save_config" = true ]; then
      # Check if tunnel already exists in TOML
      if [ -f "$CONFIG_FILE" ] && ${pkgs.gnugrep}/bin/grep -q "^\[$tunnel_name\]" "$CONFIG_FILE"; then
        # Update existing entry
        ${pkgs.gnused}/bin/sed -i "/^\[$tunnel_name\]/,/^\[/{ 
          s/^port[[:space:]]*=.*/port = $port/
          s/^protocol[[:space:]]*=.*/protocol = \"$protocol\"/
          ''${label:+s/^label[[:space:]]*=.*/label = \"$label\"/}
        }" "$CONFIG_FILE"
      else
        # Append new entry
        {
          echo ""
          echo "[$tunnel_name]"
          echo "port = $port"
          if [ "$protocol" != "http" ]; then
            echo "protocol = \"$protocol\""
          fi
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

    # Encode label into proxy name if provided (format: tunnel_name[label1,label2])
    proxy_name="$tunnel_name"
    if [ -n "$label" ]; then
      proxy_name="''${tunnel_name}[''${label}]"
    fi

    # Build proxy configuration based on protocol
    if [ "$protocol" = "http" ]; then
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
    subdomain = "$tunnel_name"
    EOF
    elif [ "$protocol" = "tcp" ] || [ "$protocol" = "udp" ]; then
      # For TCP/UDP, enable admin API to query allocated port
      # Use Python to find a free port (cross-platform and guaranteed to work)
      admin_port=$(${pkgs.python3}/bin/python3 -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')
      
      ${pkgs.coreutils}/bin/cat > $config_file <<EOF
    serverAddr = "${cfg.serverAddr}"
    serverPort = ${toString cfg.serverPort}

    auth.method = "token"
    auth.tokenSource.type = "file"
    auth.tokenSource.file.path = "${cfg.authTokenFile}"
    
    webServer.addr = "127.0.0.1"
    webServer.port = $admin_port

    [[proxies]]
    name = "$proxy_name"
    type = "$protocol"
    localIP = "127.0.0.1"
    localPort = $port
    remotePort = 0
    EOF
    else
      ${pkgs.gum}/bin/gum style --foreground 196 "Invalid protocol: $protocol (must be http, tcp, or udp)"
      exit 1
    fi

    # Start tunnel
    echo
    ${pkgs.gum}/bin/gum style --foreground 35 "✓ Tunnel configured"
    ${pkgs.gum}/bin/gum style --foreground 117 "  Local:    localhost:$port"
    if [ "$protocol" = "http" ]; then
      public_url="https://$tunnel_name.${cfg.domain}"
      ${pkgs.gum}/bin/gum style --foreground 117 "  Public:   $public_url"
    else
      ${pkgs.gum}/bin/gum style --foreground 117 "  Protocol: $protocol"
      ${pkgs.gum}/bin/gum style --foreground 214 "  Waiting for server to allocate port..."
    fi
    echo
    ${pkgs.gum}/bin/gum style --foreground 214 "Connecting to ${cfg.serverAddr}:${toString cfg.serverPort}..."
    echo

    # For TCP/UDP, capture output to parse allocated port
    if [ "$protocol" = "tcp" ] || [ "$protocol" = "udp" ]; then
      # Start frpc in background and capture its PID
      ${pkgs.frp}/bin/frpc -c $config_file 2>&1 | while IFS= read -r line; do
        echo "$line"
        
        # Look for successful proxy start
        if echo "$line" | ${pkgs.gnugrep}/bin/grep -q "start proxy success"; then
          # Wait a moment for the proxy to fully initialize
          sleep 1
          
          # Query the frpc admin API for proxy status
          proxy_status=$(${pkgs.curl}/bin/curl -s http://127.0.0.1:$admin_port/api/status 2>/dev/null || echo "{}")
          
          # Try to extract remote port from JSON response
          # Format: "remote_addr":"bore.dunkirk.sh:20097"
          remote_addr=$(echo "$proxy_status" | ${pkgs.jq}/bin/jq -r ".tcp[]? | select(.name == \"$proxy_name\") | .remote_addr" 2>/dev/null)
          if [ -z "$remote_addr" ] || [ "$remote_addr" = "null" ]; then
            remote_addr=$(echo "$proxy_status" | ${pkgs.jq}/bin/jq -r ".udp[]? | select(.name == \"$proxy_name\") | .remote_addr" 2>/dev/null)
          fi
          
          # Extract just the port number
          remote_port=$(echo "$remote_addr" | ${pkgs.gnugrep}/bin/grep -oP ':\K[0-9]+$')
          
          if [ -n "$remote_port" ] && [ "$remote_port" != "null" ]; then
            echo
            ${pkgs.gum}/bin/gum style --foreground 35 "✓ Tunnel established"
            ${pkgs.gum}/bin/gum style --foreground 117 "  Local:  localhost:$port"
            ${pkgs.gum}/bin/gum style --foreground 117 "  Remote: ${cfg.serverAddr}:$remote_port"
            ${pkgs.gum}/bin/gum style --foreground 117 "  Type:   $protocol"
            echo
          fi
        fi
      done
    else
      exec ${pkgs.frp}/bin/frpc -c $config_file
    fi
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

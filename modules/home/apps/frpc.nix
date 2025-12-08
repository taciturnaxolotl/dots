{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.atelier.frpc;

  frpc-tunnel = pkgs.writeShellScriptBin "frpc-tunnel" ''
    # Check if gum is available
    if ! command -v ${pkgs.gum}/bin/gum >/dev/null 2>&1; then
      echo "Error: gum is required but not installed"
      exit 1
    fi

    # Get subdomain
    if [ -n "$1" ]; then
      subdomain="$1"
    else
      ${pkgs.gum}/bin/gum style --foreground 212 --bold "🚇 FRP Tunnel"
      echo
      subdomain=$(${pkgs.gum}/bin/gum input --placeholder "Enter subdomain (e.g., myapp)")
      if [ -z "$subdomain" ]; then
        ${pkgs.gum}/bin/gum style --foreground 196 "❌ Subdomain cannot be empty"
        exit 1
      fi
    fi

    # Validate subdomain
    if ! echo "$subdomain" | ${pkgs.gnugrep}/bin/grep -qE '^[a-z0-9-]+$'; then
      ${pkgs.gum}/bin/gum style --foreground 196 "❌ Subdomain must contain only lowercase letters, numbers, and hyphens"
      exit 1
    fi

    # Get port
    if [ -n "$2" ]; then
      port="$2"
    else
      port=$(${pkgs.gum}/bin/gum input --placeholder "Enter local port (e.g., 8000)")
      if [ -z "$port" ]; then
        ${pkgs.gum}/bin/gum style --foreground 196 "❌ Port cannot be empty"
        exit 1
      fi
    fi

    # Validate port
    if ! echo "$port" | ${pkgs.gnugrep}/bin/grep -qE '^[0-9]+$'; then
      ${pkgs.gum}/bin/gum style --foreground 196 "❌ Port must be a number"
      exit 1
    fi

    config_file=$(${pkgs.coreutils}/bin/mktemp)
    trap "${pkgs.coreutils}/bin/rm -f $config_file" EXIT

    ${pkgs.coreutils}/bin/cat > $config_file <<EOF
    serverAddr = "${cfg.serverAddr}"
    serverPort = ${toString cfg.serverPort}

    auth.method = "token"
    auth.tokenSource.type = "file"
    auth.tokenSource.file.path = "${cfg.authTokenFile}"

    [[proxies]]
    name = "$subdomain-tunnel"
    type = "http"
    localIP = "127.0.0.1"
    localPort = $port
    subdomain = "$subdomain"
    EOF

    echo
    ${pkgs.gum}/bin/gum style --border double --padding "1 2" --border-foreground 212 \
      "🌐 Tunnel Active" \
      "" \
      "Local:  $(${pkgs.gum}/bin/gum style --foreground 212 --bold "localhost:$port")" \
      "Public: $(${pkgs.gum}/bin/gum style --foreground 212 --bold "https://$subdomain.bore.dunkirk.sh")" \
      "" \
      "Press $(${pkgs.gum}/bin/gum style --foreground 196 --bold "Ctrl+C") to stop"
    echo

    exec ${pkgs.frp}/bin/frpc -c $config_file
  '';
in
{
  options.atelier.frpc = {
    enable = lib.mkEnableOption "frp client for tunneling services";

    serverAddr = lib.mkOption {
      type = lib.types.str;
      default = "terebithia.dunkirk.sh";
      description = "frp server address";
    };

    serverPort = lib.mkOption {
      type = lib.types.port;
      default = 7000;
      description = "frp server port";
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
      frpc-tunnel
    ];
  };
}

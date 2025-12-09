{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.atelier.bore;

  bore = pkgs.writeShellScriptBin "bore" ''
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

    # Get subdomain
    if [ -n "$1" ]; then
      subdomain="$1"
    else
      ${pkgs.gum}/bin/gum style --bold --foreground 212 "Creating bore tunnel"
      echo
      subdomain=$(${pkgs.gum}/bin/gum input --placeholder "myapp" --prompt "Subdomain: ")
      if [ -z "$subdomain" ]; then
        ${pkgs.gum}/bin/gum style --foreground 196 "No subdomain provided"
        exit 1
      fi
    fi

    # Validate subdomain
    if ! echo "$subdomain" | ${pkgs.gnugrep}/bin/grep -qE '^[a-z0-9-]+$'; then
      ${pkgs.gum}/bin/gum style --foreground 196 "Invalid subdomain (use only lowercase letters, numbers, and hyphens)"
      exit 1
    fi

    # Get port
    if [ -n "$2" ]; then
      port="$2"
    else
      port=$(${pkgs.gum}/bin/gum input --placeholder "8000" --prompt "Local port: ")
      if [ -z "$port" ]; then
        ${pkgs.gum}/bin/gum style --foreground 196 "No port provided"
        exit 1
      fi
    fi

    # Validate port
    if ! echo "$port" | ${pkgs.gnugrep}/bin/grep -qE '^[0-9]+$'; then
      ${pkgs.gum}/bin/gum style --foreground 196 "Invalid port (must be a number)"
      exit 1
    fi

    # Check if local port is accessible
    if ! ${pkgs.netcat}/bin/nc -z 127.0.0.1 "$port" 2>/dev/null; then
      ${pkgs.gum}/bin/gum style --foreground 214 "! Warning: Nothing listening on localhost:$port"
    fi

    # Create config file
    config_file=$(${pkgs.coreutils}/bin/mktemp)
    trap "${pkgs.coreutils}/bin/rm -f $config_file" EXIT

    ${pkgs.coreutils}/bin/cat > $config_file <<EOF
    serverAddr = "${cfg.serverAddr}"
    serverPort = ${toString cfg.serverPort}

    auth.method = "token"
    auth.tokenSource.type = "file"
    auth.tokenSource.file.path = "${cfg.authTokenFile}"

    [[proxies]]
    name = "$subdomain"
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

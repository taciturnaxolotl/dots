{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    (inputs.import-tree ../../../modules/home)
  ];

  nixpkgs.enable = true;

  home = {
    username = "kierank";
    homeDirectory = "/Users/kierank";
    packages = with pkgs; [
      inputs.nixvim.packages.${system}.default
      vesktop
    ];
  };

  atelier = {
    shell = {
      enable = true;
    };
    terminal = {
      ghostty = {
        enable = true;
        windowDecoration = true;
      };
    };
    apps = {
      halloy.enable = true;
      spotify.enable = true;
      crush.enable = true;
      helix.enable = true;
    };
  };

  programs.zsh.initContent = ''
    eval "$(/usr/libexec/path_helper)"

    # MITM proxy management functions
    MITM_SERVICE="Wi-Fi"  # Change to "Ethernet" if needed
    MITM_CERT="$HOME/.mitmproxy/mitmproxy-ca-cert.pem"

    mitmup() {
      # Generate mitmproxy CA certificate if it doesn't exist
      if [ ! -f "$MITM_CERT" ]; then
        echo "Generating mitmproxy CA certificate..."
        (timeout 0.1 mitmproxy --set confdir="$HOME/.mitmproxy" 2>/dev/null; true)
      fi

      networksetup -setwebproxy "$MITM_SERVICE" localhost 8080 &&
      networksetup -setsecurewebproxy "$MITM_SERVICE" localhost 8080 &&
      sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$MITM_CERT" &&
      echo "mitmproxy enabled and cert added"
    }

    mitmdown() {
      networksetup -setwebproxystate "$MITM_SERVICE" off &&
      networksetup -setsecurewebproxystate "$MITM_SERVICE" off &&
      sudo security delete-certificate -c mitmproxy /Library/Keychains/System.keychain &&
      echo "mitmproxy disabled and cert removed"
    }

    mitmstatus() {
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    NC='\033[0m' # No Color

    echo "========== Proxy Status =========="
    for proto in webproxy securewebproxy; do
    proxy_status=$(networksetup -get''${proto} "$MITM_SERVICE")
    enabled=$(echo "$proxy_status" | grep "Enabled: Yes")
    PROTO_UPPER=$(echo "$proto" | tr '[:lower:]' '[:upper:]')
    if [ -n "$enabled" ]; then
    echo -e "''${PROTO_UPPER} : ''${GREEN}ENABLED''${NC}"
    else
    echo -e "''${PROTO_UPPER} : ''${RED}DISABLED''${NC}"
    fi
    echo "$proxy_status" | grep -E "Server:|Port:"
    done

    echo "========== mitmproxy Certificate =========="
    if security find-certificate -c mitmproxy /Library/Keychains/System.keychain > /dev/null 2>&1; then
    echo -e "mitmproxy certificate: ''${GREEN}PRESENT''${NC}"
    else
    echo -e "mitmproxy certificate: ''${RED}NOT PRESENT''${NC}"
    fi

      echo "========== mitmproxy Process =========="
      if pgrep -f mitmproxy > /dev/null; then
        echo -e "mitmproxy process: ''${GREEN}RUNNING''${NC}"
      else
        echo -e "mitmproxy process: ''${RED}NOT RUNNING''${NC}"
      fi
      echo "==========================================="
    }

    
  '';

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "23.05";
}

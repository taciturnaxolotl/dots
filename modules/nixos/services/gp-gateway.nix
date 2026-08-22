# GlobalProtect → Tailscale subnet router
#
# Cedarville's GlobalProtect (globalprotect.cedarville.edu, PAN-OS 6.3.3) has
# cookie reauth disabled (portal-userauthcookie is empty, save-user-credentials
# 0), so there is no long-lived credential to persist. Every tunnel needs a
# fresh SAML + Duo. What this module buys instead: one login on prattle serves
# every device on the tailnet, and we keep only the campus routes so the VPN's
# content filtering never touches general traffic.
#
# Flow:
#   1. Browser does SAML+Duo, a helper (Chrome extension or manual curl) POSTs
#      the single-use prelogin-cookie to gp-receiver on the tailnet.
#   2. gp-receiver drops it at /run/gp-gateway/cookie and pokes gp-tunnel.
#   3. gp-tunnel hands the cookie to openconnect, which logs into the gateway,
#      submits HIP hourly, and holds the tunnel.
#   4. A custom vpnc-script installs ONLY cfg.routes (ignoring any pushed
#      default route), and tailscale advertises those same routes.
#
# The cookie is single-use and short-lived, so nothing is stored on disk beyond
# the tmpfs at /run. This module carries no secret in the nix store.

{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.atelier.services.gpGateway;

  # Install only the routes we care about; drop the gateway's default route and
  # DNS so prattle's own connectivity and the box's resolver are untouched. This
  # is the whole "I don't want the blocked stuff" guarantee: campus never sees
  # traffic outside these prefixes.
  vpncScript = pkgs.writeShellScript "gp-vpnc-script" ''
    set -eu
    export PATH=${lib.makeBinPath [ pkgs.iproute2 pkgs.coreutils ]}:$PATH
    # This REPLACES openconnect's stock vpnc-script on purpose. The stock script
    # would install the gateway's pushed 0.0.0.0/0, routing prattle's own traffic
    # (and this SSH session) through campus. So we bring the interface up
    # ourselves and add only cfg.routes. stdout lands in openconnect's journal;
    # no logger (not on PATH, and its absence returning 127 tears the tunnel down).
    case "$reason" in
      connect|reconnect)
        ip link set dev "$TUNDEV" up
        ip link set dev "$TUNDEV" mtu "''${INTERNAL_IP4_MTU:-1422}"
        ip addr replace "$INTERNAL_IP4_ADDRESS/32" dev "$TUNDEV"
        # Pin a host route to the gateway via the real uplink BEFORE adding the
        # campus routes. The gateway (163.11.247.242) sits inside 163.11.0.0/16,
        # so without this the gateway's own address gets pulled into the tunnel
        # and openconnect's keepalives/reconnects black-hole into it (looks like
        # dead-peer). The stock vpnc-script does this; we replaced it, so redo it.
        if [ -n "''${VPNGATEWAY:-}" ]; then
          orig=$(ip route get "$VPNGATEWAY" | sed -n 's/.* via \([0-9.]*\) dev \([^ ]*\).*/\1 \2/p')
          if [ -n "$orig" ]; then
            set -- $orig
            ip route replace "$VPNGATEWAY/32" via "$1" dev "$2"
            echo "gp-gateway: pinned gateway $VPNGATEWAY via $1 dev $2"
          fi
        fi
        ${lib.concatMapStringsSep "\n" (r: ''
          ip route replace ${r} dev "$TUNDEV"
        '') cfg.routes}
        echo "gp-gateway: up on $TUNDEV as $INTERNAL_IP4_ADDRESS, installed ${toString (lib.length cfg.routes)} route(s)"
        # Always log what the gateway pushed: a standing drift detector. If an
        # internal host stops resolving, grep gp-gateway: to see whether the
        # campus route set changed, then adjust cfg.routes.
        echo "gp-gateway: gateway pushed the following config:"
        env | grep -E '^(CISCO_SPLIT_INC|INTERNAL_IP4|CISCO_DEF_DOMAIN)' | sort || true
        ;;
      disconnect)
        ${lib.concatMapStringsSep "\n" (r: ''
          ip route del ${r} dev "$TUNDEV" 2>/dev/null || true
        '') cfg.routes}
        [ -n "''${VPNGATEWAY:-}" ] && ip route del "$VPNGATEWAY/32" 2>/dev/null || true
        ip addr flush dev "$TUNDEV" 2>/dev/null || true
        ;;
    esac
    exit 0
  '';

  connect = pkgs.writeShellScript "gp-connect" ''
    set -euo pipefail
    COOKIE_FILE=/run/gp-gateway/cookie
    USER_FILE=/run/gp-gateway/user
    # No cookie yet is not a failure: the tunnel only exists once the receiver
    # hands it one, so exit clean and stay dead until then. Failing here would
    # make deploy-rs treat every cookie-less activation as a broken deploy.
    [ -s "$COOKIE_FILE" ] || { echo "no cookie yet, waiting for gp-receiver"; exit 0; }

    # The SAML prelogin-cookie is single-use. The portal getconfig spends it, so
    # the gateway then rejects it as empty (auth-failed-password-empty). Skip the
    # portal entirely: --usergroup=gateway:prelogin-cookie connects straight to
    # the gateway and spends the one cookie exactly once, where it counts. The
    # gateway is the same host as the portal here, so nothing is lost. The cookie
    # goes in as the password (--passwd-on-stdin), not --cookie-on-stdin.
    exec ${pkgs.openconnect}/bin/openconnect \
      --protocol=gp \
      --user="$(cat "$USER_FILE")" \
      --usergroup=gateway:prelogin-cookie \
      --no-dtls \
      --passwd-on-stdin \
      --os=linux \
      --csd-wrapper=${pkgs.openconnect}/libexec/openconnect/hipreport.sh \
      --script=${vpncScript} \
      ${lib.optionalString (cfg.routes == [ ]) "--verbose "} \
      ${cfg.portal} < "$COOKIE_FILE"
  '';

  # Tailnet-only listener. Takes {user, cookie} JSON, writes it to the tmpfs,
  # and restarts the tunnel. Binds to the tailscale IP only; never 0.0.0.0.
  receiver = pkgs.writers.writePython3 "gp-receiver" { flakeIgnore = [ "E501" ]; } ''
    import base64
    import json
    import os
    import re
    import ssl
    import subprocess
    import urllib.request
    from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

    BIND = ("${cfg.bindAddr}", ${toString cfg.receiverPort})
    PORTAL = "${cfg.portal}"
    RUN = "/run/gp-gateway"
    # Mint from the GATEWAY prelogin, not the portal's. The gateway is a separate
    # SAML SP; a portal-audience cookie is rejected at the gateway login
    # (auth-failed-password-empty). openconnect connects gateway-direct, so the
    # captured cookie must be gateway-scoped.
    PRELOGIN = f"https://{PORTAL}/ssl-vpn/prelogin.esp?tmp=tmp&clientVer=4100&clientos=Linux"


    def fresh_login_url():
        # Mint a fresh SAMLRequest so the bookmark is stable but the RelayState
        # is never stale. We claim the GP client UA so the portal runs the app
        # flow (which later hands back a prelogin-cookie, not a web SESSID).
        req = urllib.request.Request(PRELOGIN, headers={"User-Agent": "PAN GlobalProtect"})
        xml = urllib.request.urlopen(req, timeout=20, context=ssl.create_default_context()).read().decode()
        m = re.search(r"<saml-request>(.*?)</saml-request>", xml, re.S)
        if not m:
            return None
        b = m.group(1).strip()
        b += "=" * (-len(b) % 4)
        return base64.b64decode(b).decode()


    def tunnel_status():
        # systemctl is the source of truth for up/down (the openconnect process
        # stays "active" only while the tunnel lives). Address/expiry are pulled
        # from the journal only when active, so a dead tunnel never reads as up.
        active = subprocess.run(
            ["systemctl", "is-active", "gp-tunnel.service"],
            capture_output=True, text=True,
        ).stdout.strip()
        if active != "active":
            return {"state": active, "address": None, "expires": None}
        addr = None
        expires = None
        try:
            j = subprocess.run(
                ["journalctl", "-u", "gp-tunnel.service", "-o", "cat",
                 "--no-pager", "-n", "400"],
                capture_output=True, text=True,
            ).stdout
            for line in j.splitlines():
                ma = re.search(r"Configured as ([0-9.]+)", line)
                if ma:
                    addr = ma.group(1)
                me = re.search(r"expire at (.+)$", line)
                if me:
                    expires = me.group(1).strip()
        except Exception:
            pass
        return {"state": "up", "address": addr, "expires": expires}


    class H(BaseHTTPRequestHandler):
        def send_json(self, obj):
            body = json.dumps(obj).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(body)

        def end_headers(self):
            # The extension's application/json POST triggers a CORS preflight;
            # answer it permissively since the listener is already tailnet-only.
            self.send_header("Access-Control-Allow-Origin", "*")
            super().end_headers()

        def do_OPTIONS(self):
            self.send_response(204)
            self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type")
            self.end_headers()

        def do_GET(self):
            if self.path == "/status":
                self.send_json(tunnel_status())
                return
            # The one-click entry point: bookmark http://<host>:<port>/ and each
            # click bounces you to a fresh Entra login.
            if self.path not in ("/", "/login"):
                self.send_response(404)
                self.end_headers()
                return
            try:
                url = fresh_login_url()
            except Exception as e:
                self.send_response(502)
                self.end_headers()
                self.wfile.write(f"prelogin failed: {e}".encode())
                return
            if not url:
                self.send_response(502)
                self.end_headers()
                self.wfile.write(b"no saml-request in prelogin")
                return
            self.send_response(302)
            self.send_header("Location", url)
            self.end_headers()

        def do_POST(self):
            if self.path != "/cookie":
                self.send_response(404)
                self.end_headers()
                return
            try:
                n = int(self.headers.get("Content-Length", 0))
                d = json.loads(self.rfile.read(n) or b"{}")
                user = d.get("user", "")
                cookie = d.get("cookie", "")
                if not cookie:
                    self.send_response(400)
                    self.end_headers()
                    self.wfile.write(b"no cookie")
                    return
                os.makedirs(RUN, mode=0o700, exist_ok=True)
                with open(RUN + "/user", "w") as f:
                    f.write(user)
                with open(RUN + "/cookie", "w") as f:
                    f.write(cookie)
                # --no-block: enqueue the restart and return at once. Waiting for
                # the job to settle would stall the HTTP response long enough for
                # the browser fetch to time out (badge stuck on "relaying").
                subprocess.run(
                    ["systemctl", "restart", "--no-block", "gp-tunnel.service"],
                    check=False,
                )
                self.send_response(200)
                self.end_headers()
                self.wfile.write(f"relayed cookie for {user}".encode())
            except Exception as e:
                # Always answer, so the browser extension never hangs on "relaying".
                self.send_response(500)
                self.end_headers()
                self.wfile.write(f"receiver error: {e}".encode())

        def log_message(self, *a):
            pass  # never log the cookie


    ThreadingHTTPServer(BIND, H).serve_forever()
  '';
in
{
  options.atelier.services.gpGateway = {
    enable = lib.mkEnableOption "GlobalProtect to Tailscale subnet router";

    portal = lib.mkOption {
      type = lib.types.str;
      default = "globalprotect.cedarville.edu";
      description = "GlobalProtect portal/gateway hostname.";
    };

    routes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "10.0.0.0/8" "163.11.0.0/16" ];
      description = ''
        Campus CIDRs to install on the tunnel and advertise over Tailscale.
        Leave empty for the first connect: openconnect runs verbose and the
        gateway's pushed routes show up in the journal, then fill this in.
      '';
    };

    receiverPort = lib.mkOption {
      type = lib.types.port;
      default = 8088;
      description = "Port for the tailnet-only cookie receiver.";
    };

    bindAddr = lib.mkOption {
      type = lib.types.str;
      default = "100.105.247.54"; # prattle's tailnet IP
      description = "Address the cookie receiver binds to. Keep this tailnet-only.";
    };
  };

  config = lib.mkIf cfg.enable {
    # nixarr's ProtonVPN netns may already set this; defer to whoever else wants it.
    boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkDefault 1;

    services.tailscale.useRoutingFeatures = lib.mkForce "both";

    # Own /run/gp-gateway here rather than via each service's RuntimeDirectory:
    # a shared RuntimeDirectory gets torn down when gp-tunnel stops (which it
    # does on every cookie-less start), yanking the dir out from under the
    # still-running receiver. tmpfiles keeps it stable across both lifecycles.
    systemd.tmpfiles.rules = [ "d /run/gp-gateway 0700 root root -" ];

    systemd.services.gp-tunnel = {
      description = "GlobalProtect tunnel (openconnect)";
      # Triggered only by the receiver, never by activation. Without this a
      # failed tunnel (expired cookie, dropped session) would sink the whole
      # deploy: deploy-rs rolls back if any unit it starts fails. wantedBy=[]
      # keeps activation from starting it; restart/stopIfChanged keep a running
      # or failed tunnel invisible to switch-to-configuration.
      wantedBy = [ ];
      restartIfChanged = false;
      stopIfChanged = false;
      serviceConfig = {
        ExecStart = connect;
        # openconnect handles transient blips itself; if it exits the session is
        # gone and needs a fresh cookie, so looping here would spin uselessly.
        Restart = "no";
      };
    };

    systemd.services.gp-receiver = {
      description = "GlobalProtect cookie receiver (tailnet-only)";
      after = [ "tailscaled.service" "systemd-tmpfiles-setup.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = receiver;
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # Advertise the campus routes to the tailnet. Approve them once in the admin
    # console. Re-runs are idempotent.
    systemd.services.gp-advertise = lib.mkIf (cfg.routes != [ ]) {
      description = "Advertise GlobalProtect routes over Tailscale";
      after = [ "tailscaled.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        ${config.services.tailscale.package}/bin/tailscale set \
          --advertise-routes=${lib.concatStringsSep "," cfg.routes}
      '';
    };

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ cfg.receiverPort ];

    environment.systemPackages = [ pkgs.openconnect ];
  };
}
